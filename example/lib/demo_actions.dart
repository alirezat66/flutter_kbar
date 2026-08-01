import 'package:flutter/material.dart';
import 'package:flutter_kbar/flutter_kbar.dart';

import 'feedback_dialog.dart';

/// Application state the demo commands act on.
class DemoState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  Color _seedColor = const Color(0xFF6C8CFF);
  double _textScale = 1;
  final List<String> _log = <String>[];

  /// The active theme mode.
  ThemeMode get themeMode => _themeMode;

  /// The colour the theme is generated from.
  Color get seedColor => _seedColor;

  /// Text scale applied to the demo page.
  double get textScale => _textScale;

  /// Recently performed commands, newest first.
  List<String> get log => List<String>.unmodifiable(_log);

  /// Sets the theme mode and records it.
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _note('Theme: ${mode.name}');
  }

  /// Sets the seed colour and records it.
  void setSeedColor(Color color, String name) {
    _seedColor = color;
    _note('Accent: $name');
  }

  /// Adjusts the text scale, clamped to a sensible range.
  void setTextScale(double scale) {
    _textScale = scale.clamp(0.8, 1.6);
    _note('Text scale: ${_textScale.toStringAsFixed(2)}');
  }

  /// Records a message without changing anything else.
  void note(String message) => _note(message);

  void _note(String message) {
    _log.insert(0, message);
    if (_log.length > 12) _log.removeLast();
    notifyListeners();
  }
}

/// Builds the demo's command set.
///
/// Exercises every feature: sections with priorities, nested actions, single
/// and sequence shortcuts, subtitles, icons, keywords, undoable commands, and
/// an asynchronous command that opens a dialog.
///
/// [navigatorKey] is how a command declared outside the widget tree reaches a
/// [Navigator] — needed to push a dialog.
List<KBarAction> buildDemoActions(
  DemoState state, {
  required GlobalKey<NavigatorState> navigatorKey,
}) {
  return <KBarAction>[
    // ---- A command that opens a form ------------------------------------
    KBarAction(
      id: 'feedback',
      name: 'Send feedback…',
      subtitle: 'Opens a form in a dialog',
      icon: const Icon(Icons.forum_outlined),
      section: const KBarSection('Help'),
      keywords: 'bug,report,contact,support,form,dialog',
      shortcut: const <String>[r'$mod+i'],
      // `perform` may be async: the palette closes first, then this runs and
      // the controller awaits it.
      perform: (_) async {
        final BuildContext? context = navigatorKey.currentContext;
        if (context == null) return;

        final FeedbackSubmission? result = await showFeedbackDialog(context);
        state.note(
          result == null
              ? 'Feedback cancelled'
              : 'Feedback sent — ${result.category.label} from ${result.name}',
        );
      },
    ),

    // ---- Navigation ------------------------------------------------------
    KBarAction(
      id: 'home',
      name: 'Go home',
      subtitle: 'Return to the start page',
      icon: const Icon(Icons.home_outlined),
      section: const KBarSection('Navigation', priority: KBarPriority.high),
      keywords: 'start,index',
      shortcut: const <String>['g', 'h'],
      perform: (_) => state.note('Navigated home'),
    ),
    KBarAction(
      id: 'docs',
      name: 'Open documentation',
      subtitle: 'flutter_kbar on pub.dev',
      icon: const Icon(Icons.menu_book_outlined),
      section: const KBarSection('Navigation', priority: KBarPriority.high),
      keywords: 'help,manual,guide',
      shortcut: const <String>['g', 'd'],
      perform: (_) => state.note('Opened documentation'),
    ),

    // ---- Appearance: a nested action -------------------------------------
    const KBarAction(
      id: 'theme',
      name: 'Change theme',
      subtitle: 'Light, dark, or follow the system',
      icon: Icon(Icons.brightness_6_outlined),
      section: KBarSection('Appearance'),
      keywords: 'dark,light,appearance,mode',
      // No perform, so selecting this descends into its children.
      shortcut: <String>['t'],
    ),
    KBarAction(
      id: 'theme.light',
      name: 'Light',
      parent: 'theme',
      icon: const Icon(Icons.light_mode_outlined),
      perform: (KBarActionContext context) {
        final ThemeMode previous = state.themeMode;
        state.setThemeMode(ThemeMode.light);
        context.undoWith(() => state.setThemeMode(previous));
      },
    ),
    KBarAction(
      id: 'theme.dark',
      name: 'Dark',
      parent: 'theme',
      icon: const Icon(Icons.dark_mode_outlined),
      perform: (KBarActionContext context) {
        final ThemeMode previous = state.themeMode;
        state.setThemeMode(ThemeMode.dark);
        context.undoWith(() => state.setThemeMode(previous));
      },
    ),
    KBarAction(
      id: 'theme.system',
      name: 'System',
      parent: 'theme',
      icon: const Icon(Icons.brightness_auto_outlined),
      perform: (KBarActionContext context) {
        final ThemeMode previous = state.themeMode;
        state.setThemeMode(ThemeMode.system);
        context.undoWith(() => state.setThemeMode(previous));
      },
    ),

    // ---- Appearance: a second nested action ------------------------------
    const KBarAction(
      id: 'accent',
      name: 'Change accent colour',
      subtitle: 'Recolour the whole app',
      icon: Icon(Icons.palette_outlined),
      section: KBarSection('Appearance'),
      keywords: 'color,colour,seed,accent',
    ),
    for (final (String name, Color color) swatch in <(String, Color)>[
      ('Indigo', Color(0xFF6C8CFF)),
      ('Emerald', Color(0xFF2FBF71)),
      ('Amber', Color(0xFFFFB020)),
      ('Rose', Color(0xFFFF5C8A)),
    ])
      KBarAction(
        id: 'accent.${swatch.$1.toLowerCase()}',
        name: swatch.$1,
        parent: 'accent',
        icon: Icon(Icons.circle, color: swatch.$2),
        perform: (KBarActionContext context) {
          final Color previous = state.seedColor;
          state.setSeedColor(swatch.$2, swatch.$1);
          context.undoWith(() => state.setSeedColor(previous, 'previous'));
        },
      ),

    // ---- Text ------------------------------------------------------------
    KBarAction(
      id: 'text.bigger',
      name: 'Increase text size',
      icon: const Icon(Icons.text_increase),
      section: const KBarSection('Text'),
      shortcut: const <String>[r'$mod+='],
      perform: (_) => state.setTextScale(state.textScale + 0.1),
    ),
    KBarAction(
      id: 'text.smaller',
      name: 'Decrease text size',
      icon: const Icon(Icons.text_decrease),
      section: const KBarSection('Text'),
      shortcut: const <String>[r'$mod+-'],
      perform: (_) => state.setTextScale(state.textScale - 0.1),
    ),
    KBarAction(
      id: 'text.reset',
      name: 'Reset text size',
      icon: const Icon(Icons.format_size),
      section: const KBarSection('Text'),
      perform: (_) => state.setTextScale(1),
    ),

    // ---- A low-priority section, to show ordering ------------------------
    KBarAction(
      id: 'log.clear',
      name: 'Clear activity log',
      icon: const Icon(Icons.clear_all),
      section: const KBarSection('Danger zone', priority: KBarPriority.low),
      perform: (_) => state.note('Log cleared'),
    ),
  ];
}
