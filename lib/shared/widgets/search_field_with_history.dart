import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/window_size_class.dart';
import '../../core/theme/application/theme_providers.dart';
import '../../core/theme/domain/theme_strings.dart';
import '../../core/theme/infrastructure/token_resolver.dart';
import '../../features/search/application/search_history_controller.dart';
import '../../features/search/domain/search_history_entry.dart';
import 'search_history_overlay.dart';

/// A search field with a Google-style dropdown of remembered keywords.
///
/// The dropdown is the history's only home: it belongs to the field the user
/// is typing in, because a suggestion is only worth anything at the moment of
/// typing.
///
/// ## Why the panel takes everything by value
///
/// The panel is inserted into the *root* overlay, which sits outside the field's
/// provider scope. A `ConsumerWidget` there creates a **second** instance of the
/// history provider — it resolves to `AsyncLoading` and never sees the app's
/// overrides, so the panel renders empty even though the field's own scope has
/// the data. Everything the panel needs is therefore read here and passed down
/// as plain values, including the callbacks that mutate history.
class SearchFieldWithHistory extends ConsumerStatefulWidget {
  const SearchFieldWithHistory({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    this.hintText,
    this.maxWidth,
    this.dense = true,
    this.fillColor,
    this.borderRadius,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 8),
    this.textStyle,
    this.hintStyle,
    this.prefix,
    this.suffix,
    this.suffixConstraints,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Runs the current text — from Enter, from the submit button, or from
  /// picking a history row.
  final ValueChanged<String> onSubmit;

  /// Defaults to the skin's `search.hint` slot.
  final String? hintText;
  final double? maxWidth;
  final bool dense;
  final Color? fillColor;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry contentPadding;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final Widget? prefix;
  final Widget? suffix;
  final BoxConstraints? suffixConstraints;

  @override
  ConsumerState<SearchFieldWithHistory> createState() =>
      _SearchFieldWithHistoryState();
}

class _SearchFieldWithHistoryState
    extends ConsumerState<SearchFieldWithHistory> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;
  int _selectedIndex = -1;
  bool _open = false;

  /// The field's measured width, used to size the dropdown.
  double _fieldWidth = 0;
  /// Keyed on the inner field, so its own box can be measured.
  final GlobalKey _fieldKey = GlobalKey();
  /// Keyed on the panel body, so a press inside it is not read as "outside".
  ///
  /// Resolved by lookup rather than held as a `GlobalKey`, because the panel is
  /// rebuilt on every refresh and a key passed down would be recreated with it.
  static const Key _panelKey = Key('search-history-panel');
  /// Whether the outside-dismiss pointer route is currently registered.
  bool _pointerRouteAdded = false;
  /// Whether the press currently in flight landed on the field or the panel.
  ///
  /// Read when the field reports a blur: a press inside the panel takes focus
  /// away before the row's own tap completes, so closing on that blur destroys
  /// the row between `PointerDownEvent` and `PointerUpEvent` and the tap is
  /// lost. See [_onFocusChanged].
  bool _pressInside = false;

  /// Repaints the open panel in place; see [_refreshPanel].
  ValueNotifier<_PanelState>? _panelState;

  /// Whether an outside tap may dismiss the panel yet.
  ///
  /// Shared tap group for the field and its dropdown, so a tap on a row counts
  /// as *inside* even though the panel lives in the root overlay.
  static final Object _tapGroup = Object();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
    // History is loaded asynchronously; repaint once it arrives so a panel
    // opened during the load fills in instead of staying empty.
    ref.listenManual(searchHistoryControllerProvider, (_, next) {
      _refreshPanel();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _stopOutsideDismiss();
    _removeOverlay();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measureField();
  }

  /// Reads the field's width once it has been laid out.
  ///
  /// Post-frame rather than during build: the box has no size until after the
  /// first layout pass, and the panel needs that number to be capped.
  void _measureField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // The *field's* box, not this widget's: the field sits inside a
      // `ConstrainedBox` and a `TapRegion`, so the state's own render object is
      // the outer wrapper and reports the overlay-wide width instead.
      // The field's own box: the state's context is the outer wrapper (inside
      // `ConstrainedBox` and `TapRegion`), which reports the overlay-wide width.
      final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
      final width = box?.size.width ?? 0;

      if (width != _fieldWidth) {
        _fieldWidth = width;
        _refreshPanel();
      }
    });
  }

  void _onTextChanged() {
    // Retyping resets the keyboard cursor: the row it was on may no longer
    // match, and carrying a stale highlight into a filtered list would run a
    // keyword the user never selected.
    _selectedIndex = -1;
    _refreshPanel();
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) {
      _openOverlay();
      return;
    }
    // Closing on blur is what makes the panel feel like a suggestion list: it
    // is attached to the act of typing, and it must not linger over the page
    // once the user has moved on.
    //
    // But not while the press that caused the blur is still in flight and
    // landed on the field or the panel. Focus moves on `PointerDownEvent`, so
    // an unconditional close here tore the panel down one frame into the
    // gesture: the row's recognizer was gone by the time the button came up,
    // and picking a remembered keyword silently did nothing. Dismissing a
    // press that started *outside* is already [_onPointerRoute]'s job.
    if (_pressInside) {
      return;
    }
    _closeOverlay();
  }

  List<SearchHistoryEntry> get _entries {
    return ref.read(searchHistoryControllerProvider).value ??
        const <SearchHistoryEntry>[];
  }

  void _openOverlay() {
    if (_open) {
      return;
    }
    // Measure immediately, in case no frame is pending.
    void measureNow() {
      final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;

      final width = box?.size.width ?? 0;
      if (width > 0) {
        _fieldWidth = width;
      }
    }

    _open = true;
    measureNow();
    // Measure before inserting: a panel built with a stale width of 0 stretches
    // across the whole overlay, and a focus change can open the panel without
    // a frame in between for the post-frame callback to have run.
    _measureField();
    _insertOverlay();
    _startOutsideDismiss();
  }

  void _closeOverlay() {
    if (!_open) {
      return;
    }
    _open = false;
    _selectedIndex = -1;
    _pressInside = false;
    _removeOverlay();
    _stopOutsideDismiss();
  }

  /// Repaints the open panel without tearing the overlay down.
  ///
  /// Removing and re-inserting the entry destroyed the row the pointer was
  /// over, which re-entered the row's own hover handler and rebuilt again — an
  /// infinite loop that hung the frame and swallowed the click.
  void _refreshPanel() {
    _panelState?.value = _PanelState(
      query: widget.controller.text,
      selectedIndex: _selectedIndex,
      entries: _entries,
      width: _fieldWidth,
    );
  }

  void _insertOverlay() {
    final overlay = Overlay.of(context, rootOverlay: true);
    final notifier = ValueNotifier<_PanelState>(
      _PanelState(
        query: widget.controller.text,
        selectedIndex: _selectedIndex,
        entries: _entries,
        width: _fieldWidth,
      ),
    );
    _panelState = notifier;
    final entry = OverlayEntry(
      builder: (context) => ValueListenableBuilder<_PanelState>(
        valueListenable: notifier,
        builder: (context, panelState, _) => _HistoryPanel(
          panelKey: _panelKey,
          link: _link,
          state: panelState,
          onHoverIndex: (index) {
            _selectedIndex = index;
            _refreshPanel();
          },
          onPick: (keyword) {
            widget.controller.text = keyword;
            widget.controller.selection = TextSelection.collapsed(
              offset: keyword.length,
            );
            _closeOverlay();
            widget.focusNode.unfocus();
            widget.onSubmit(keyword);
          },
          tapGroup: _tapGroup,
          onRemove: _removeHistory,
          onClearAll: _clearHistory,
          onDismiss: _closeOverlay,
        ),
      ),
    );
    _overlay = entry;
    overlay.insert(entry);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
    _panelState?.dispose();
    _panelState = null;
  }

  /// Drops one remembered keyword.
  ///
  /// Runs from the state, not from inside the overlay: only this scope holds
  /// the app's provider overrides.
  void _removeHistory(String keyword) {
    unawaited(
      ref.read(searchHistoryControllerProvider.notifier).remove(keyword),
    );
  }

  /// Clears every remembered keyword, behind a confirmation.
  Future<void> _clearHistory(BuildContext context) async {
    final strings = ref.read(activeThemeStringsProvider);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              strings.resolve(ThemeStringKey.searchHistoryClearAllTitle),
            ),
            content: Text(
              strings.resolve(ThemeStringKey.searchHistoryClearAllMessage),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(strings.resolve(ThemeStringKey.actionCancel)),
              ),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(
                  strings.resolve(ThemeStringKey.searchHistoryClearAll),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await ref.read(searchHistoryControllerProvider.notifier).clear();
  }

  /// Runs the highlighted row, or the typed text when none is highlighted.
  void _submit() {
    final matches = matchSearchHistory(_entries, widget.controller.text);
    if (_selectedIndex >= 0 && _selectedIndex < matches.length) {
      final keyword = matches[_selectedIndex].keyword;
      widget.controller.text = keyword;
      widget.controller.selection = TextSelection.collapsed(
        offset: keyword.length,
      );
      _closeOverlay();
      widget.onSubmit(keyword);
      return;
    }
    _closeOverlay();
    widget.onSubmit(widget.controller.text);
  }

  void _moveSelection(int delta) {
    if (!_open) {
      _openOverlay();
    }
    final matches = matchSearchHistory(_entries, widget.controller.text);
    if (matches.isEmpty) {
      return;
    }
    _selectedIndex = (_selectedIndex + delta).clamp(-1, matches.length - 1);
    _refreshPanel();
  }

  @override
  Widget build(BuildContext context) {
    // Re-measured every build: the field's width changes with the window (the
    // top bar caps it at 280 or 360 depending on width), and the panel has to
    // follow rather than keep the size from the first frame.
    _measureField();
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    final radius = widget.borderRadius ??
        BorderRadius.all(Radius.circular(tokens.radius.full));

    final field = CompositedTransformTarget(
      link: _link,
      child: SizedBox(
        key: _fieldKey,
        child: _KeyIntents(
        onArrowDown: () => _moveSelection(1),
        onArrowUp: () => _moveSelection(-1),
        onEscape: _closeOverlay,
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          style: widget.textStyle ?? TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            isDense: widget.dense,
            filled: true,
            fillColor: widget.fillColor ?? colors.surfaceBase,
            contentPadding: widget.contentPadding,
            prefixIcon: widget.prefix,
            hintText:
                widget.hintText ?? strings.resolve(ThemeStringKey.searchHint),
            hintStyle:
                widget.hintStyle ??
                TextStyle(fontSize: 13, color: colors.textMuted),
            suffixIcon: widget.suffix,
            suffixIconConstraints: widget.suffixConstraints,
            border: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: colors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: colors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: colors.borderFocus, width: 2),
            ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _submit(),
        ),
        ),
      ),
    );

    final constrained = widget.maxWidth == null
        ? field
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth!),
            child: field,
          );

    return TapRegion(
      groupId: _tapGroup,
      // Dismiss on a tap outside the field; the panel shares this tap group, so
      // a tap on a row is not "outside" and does not close it before the row's
      // own handler runs.
      onTapOutside: (_) => _closeOverlay(),
      child: constrained,
    );
  }

  /// Dismisses when a press lands outside both the field and the panel.
  ///
  /// `TapRegion.onTapOutside` needs a registered `TapRegionSurface`, and the
  /// panel's region lives in the root overlay where that registration does not
  /// reach, so the callback silently never fired. Comparing the press position
  /// against the two boxes depends on nothing else.
  ///
  /// Deliberately not a full-screen barrier widget: anything full-screen in the
  /// root overlay sits *above* the field in hit-test order and swallows a second
  /// tap on it, which closed the panel every time the field was re-tapped.
  void _startOutsideDismiss() {
    if (_pointerRouteAdded) {
      return;
    }
    _pointerRouteAdded = true;
    WidgetsBinding.instance.pointerRouter.addGlobalRoute(_onPointerRoute);
  }

  void _stopOutsideDismiss() {
    if (!_pointerRouteAdded) {
      return;
    }
    _pointerRouteAdded = false;
    WidgetsBinding.instance.pointerRouter.removeGlobalRoute(_onPointerRoute);
  }

  void _onPointerRoute(PointerEvent event) {
    if (!_open) {
      return;
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      // The gesture is over: if it took focus without picking a row, the blur
      // that was held back above now applies.
      _pressInside = false;
      if (!widget.focusNode.hasFocus) {
        _closeOverlay();
      }
      return;
    }
    if (event is! PointerDownEvent) {
      return;
    }

    _pressInside = _contains(_fieldKey.currentContext, event.position) ||
        _contains(_panelContext(), event.position);
    if (_pressInside) {
      return;
    }
    _closeOverlay();
  }

  /// The panel body's context, found by key inside the root overlay.
  ///
  /// Looked up rather than held: the panel is rebuilt on every refresh, so a
  /// context captured earlier could be stale or detached.
  BuildContext? _panelContext() {
    final overlay = Overlay.of(context, rootOverlay: true);
    BuildContext? found;
    void visit(Element element) {
      if (found != null) {
        return;
      }
      if (element.widget.key == _panelKey) {
        found = element;
        return;
      }
      element.visitChildren(visit);
    }
    overlay.context.visitChildElements(visit);

    return found;
  }

  /// Whether [position] is inside the box for [context].
  static bool _contains(BuildContext? context, Offset position) {
    final box = context?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) {
      return false;
    }
    // Paint bounds in global coordinates: `globalToLocal` mis-converts for a
    // box that is not the transform root, which made the panel appear to cover
    // the whole screen and every press read as "inside".
    final rect = box.localToGlobal(Offset.zero) & box.size;
    return rect.contains(position);
  }
}

/// Everything the floating panel needs, read in the field's own scope.
class _PanelState {
  const _PanelState({
    required this.query,
    required this.selectedIndex,
    required this.entries,
    required this.width,
  });

  final String query;
  final int selectedIndex;
  final List<SearchHistoryEntry> entries;
  final double width;
}

/// Claims the keys the suggestion list owns before the text field sees them.
///
/// `EditableText` installs its own handlers for arrows and Enter and is the
/// primary focus, so neither a `Focus` above nor one below the field receives
/// the event first. `Shortcuts` is matched on the way *down* to the focused
/// widget, before the field's own handlers run.
class _KeyIntents extends StatelessWidget {
  const _KeyIntents({
    required this.onArrowDown,
    required this.onArrowUp,
    required this.onEscape,
    required this.child,
  });

  final VoidCallback onArrowDown;
  final VoidCallback onArrowUp;
  final VoidCallback onEscape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveDownIntent(),
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveUpIntent(),
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _MoveDownIntent: CallbackAction<_MoveDownIntent>(
            onInvoke: (_) {
              onArrowDown();
              return null;
            },
          ),
          _MoveUpIntent: CallbackAction<_MoveUpIntent>(
            onInvoke: (_) {
              onArrowUp();
              return null;
            },
          ),
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              onEscape();
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

class _MoveDownIntent extends Intent {
  const _MoveDownIntent();
}

class _MoveUpIntent extends Intent {
  const _MoveUpIntent();
}

/// The floating half: follows the field's box, sized to it.
class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.panelKey,
    required this.link,
    required this.state,
    required this.onHoverIndex,
    required this.onPick,
    required this.tapGroup,
    required this.onRemove,
    required this.onClearAll,
    required this.onDismiss,
  });

  /// Keyed on the panel's own box, not on this widget: the root is a
  /// `CompositedTransformFollower`, which is a proxy and reports the theater's
  /// viewport-sized box. The dismiss route measures by this key, and a
  /// viewport-sized rect made every press look like it was inside the panel.
  final Key panelKey;

  final LayerLink link;
  final _PanelState state;
  final ValueChanged<int> onHoverIndex;
  final ValueChanged<String> onPick;
  final Object tapGroup;
  final ValueChanged<String> onRemove;
  final Future<void> Function(BuildContext context) onClearAll;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final metrics = WindowSizeClass.of(context);
    final horizontalInset =
        metrics.width == WindowWidthClass.expanded ? 0.0 : 12.0;
    // `CompositedTransformFollower` is a `RenderProxyBox`: it lays its child out
    // with the constraints it was handed and reports no box of its own. The
    // root overlay hands the theater's children
    // `BoxConstraints.tight(viewportSize)`, so without a width declared in here
    // the panel stretched to the whole viewport — 1280x900 under a 360dp field,
    // i.e. the panel covering the page's bottom-right corner.
    //
    // `SizedBox` sets the width; `Align` keeps the panel at the follower's
    // top-left, because a child that sizes itself is otherwise free to sit
    // anywhere in the box it was given.
    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      // Same tap group as the field: the panel is in the root overlay, so
      // without this every row tap reads as "outside" and the panel is
      // dismissed before the row's own handler runs.
      child: TapRegion(
        groupId: tapGroup,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalInset),
            child: SearchHistoryOverlay(
              panelKey: panelKey,
              width: state.width <= 0 ? null : state.width,
              entries: state.entries,
              query: state.query,
              selectedIndex: state.selectedIndex,
              onHoverIndex: onHoverIndex,
              onPick: onPick,
              onRemove: onRemove,
              onClearAll: onClearAll,
            ),
          ),
        ),
      ),
    );
  }
}
