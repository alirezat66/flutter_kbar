import 'package:flutter/material.dart';

import '../keyboard/kbar_shortcut.dart';
import '../util/kbar_platform.dart';
import 'kbar_theme.dart';
import 'kbar_theme_data.dart';

/// Renders an action's key binding as a row of key caps.
///
/// A sequence like `['g', 'h']` renders as two separate caps with a gap, so it
/// reads as "press g, then h" rather than "g and h together".
class KBarShortcutChips extends StatelessWidget {
  /// Renders [shortcut], in [KBarAction.shortcut] form.
  const KBarShortcutChips(this.shortcut, {this.style, super.key});

  /// The binding to render.
  final List<String> shortcut;

  /// Overrides for the ambient palette theme.
  final KBarThemeData? style;

  @override
  Widget build(BuildContext context) {
    if (shortcut.isEmpty) return const SizedBox.shrink();

    final KBarThemeData theme = KBarTheme.of(context).merge(style);
    final List<Widget> caps = <Widget>[];

    for (int i = 0; i < shortcut.length; i++) {
      // Each list entry is one press in the sequence.
      final KBarShortcut? parsed = _tryParse(shortcut[i]);
      if (parsed == null) continue;
      if (i > 0) caps.add(const SizedBox(width: 6));
      for (final KBarKeyPress press in parsed.presses) {
        caps.add(_cap(theme, _label(press)));
      }
    }

    if (caps.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: 'Shortcut ${shortcut.join(' then ')}',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: caps),
    );
  }

  static KBarShortcut? _tryParse(String source) {
    try {
      return KBarShortcut.parse(source);
    } on FormatException {
      return null;
    }
  }

  Widget _cap(KBarThemeData theme, String label) => Container(
    padding: theme.shortcutPadding,
    decoration: theme.shortcutDecoration,
    child: Text(label, style: theme.shortcutTextStyle),
  );

  /// A human-readable label for one press.
  ///
  /// Apple platforms get the conventional glyphs; everywhere else gets words,
  /// because `⌃` and `⌥` are not part of the Windows or Linux vocabulary.
  static String _label(KBarKeyPress press) {
    final bool apple = kbarIsApplePlatform;
    final StringBuffer buffer = StringBuffer();

    for (final KBarModifier modifier in <KBarModifier>[
      KBarModifier.control,
      KBarModifier.alt,
      KBarModifier.shift,
      KBarModifier.meta,
    ]) {
      if (!press.resolvedModifiers.contains(modifier)) continue;
      buffer.write(switch (modifier) {
        KBarModifier.control => apple ? '⌃' : 'Ctrl+',
        KBarModifier.alt => apple ? '⌥' : 'Alt+',
        KBarModifier.shift => apple ? '⇧' : 'Shift+',
        KBarModifier.meta => apple ? '⌘' : 'Win+',
        KBarModifier.mod => '',
      });
    }

    buffer.write(_keyLabel(press.key));
    return buffer.toString();
  }

  static String _keyLabel(String key) => switch (key) {
    'Enter' => '↵',
    'Escape' => 'Esc',
    'Backspace' => '⌫',
    'Delete' => 'Del',
    'ArrowUp' => '↑',
    'ArrowDown' => '↓',
    'ArrowLeft' => '←',
    'ArrowRight' => '→',
    'Tab' => '⇥',
    ' ' => 'Space',
    _ => key.length == 1 ? key.toUpperCase() : key,
  };
}
