import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_kbar/flutter_kbar.dart';

const String _paletteCode = '''KBarPortal(
  child: KBarPositioner(
    child: KBarAnimator(
      child: Material(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const KBarSearchField(),
            KBarResults(
              itemBuilder: (context, item, index, active) {
                return switch (item) {
                  KBarSectionHeader(:final title) =>
                    MySectionHeader(title),
                  KBarActionResult(:final action) =>
                    MyCommandRow(action, active),
                };
              },
            ),
          ],
        ),
      ),
    ),
  ),
)''';

/// Demonstrates a live palette composed from flutter_kbar primitives.
class HeadlessExamplePage extends StatefulWidget {
  /// Creates the page.
  const HeadlessExamplePage({this.onPaletteModeChanged, super.key});

  /// Tells the app shell to use the custom palette while this route is active.
  final ValueChanged<bool>? onPaletteModeChanged;

  @override
  State<HeadlessExamplePage> createState() => _HeadlessExamplePageState();
}

class _HeadlessExamplePageState extends State<HeadlessExamplePage> {
  int _confetti = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.onPaletteModeChanged?.call(true),
    );
  }

  @override
  void dispose() {
    scheduleMicrotask(() => widget.onPaletteModeChanged?.call(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return KBarRegisterActions(
      actions: <KBarAction>[
        KBarAction(
          id: 'page.confetti',
          name: 'Throw confetti',
          subtitle: 'A command registered only while this page exists',
          icon: const Icon(Icons.celebration_outlined),
          section: const KBarSection('Headless lab'),
          perform: (_) => setState(() => _confetti++),
        ),
        KBarAction(
          id: 'page.back',
          name: 'Leave headless lab',
          subtitle: 'Remove this page and its scoped commands',
          icon: const Icon(Icons.arrow_back),
          section: const KBarSection('Headless lab'),
          perform: (_) => Navigator.of(context).maybePop(),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('Headless example')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 64),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'PALETTE COMPOSITION LAB',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The package owns behavior.\nYou own every pixel.',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '“Headless” means search, keyboard navigation, matching, '
                      'focus and command execution still work when you replace '
                      'the bundled interface. This page is using the custom '
                      'palette—not merely showing its source.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: () => context.kbar.open(),
                          icon: const Icon(Icons.terminal),
                          label: const Text('Open custom palette'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _copyCode(context),
                          icon: const Icon(Icons.content_copy),
                          label: const Text('Copy composition'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    const _Anatomy(),
                    const SizedBox(height: 24),
                    _ScopedCommandLab(confetti: _confetti),
                    const SizedBox(height: 24),
                    const _CodeReference(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _paletteCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Palette composition copied'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _Anatomy extends StatelessWidget {
  const _Anatomy();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const List<(String, String)> primitives = <(String, String)>[
      ('KBarPortal', 'mount above the app'),
      ('KBarPositioner', 'place the panel'),
      ('KBarAnimator', 'animate state'),
      ('KBarSearchField', 'capture the query'),
      ('KBarResults', 'render your rows'),
    ];

    return _Panel(
      title: 'How the primitives connect',
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        children: <Widget>[
          for (final (int index, (String, String) primitive)
              in primitives.indexed) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    primitive.$1,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    primitive.$2,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (index < primitives.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScopedCommandLab extends StatelessWidget {
  const _ScopedCommandLab({required this.confetti});

  final int confetti;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _Panel(
      title: 'Prove that behavior is still connected',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Open the custom palette and run “Throw confetti.” The command '
            'exists only on this route and disappears when you leave.',
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              confetti == 0
                  ? 'Waiting for the page command…'
                  : '${'🎉' * confetti.clamp(1, 12)}  Run $confetti',
              key: ValueKey<int>(confetti),
              style: theme.textTheme.titleMedium?.copyWith(
                color: confetti == 0
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeReference extends StatelessWidget {
  const _CodeReference();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Composition reference',
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: const Color(0xFF020B1E),
          padding: const EdgeInsets.all(20),
          child: const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              _paletteCode,
              style: TextStyle(
                color: Color(0xFFD9F4FF),
                fontFamily: 'monospace',
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final String title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (padding != EdgeInsets.zero) ...<Widget>[
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// A complete custom palette assembled from public headless primitives.
class MinimalPalette extends StatelessWidget {
  /// Creates the palette around the routed app [child].
  const MinimalPalette({required this.child, super.key});

  /// The routed application displayed below the palette.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Widget palette = KBarPortal(
      barrierColor: const Color(0xB3020B1E),
      child: KBarPositioner(
        maxWidth: 680,
        child: KBarAnimator(child: _panel(context)),
      ),
    );
    return Stack(children: <Widget>[child, palette]);
  }

  Widget _panel(BuildContext context) {
    const Color panel = Color(0xFF061426);
    const Color border = Color(0xFF1B4168);
    const Color cyan = Color(0xFF45DFFF);

    return Semantics(
      label: 'Custom command palette',
      container: true,
      child: Material(
        color: panel,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.terminal, color: cyan),
                    SizedBox(width: 12),
                    Expanded(
                      child: KBarSearchField(
                        placeholder: 'Run a command…',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                        placeholderStyle: TextStyle(
                          color: Color(0xFF7896B5),
                          fontSize: 18,
                        ),
                        padding: EdgeInsets.symmetric(vertical: 20),
                      ),
                    ),
                    Text(
                      'HEADLESS',
                      style: TextStyle(
                        color: cyan,
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: border),
              KBarResults(
                maxHeight: 410,
                padding: const EdgeInsets.symmetric(vertical: 8),
                emptyBuilder: (BuildContext context, String query) => Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'No command matches “$query”',
                    style: const TextStyle(color: Color(0xFF9BB5CF)),
                  ),
                ),
                itemBuilder:
                    (
                      BuildContext context,
                      KBarResultItem item,
                      int index,
                      bool isActive,
                    ) => switch (item) {
                      KBarSectionHeader(:final String title) => Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                        child: Text(
                          title.toUpperCase(),
                          style: const TextStyle(
                            color: cyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      KBarActionResult(:final KBarActionNode action) =>
                        _CustomCommandRow(action: action, isActive: isActive),
                    },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomCommandRow extends StatelessWidget {
  const _CustomCommandRow({required this.action, required this.isActive});

  final KBarActionNode action;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    const Color cyan = Color(0xFF45DFFF);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF123452) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isActive ? Border.all(color: cyan) : null,
      ),
      child: Row(
        children: <Widget>[
          IconTheme(
            data: IconThemeData(
              color: isActive ? cyan : const Color(0xFF9BB5CF),
              size: 20,
            ),
            child: action.icon ?? const Icon(Icons.bolt),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  action.name,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFFD9E9F7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (action.subtitle case final String subtitle)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF7896B5),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (action.isNavigational)
            const Icon(Icons.chevron_right, color: cyan, size: 19),
        ],
      ),
    );
  }
}
