import 'package:flutter/material.dart';
import 'package:flutter_kbar/flutter_kbar.dart';

/// Builds a palette from the primitives instead of using `KBarPalette`.
///
/// Everything `KBarPalette` does is assembled from these same public pieces —
/// `KBarPortal`, `KBarPositioner`, `KBarAnimator`, `KBarSearchField` and
/// `KBarResults` — so there is no cliff between styling the bundled palette and
/// building your own.
///
/// This page also shows `KBarRegisterActions`, which contributes commands only
/// while the page is mounted. Open the palette and search for "confetti": it is
/// there from this page and gone once you navigate away.
class HeadlessExamplePage extends StatefulWidget {
  /// Creates the page.
  const HeadlessExamplePage({super.key});

  @override
  State<HeadlessExamplePage> createState() => _HeadlessExamplePageState();
}

class _HeadlessExamplePageState extends State<HeadlessExamplePage> {
  int _confetti = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return KBarRegisterActions(
      // Registered on mount, removed on unmount.
      actions: <KBarAction>[
        KBarAction(
          id: 'page.confetti',
          name: 'Throw confetti',
          subtitle: 'Only available on the headless example page',
          icon: const Icon(Icons.celebration_outlined),
          section: const KBarSection('This page'),
          perform: (_) => setState(() => _confetti++),
        ),
        KBarAction(
          id: 'page.back',
          name: 'Go back',
          icon: const Icon(Icons.arrow_back),
          section: const KBarSection('This page'),
          perform: (_) => Navigator.of(context).maybePop(),
        ),
      ],
      // The deps list mirrors React's: rebuild the registration when the
      // captured state actually changes.
      deps: <Object?>[_confetti == 0],
      child: Scaffold(
        appBar: AppBar(title: const Text('Headless example')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'This page registers its own commands.',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Open the palette and search for "confetti". Navigate away '
                    'and it disappears.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _confetti == 0
                        ? 'No confetti yet.'
                        : 'Confetti thrown $_confetti time'
                              '${_confetti == 1 ? '' : 's'}. '
                              '${'🎉' * _confetti.clamp(0, 12)}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 32),
                  Text('Live state', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  // KBarSelector rebuilds only when its own slice changes.
                  KBarSelector<String>(
                    selector: (KBarState state) => state.searchQuery,
                    builder:
                        (
                          BuildContext context,
                          String query,
                          KBarController kbar,
                          Widget? child,
                        ) => Text(
                          'Query: ${query.isEmpty ? '(empty)' : '"$query"'}',
                          style: theme.textTheme.bodySmall,
                        ),
                  ),
                  KBarMatchesBuilder(
                    builder:
                        (
                          BuildContext context,
                          KBarMatches matches,
                          KBarController kbar,
                          Widget? child,
                        ) => Text(
                          'Matches: ${matches.actionResults.length}',
                          style: theme.textTheme.bodySmall,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A minimal palette assembled from the primitives.
///
/// Not used by the demo — `KBarPalette` is — but kept here as the reference for
/// what building your own looks like end to end.
class MinimalPalette extends StatelessWidget {
  /// Creates the palette.
  const MinimalPalette({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return KBarPortal(
      child: KBarPositioner(
        child: KBarAnimator(
          child: Material(
            color: colors.surface,
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const KBarSearchField(placeholder: 'What do you need?'),
                const Divider(height: 1),
                KBarResults(
                  emptyBuilder: (BuildContext context, String query) =>
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Nothing found'),
                      ),
                  itemBuilder:
                      (
                        BuildContext context,
                        KBarResultItem item,
                        int index,
                        bool isActive,
                      ) => switch (item) {
                        KBarSectionHeader(:final String title) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            title.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        KBarActionResult(:final KBarActionNode action) =>
                          Container(
                            color: isActive
                                ? colors.primary.withValues(alpha: 0.12)
                                : null,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(action.name),
                          ),
                      },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
