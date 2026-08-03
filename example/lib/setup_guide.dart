import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_kbar/flutter_kbar.dart';

/// A copyable, step-by-step guide to adding flutter_kbar to an app.
class SetupGuidePage extends StatelessWidget {
  /// Creates the setup guide.
  const SetupGuidePage({super.key});

  static const List<_GuideStep> _steps = <_GuideStep>[
    _GuideStep(
      title: 'Add the package',
      description: 'Add flutter_kbar to your app, then fetch dependencies.',
      language: 'pubspec.yaml',
      code: '''dependencies:
  flutter_kbar: ^1.0.0''',
    ),
    _GuideStep(
      title: 'Define your commands',
      description:
          'Each action needs an id and label. Add search terms, an icon, '
          'a shortcut, or a section when useful.',
      language: 'dart',
      code: r'''final actions = <KBarAction>[
  KBarAction(
    id: 'save',
    name: 'Save file',
    subtitle: 'Write changes to disk',
    icon: const Icon(Icons.save_outlined),
    section: const KBarSection('File'),
    shortcut: const <String>[r'$mod+s'],
    perform: (_) => saveFile(),
  ),
];''',
    ),
    _GuideStep(
      title: 'Wrap your app',
      description:
          'The provider owns the commands. Place KBarPalette in the app '
          'builder so it appears above every route.',
      language: 'dart',
      code: r'''KBarProvider(
  actions: actions,
  child: MaterialApp(
    builder: (context, child) => KBarPalette(
      child: child!,
    ),
    home: const HomePage(),
  ),
)''',
    ),
    _GuideStep(
      title: 'Open the palette',
      description:
          'The default shortcut is Cmd+K on Apple platforms and Ctrl+K '
          'everywhere else. You can also open it from any descendant widget.',
      language: 'dart',
      code: '''FilledButton.icon(
  onPressed: () => context.kbar.open(),
  icon: const Icon(Icons.search),
  label: const Text('Open command palette'),
)''',
    ),
    _GuideStep(
      title: 'Register page commands',
      description:
          'Commands registered this way exist only while their page is in '
          'the widget tree.',
      language: 'dart',
      code: '''KBarRegisterActions(
  actions: <KBarAction>[
    KBarAction(
      id: 'page.refresh',
      name: 'Refresh page',
      perform: (_) => refresh(),
    ),
  ],
  child: const MyPage(),
)''',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Setup guide')),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 64),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'FROM ZERO TO COMMAND PALETTE',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add flutter_kbar in five steps.',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Copy each block in order. The result is a working, '
                      'keyboard-first palette you can extend one command at '
                      'a time.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    for (final (int index, _GuideStep step) in _steps.indexed)
                      _StepCard(index: index + 1, step: step),
                    const SizedBox(height: 8),
                    _DoneCard(onOpen: () => context.kbar.open()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep {
  const _GuideStep({
    required this.title,
    required this.description,
    required this.language,
    required this.code,
  });

  final String title;
  final String description;
  final String language;
  final String code;
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.index, required this.step});

  final int index;
  final _GuideStep step;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              index.toString().padLeft(2, '0'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  step.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  step.description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                _CodeBlock(language: step.language, code: step.code),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.language, required this.code});

  final String language;
  final String code;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$language copied'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    const Color editor = Color(0xFF020B1E);
    const Color editorBorder = Color(0xFF183358);
    const Color codeColor = Color(0xFFD9F4FF);
    const Color utilityColor = Color(0xFF79DFFF);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: editor,
          border: Border.fromBorderSide(BorderSide(color: editorBorder)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.only(left: 16, right: 6),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: editorBorder)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.code, size: 16, color: utilityColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      language,
                      style: const TextStyle(
                        color: utilityColor,
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _copy(context),
                    icon: const Icon(Icons.content_copy, size: 15),
                    label: const Text('Copy'),
                    style: TextButton.styleFrom(foregroundColor: utilityColor),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(18),
              child: Text(
                code,
                style: const TextStyle(
                  color: codeColor,
                  fontFamily: 'monospace',
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 20,
        runSpacing: 16,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'That is the complete setup.',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Open the real palette and try it now.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.keyboard_command_key),
            label: const Text('Try the palette'),
          ),
        ],
      ),
    );
  }
}
