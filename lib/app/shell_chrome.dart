import 'package:flutter/widgets.dart';

/// What chrome the shell is currently drawing around a page.
///
/// Pages are not entitled to a top bar: a phone arrangement has none
/// (`UI_DESIGN_SPEC.md` §2.2), and the shell's plan drops one on a window
/// whose height cannot afford it (D7 step 2). A page that needs the *global*
/// search field therefore has to ask rather than assume.
///
/// Only what a page must react to belongs here. Everything else about the
/// shell stays in `RobyneShell` and its plan.
class ShellChrome extends InheritedWidget {
  const ShellChrome({
    super.key,
    required this.topBarVisible,
    required super.child,
  });

  /// True while the shell draws the [RobyneRegion.topBar] region.
  ///
  /// When this is false there is no global search field on screen at all, so
  /// the keyword box moves into the content that wants one.
  final bool topBarVisible;

  /// The chrome in effect, or null when the page is not hosted by the shell
  /// (a widget test, or a page reused in another surface).
  ///
  /// Callers must treat null as "no top bar": the safe default is for the
  /// page to carry its own affordance. Assuming a top bar exists is what left
  /// a phone's search page with no way to search a second time.
  static ShellChrome? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellChrome>();
  }

  @override
  bool updateShouldNotify(ShellChrome oldWidget) {
    return topBarVisible != oldWidget.topBarVisible;
  }
}
