import 'package:flutter/widgets.dart';

/// Whether a text field currently has focus.
///
/// Action shortcuts are suppressed while this is true, so that typing `g` in a
/// form does not fire the `g` shortcut. The palette's own toggle binding is
/// deliberately exempt — `⌘K` should work from anywhere.
///
/// [EditableText] builds a [Focus] around its own focus node, so the primary
/// focus node's context is a descendant element of the [EditableText] and this
/// ancestor lookup finds it.
///
/// Override via `KBarOptions.shouldIgnoreShortcuts` for custom editors that
/// Flutter cannot recognise as text fields — a canvas-based code editor, say.
bool kbarIsTextFieldFocused() {
  final BuildContext? context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  if (context.widget is EditableText) return true;
  return context.findAncestorStateOfType<EditableTextState>() != null;
}
