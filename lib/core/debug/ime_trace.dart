import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

const imeTraceEnabled = bool.fromEnvironment('ROBYNE_IME_TRACE');

void imeTrace(String message) {
  if (!imeTraceEnabled) {
    return;
  }
  debugPrint('[ROBYNE_IME_TRACE] ${DateTime.now().toIso8601String()} $message');
}

void attachImeTextControllerTrace(
  TextEditingController controller,
  String label,
) {
  if (!imeTraceEnabled) {
    return;
  }
  void listener() {
    final value = controller.value;
    imeTrace(
      'text[$label] len=${value.text.length} '
      'selection=${_selection(value.selection)} '
      'composing=${_range(value.composing)}',
    );
  }

  controller.addListener(listener);
  listener();
}

class ImeTraceProbe with WidgetsBindingObserver {
  ImeTraceProbe._();

  static ImeTraceProbe? _instance;

  static void install() {
    if (!imeTraceEnabled || _instance != null) {
      return;
    }
    final probe = ImeTraceProbe._();
    _instance = probe;
    WidgetsBinding.instance.addObserver(probe);
    FocusManager.instance.addListener(probe._logFocusChange);
    SemanticsBinding.instance.addSemanticsEnabledListener(
      probe._logSemanticsChange,
    );
    probe._logState('install');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      probe._logState('first-frame');
    });
  }

  @override
  void didChangeAccessibilityFeatures() {
    _logState('accessibility-features-change');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _logState('lifecycle=$state');
  }

  @override
  void didChangeMetrics() {
    _logState('metrics-change');
  }

  @override
  void didChangeTextScaleFactor() {
    _logState('text-scale-change');
  }

  @override
  void didChangePlatformBrightness() {
    _logState('brightness-change');
  }

  void _logFocusChange() {
    _logState('focus-change');
  }

  void _logSemanticsChange() {
    _logState('semantics-enabled-change');
  }

  void _logState(String event) {
    final binding = SemanticsBinding.instance;
    final features = binding.accessibilityFeatures;
    imeTrace(
      '$event '
      'platform=$defaultTargetPlatform '
      'semanticsEnabled=${binding.semanticsEnabled} '
      'semanticsHandles=${binding.debugOutstandingSemanticsHandles} '
      'features={accessibleNavigation:${features.accessibleNavigation},'
      'disableAnimations:${features.disableAnimations},'
      'boldText:${features.boldText},'
      'highContrast:${features.highContrast},'
      'invertColors:${features.invertColors},'
      'reduceMotion:${features.reduceMotion}} '
      'focus=${_focus()}',
    );
  }
}

String _focus() {
  final focus = FocusManager.instance.primaryFocus;
  final context = focus?.context;
  return '{debugLabel:${focus?.debugLabel},'
      'hasFocus:${focus?.hasFocus},'
      'hasPrimaryFocus:${focus?.hasPrimaryFocus},'
      'context:${context?.widget.runtimeType},'
      'editable:${_hasEditableAncestor(context)}}';
}

bool _hasEditableAncestor(BuildContext? context) {
  if (context == null) {
    return false;
  }
  if (context.widget is EditableText) {
    return true;
  }
  if (context.findAncestorStateOfType<EditableTextState>() != null) {
    return true;
  }
  var found = false;
  context.visitAncestorElements((element) {
    if (element.widget is EditableText) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

String _selection(TextSelection selection) {
  return '{base:${selection.baseOffset},extent:${selection.extentOffset},'
      'affinity:${selection.affinity},directional:${selection.isDirectional}}';
}

String _range(TextRange range) {
  return '{start:${range.start},end:${range.end},'
      'valid:${range.isValid},collapsed:${range.isCollapsed}}';
}
