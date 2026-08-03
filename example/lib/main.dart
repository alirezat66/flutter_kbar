import 'package:flutter/material.dart';
import 'package:flutter_kbar/flutter_kbar.dart';

import 'demo_actions.dart';
import 'escape_to_go_back.dart';
import 'headless_example.dart';
import 'setup_guide.dart';

void main() => runApp(const DemoApp());

/// The flutter_kbar demo.
class DemoApp extends StatefulWidget {
  /// Creates the demo.
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  final DemoState _state = DemoState();

  /// Lets commands defined outside the widget tree push routes and dialogs.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (BuildContext context, Widget? child) {
        return KBarProvider(
          actions: buildDemoActions(_state, navigatorKey: _navigatorKey),
          options: const KBarOptions(
            enableHistory: true,
            // Firefox binds Ctrl/Cmd+K to its own search bar, so web builds
            // want a fallback.
            toggleShortcuts: <String>[r'$mod+k', r'$mod+shift+p'],
          ),
          child: MaterialApp(
            title: 'flutter_kbar',
            debugShowCheckedModeBanner: false,
            navigatorKey: _navigatorKey,
            themeMode: _state.themeMode,
            theme: _theme(Brightness.light),
            darkTheme: _theme(Brightness.dark),
            // Placing the palette here keeps it above every route.
            builder: (BuildContext context, Widget? child) {
              final Widget app = EscapeToGoBack(
                navigatorKey: _navigatorKey,
                child: MediaQuery.withClampedTextScaling(
                  minScaleFactor: _state.textScale,
                  maxScaleFactor: _state.textScale,
                  child: child!,
                ),
              );
              return _state.useHeadlessPalette
                  ? MinimalPalette(child: app)
                  : KBarPalette(child: app);
            },
            home: HomePage(state: _state),
          ),
        );
      },
    );
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorSchemeSeed: _state.seedColor,
  );
}

/// The demo's landing page.
class HomePage extends StatelessWidget {
  /// Shows the demo content for [state].
  const HomePage({required this.state, super.key});

  /// The state the commands act on.
  final DemoState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isApple = theme.platform == TargetPlatform.macOS;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('flutter_kbar', style: theme.textTheme.displaySmall),
                const SizedBox(height: 8),
                Text(
                  'A command palette for Flutter desktop and web.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () => context.kbar.open(),
                      icon: const Icon(Icons.search),
                      label: Text('Open palette  ${isApple ? '⌘K' : 'Ctrl K'}'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SetupGuidePage(),
                        ),
                      ),
                      icon: const Icon(Icons.code),
                      label: const Text('Setup guide'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => HeadlessExamplePage(
                            onPaletteModeChanged: state.setUseHeadlessPalette,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.construction_outlined),
                      label: const Text('Headless example'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const _Section(
                  title: 'Try these',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Hint('Type "feedback" — a command that opens a form'),
                      _Hint('Type "dark" — search reaches nested actions'),
                      _Hint('Press t — a parent shortcut opens that page'),
                      _Hint('Press g then h — a two-key sequence'),
                      _Hint('Backspace on an empty query — go back up'),
                      _Hint('Esc — close a dialog or go back a page'),
                      _Hint('Cmd/Ctrl+Z — undo a theme change'),
                      _Hint('↑ ↓ or Ctrl+N / Ctrl+P — move the selection'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'Activity',
                  child: state.log.isEmpty
                      ? Text(
                          'Nothing yet — run a command.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            for (final String entry in state.log)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  entry,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
