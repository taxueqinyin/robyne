import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/application/theme_providers.dart';
import '../../core/theme/domain/theme_icons.dart';
import '../../core/theme/domain/theme_strings.dart';
import '../../core/theme/infrastructure/token_resolver.dart';
import '../../core/theme/presentation/theme_icon.dart';
import '../../features/search/application/search_controller.dart'
    as search_state;
import 'search_field_with_history.dart';

/// The keyword box a shell without a global top bar hands to its content.
///
/// The desktop shell owns a search field in `topBar`. The phone shell has no
/// top bar at all (`UI_DESIGN_SPEC.md` §2.2), so the field has to live in the
/// content that wants one: the home header and the results page. Both render
/// this widget rather than their own copy, so the two cannot drift into
/// different hints, radii or histories.
///
/// It carries the same remembered-keyword dropdown as the top bar's field: on
/// a phone this is the only search box on screen, so the history has nowhere
/// else to be.
class KeywordSearchField extends ConsumerStatefulWidget {
  const KeywordSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    this.compact = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Runs the confirmed keyword — typed and submitted, or picked from the
  /// remembered list.
  final ValueChanged<String> onSubmit;

  /// True inside a landscape strip, where the field shares one 44dp row with
  /// the page title.
  final bool compact;

  @override
  ConsumerState<KeywordSearchField> createState() => _KeywordSearchFieldState();
}

class _KeywordSearchFieldState extends ConsumerState<KeywordSearchField> {
  @override
  void initState() {
    super.initState();
    // Two surfaces can show this field (the home header and the search page),
    // and the last search may have been run from the other one. The controller
    // owns the keyword, so a change there is the only truth worth copying —
    // otherwise coming back to a page that is already mounted showed the
    // previous keyword above results for a newer one.
    ref.listenManual(search_state.searchControllerProvider, (_, next) {
      final keyword = next.value?.keyword;
      if (keyword == null ||
          keyword == widget.controller.text ||
          !mounted ||
          // Never overwrite what the user is typing right now.
          widget.focusNode.hasFocus) {
        return;
      }
      widget.controller.text = keyword;
      widget.controller.selection = TextSelection.collapsed(
        offset: keyword.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return SearchFieldWithHistory(
      controller: widget.controller,
      focusNode: widget.focusNode,
      onSubmit: widget.onSubmit,
      textStyle: TextStyle(fontSize: 13, color: colors.textPrimary),
      fillColor: colors.surfaceBase,
      borderRadius: BorderRadius.all(Radius.circular(tokens.radius.md)),
      contentPadding: EdgeInsets.symmetric(vertical: widget.compact ? 8 : 11),
      hintText: strings.resolve(ThemeStringKey.searchHint),
      hintStyle: TextStyle(fontSize: 12.5, color: colors.textMuted),
      prefix: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: ThemeIconView(
          slot: ThemeIconKey.search,
          fallback: Icons.search,
          size: widget.compact ? 16 : 18,
          color: colors.textMuted,
        ),
      ),
    );
  }
}
