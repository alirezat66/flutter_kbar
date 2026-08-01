import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_kbar/flutter_kbar.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end coverage of the bundled palette: open with a shortcut, type,
/// navigate, descend, and perform — through the real widget tree.
void main() {
  late KBarController controller;
  late List<String> performed;

  // The provider owns the controller, so it is disposed while the tree is
  // still alive. Disposing one we own from tearDown would run after the test
  // binding has torn down its FocusManager, which the FocusNode complains
  // about on the way out.

  List<KBarAction> demoActions() => <KBarAction>[
    KBarAction(
      id: 'save',
      name: 'Save file',
      shortcut: const <String>[r'$mod+s'],
      section: const KBarSection('File'),
      subtitle: 'Write the current file to disk',
      perform: (_) => performed.add('save'),
    ),
    KBarAction(
      id: 'open',
      name: 'Open file',
      section: const KBarSection('File'),
      perform: (_) => performed.add('open'),
    ),
    const KBarAction(
      id: 'theme',
      name: 'Change theme',
      section: KBarSection('Preferences'),
      shortcut: <String>['t'],
    ),
    KBarAction(
      id: 'theme.dark',
      name: 'Dark',
      parent: 'theme',
      perform: (_) => performed.add('dark'),
    ),
    KBarAction(
      id: 'theme.light',
      name: 'Light',
      parent: 'theme',
      perform: (_) => performed.add('light'),
    ),
  ];

  Future<void> pumpPalette(WidgetTester tester) async {
    performed = <String>[];
    await tester.pumpWidget(
      KBarProvider(
        actions: demoActions(),
        options: const KBarOptions(
          animations: KBarAnimations.none,
          searchThrottle: Duration.zero,
        ),
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          builder: (BuildContext context, Widget? child) =>
              KBarPalette(child: child),
          home: Builder(
            builder: (BuildContext context) {
              controller = KBarController.of(context);
              return const Scaffold(body: Center(child: Text('App content')));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    List<LogicalKeyboardKey> modifiers = const <LogicalKeyboardKey>[],
  }) async {
    for (final LogicalKeyboardKey modifier in modifiers) {
      await tester.sendKeyDownEvent(modifier);
    }
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
    for (final LogicalKeyboardKey modifier in modifiers.reversed) {
      await tester.sendKeyUpEvent(modifier);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('is not rendered until opened', (WidgetTester tester) async {
    await pumpPalette(tester);
    expect(find.text('App content'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Save file'), findsNothing);
  });

  testWidgets('opens with the toggle shortcut and shows grouped results', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await pumpPalette(tester);
      await press(
        tester,
        LogicalKeyboardKey.keyK,
        modifiers: <LogicalKeyboardKey>[LogicalKeyboardKey.metaLeft],
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Save file'), findsOneWidget);
      expect(find.text('Open file'), findsOneWidget);
      expect(find.text('Change theme'), findsOneWidget);

      // Section headings render, upper-cased by the default tile.
      expect(find.text('FILE'), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);

      // Nested children are not shown at the top level.
      expect(find.text('Dark'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('typing filters the list', (WidgetTester tester) async {
    await pumpPalette(tester);
    controller.open();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'open');
    await tester.pumpAndSettle();

    expect(find.text('Open file'), findsOneWidget);
    expect(find.text('Save file'), findsNothing);
  });

  testWidgets('searching reaches nested actions', (WidgetTester tester) async {
    await pumpPalette(tester);
    controller.open();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'dark');
    await tester.pumpAndSettle();

    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('shows an empty state for a query with no matches', (
    WidgetTester tester,
  ) async {
    await pumpPalette(tester);
    controller.open();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzzzzz');
    await tester.pumpAndSettle();

    expect(find.text('No results for "zzzzzz"'), findsOneWidget);
  });

  testWidgets('tapping a result performs it and closes', (
    WidgetTester tester,
  ) async {
    await pumpPalette(tester);
    controller.open();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open file'));
    await tester.pumpAndSettle();

    expect(performed, <String>['open']);
    expect(controller.isOpen, isFalse);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('descends into a nested action and back out', (
    WidgetTester tester,
  ) async {
    await pumpPalette(tester);
    controller.open();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change theme'));
    await tester.pumpAndSettle();

    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Save file'), findsNothing);

    // The placeholder becomes the nested action's name.
    expect(find.text('Change theme'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.backspace);
    expect(find.text('Save file'), findsOneWidget);
    expect(find.text('Dark'), findsNothing);
  });

  testWidgets('keyboard navigation and Enter perform the right action', (
    WidgetTester tester,
  ) async {
    await pumpPalette(tester);
    controller.open();
    await tester.pumpAndSettle();

    // Rows: FILE / Save file / Open file / PREFERENCES / Change theme
    expect(controller.activeAction?.id, 'save');

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(controller.activeAction?.id, 'open');

    await press(tester, LogicalKeyboardKey.enter);
    expect(performed, <String>['open']);
  });

  testWidgets('an action shortcut performs without opening the palette', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await pumpPalette(tester);
      await press(
        tester,
        LogicalKeyboardKey.keyS,
        modifiers: <LogicalKeyboardKey>[LogicalKeyboardKey.metaLeft],
      );

      expect(performed, <String>['save']);
      expect(controller.isOpen, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a parent shortcut opens the palette at that parent', (
    WidgetTester tester,
  ) async {
    await pumpPalette(tester);
    await press(tester, LogicalKeyboardKey.keyT);

    expect(controller.isOpen, isTrue);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Save file'), findsNothing);
  });

  testWidgets('Escape closes and tapping the barrier closes', (
    WidgetTester tester,
  ) async {
    await pumpPalette(tester);

    controller.open();
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.escape);
    expect(controller.isOpen, isFalse);

    controller.open();
    await tester.pumpAndSettle();
    // Near the bottom of the default 800x600 surface, well clear of the panel
    // anchored near the top.
    await tester.tapAt(const Offset(400, 560));
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
  });

  testWidgets('matched characters are highlighted', (
    WidgetTester tester,
  ) async {
    await pumpPalette(tester);
    controller.open();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'save');
    await tester.pumpAndSettle();

    final KBarHighlightedText highlighted = tester.widget<KBarHighlightedText>(
      find.byType(KBarHighlightedText).first,
    );
    expect(highlighted.text, 'Save file');
    expect(highlighted.ranges, isNotEmpty);
  });

  testWidgets('undo reverses an action when history is enabled', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final List<String> log = <String>[];
      controller = KBarController(
        options: const KBarOptions(
          animations: KBarAnimations.none,
          searchThrottle: Duration.zero,
          enableHistory: true,
        ),
      );
      await tester.pumpWidget(
        KBarProvider(
          controller: controller,
          options: const KBarOptions(
            animations: KBarAnimations.none,
            searchThrottle: Duration.zero,
            enableHistory: true,
          ),
          actions: <KBarAction>[
            KBarAction(
              id: 'dark',
              name: 'Dark mode',
              perform: (KBarActionContext context) {
                log.add('on');
                context.undoWith(() => log.add('off'));
              },
            ),
          ],
          child: MaterialApp(
            builder: (BuildContext context, Widget? child) =>
                KBarPalette(child: child),
            home: const Scaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.open();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark mode'));
      await tester.pumpAndSettle();

      expect(log, <String>['on']);
      expect(controller.history.canUndo, isTrue);

      await press(
        tester,
        LogicalKeyboardKey.keyZ,
        modifiers: <LogicalKeyboardKey>[LogicalKeyboardKey.metaLeft],
      );
      expect(log, <String>['on', 'off']);
      expect(controller.history.canRedo, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
