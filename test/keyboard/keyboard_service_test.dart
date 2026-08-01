import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_kbar/flutter_kbar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late KBarController controller;

  tearDown(() => controller.dispose());

  /// Runs a widget test under a fixed target platform.
  ///
  /// The override has to be cleared before the test body returns:
  /// `flutter_test` verifies that no foundation debug variable is still set at
  /// that point, which is earlier than any `tearDown` runs.
  void testWidgetsOn(
    String description,
    Future<void> Function(WidgetTester tester) body, {
    TargetPlatform platform = TargetPlatform.macOS,
  }) {
    testWidgets(description, (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  /// Mounts a provider with a real text field alongside, so focus-dependent
  /// behaviour can be exercised.
  Future<void> pumpApp(
    WidgetTester tester, {
    List<KBarAction> actions = const <KBarAction>[],
    KBarOptions options = const KBarOptions(
      animations: KBarAnimations.none,
      searchThrottle: Duration.zero,
    ),
    bool withTextField = false,
  }) async {
    controller = KBarController(options: options);
    await tester.pumpWidget(
      KBarProvider(
        controller: controller,
        actions: actions,
        options: options,
        child: MaterialApp(
          home: Scaffold(
            body: withTextField
                ? const TextField(key: Key('outside'))
                : const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
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
    await tester.pump();
  }

  group('toggle shortcut', () {
    testWidgetsOn('Cmd+K toggles on macOS and Ctrl+K does not', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      await press(
        tester,
        LogicalKeyboardKey.keyK,
        modifiers: <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft],
      );
      expect(controller.isOpen, isFalse, reason: 'Control is not \$mod here');

      await press(
        tester,
        LogicalKeyboardKey.keyK,
        modifiers: <LogicalKeyboardKey>[LogicalKeyboardKey.metaLeft],
      );
      expect(controller.isOpen, isTrue);

      await press(
        tester,
        LogicalKeyboardKey.keyK,
        modifiers: <LogicalKeyboardKey>[LogicalKeyboardKey.metaLeft],
      );
      expect(controller.isOpen, isFalse, reason: 'the same binding closes it');
    });

    testWidgetsOn(
      'Ctrl+K toggles on Windows and Cmd+K does not',
      (WidgetTester tester) async {
        await pumpApp(tester);

        await press(
          tester,
          LogicalKeyboardKey.keyK,
          modifiers: <LogicalKeyboardKey>[LogicalKeyboardKey.metaLeft],
        );
        expect(controller.isOpen, isFalse);

        await press(
          tester,
          LogicalKeyboardKey.keyK,
          modifiers: <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft],
        );
        expect(controller.isOpen, isTrue);
      },
      platform: TargetPlatform.windows,
    );

    testWidgetsOn('a bare k does not open the palette', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await press(tester, LogicalKeyboardKey.keyK);
      expect(controller.isOpen, isFalse);
    });

    testWidgetsOn('fires even while an unrelated text field has focus', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, withTextField: true);
      await tester.tap(find.byKey(const Key('outside')));
      await tester.pump();

      await press(
        tester,
        LogicalKeyboardKey.keyK,
        modifiers: <LogicalKeyboardKey>[LogicalKeyboardKey.metaLeft],
      );
      expect(controller.isOpen, isTrue);
    });

    testWidgetsOn('a fallback binding also works', (WidgetTester tester) async {
      await pumpApp(
        tester,
        options: const KBarOptions(
          animations: KBarAnimations.none,
          searchThrottle: Duration.zero,
          toggleShortcuts: <String>[r'$mod+k', r'$mod+shift+p'],
        ),
      );

      await press(
        tester,
        LogicalKeyboardKey.keyP,
        modifiers: <LogicalKeyboardKey>[
          LogicalKeyboardKey.metaLeft,
          LogicalKeyboardKey.shiftLeft,
        ],
      );
      expect(controller.isOpen, isTrue);
    });

    testWidgetsOn('onOpen and onClose fire for user-driven toggles only', (
      WidgetTester tester,
    ) async {
      final List<String> events = <String>[];
      await pumpApp(
        tester,
        options: KBarOptions(
          animations: KBarAnimations.none,
          searchThrottle: Duration.zero,
          callbacks: KBarCallbacks(
            onOpen: () => events.add('open'),
            onClose: () => events.add('close'),
          ),
        ),
      );

      controller.toggle();
      await tester.pump();
      expect(events, isEmpty, reason: 'programmatic toggles stay silent');

      controller.close();
      await tester.pump();

      await press(
        tester,
        LogicalKeyboardKey.keyK,
        modifiers: <LogicalKeyboardKey>[LogicalKeyboardKey.metaLeft],
      );
      expect(events, <String>['open']);
    });
  });

  group('action shortcuts', () {
    testWidgetsOn('fire only while the palette is closed', (
      WidgetTester tester,
    ) async {
      int fired = 0;
      await pumpApp(
        tester,
        actions: <KBarAction>[
          KBarAction(
            id: 'a',
            name: 'Alpha',
            shortcut: const <String>['a'],
            perform: (_) => fired++,
          ),
        ],
      );

      await press(tester, LogicalKeyboardKey.keyA);
      expect(fired, 1);

      controller.open();
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyA);
      expect(fired, 1, reason: 'while open, a is text input');
    });

    testWidgetsOn('are suppressed while a text field has focus', (
      WidgetTester tester,
    ) async {
      int fired = 0;
      await pumpApp(
        tester,
        withTextField: true,
        actions: <KBarAction>[
          KBarAction(
            id: 'a',
            name: 'Alpha',
            shortcut: const <String>['a'],
            perform: (_) => fired++,
          ),
        ],
      );

      await press(tester, LogicalKeyboardKey.keyA);
      expect(fired, 1);

      await tester.tap(find.byKey(const Key('outside')));
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyA);
      expect(fired, 1, reason: 'typing in a form must not fire shortcuts');
    });

    testWidgetsOn('a longer sequence wins over a shorter one', (
      WidgetTester tester,
    ) async {
      final List<String> fired = <String>[];
      await pumpApp(
        tester,
        actions: <KBarAction>[
          KBarAction(
            id: 's',
            name: 'S',
            shortcut: const <String>['s'],
            perform: (_) => fired.add('s'),
          ),
          KBarAction(
            id: 'ts',
            name: 'T then S',
            shortcut: const <String>['t', 's'],
            perform: (_) => fired.add('t s'),
          ),
        ],
      );

      await press(tester, LogicalKeyboardKey.keyT);
      await press(tester, LogicalKeyboardKey.keyS);
      expect(fired, <String>['t s'], reason: 'the bare s must not also fire');
    });

    testWidgetsOn('a sequence expires after the action timeout', (
      WidgetTester tester,
    ) async {
      final List<String> fired = <String>[];
      await pumpApp(
        tester,
        actions: <KBarAction>[
          KBarAction(
            id: 'ts',
            name: 'T then S',
            shortcut: const <String>['t', 's'],
            perform: (_) => fired.add('t s'),
          ),
        ],
      );

      await press(tester, LogicalKeyboardKey.keyT);
      await tester.pump(const Duration(milliseconds: 401));
      await press(tester, LogicalKeyboardKey.keyS);
      expect(fired, isEmpty, reason: 'the sequence should have lapsed');

      await press(tester, LogicalKeyboardKey.keyT);
      await tester.pump(const Duration(milliseconds: 100));
      await press(tester, LogicalKeyboardKey.keyS);
      expect(fired, <String>['t s']);
    });

    testWidgetsOn('a shortcut on a parent opens the palette at that parent', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        actions: <KBarAction>[
          const KBarAction(
            id: 'theme',
            name: 'Set theme',
            shortcut: <String>['t'],
          ),
          const KBarAction(id: 'dark', name: 'Dark', parent: 'theme'),
        ],
      );

      await press(tester, LogicalKeyboardKey.keyT);
      expect(controller.isOpen, isTrue);
      expect(controller.state.currentRootActionId, 'theme');
    });

    testWidgetsOn('never fire while disabled', (WidgetTester tester) async {
      int fired = 0;
      await pumpApp(
        tester,
        actions: <KBarAction>[
          KBarAction(
            id: 'a',
            name: 'Alpha',
            shortcut: const <String>['a'],
            perform: (_) => fired++,
          ),
        ],
      );
      controller.disable(true);
      await tester.pump();

      await press(tester, LogicalKeyboardKey.keyA);
      await press(
        tester,
        LogicalKeyboardKey.keyK,
        modifiers: <LogicalKeyboardKey>[LogicalKeyboardKey.metaLeft],
      );

      expect(fired, 0);
      expect(controller.isOpen, isFalse);
    });

    testWidgetsOn('newly registered actions become bindable', (
      WidgetTester tester,
    ) async {
      int fired = 0;
      await pumpApp(tester);

      controller.registerActions(<KBarAction>[
        KBarAction(
          id: 'late',
          name: 'Late',
          shortcut: const <String>['l'],
          perform: (_) => fired++,
        ),
      ]);
      await tester.pump();

      await press(tester, LogicalKeyboardKey.keyL);
      expect(fired, 1);
    });
  });

  group('keys while open', () {
    Future<void> pumpOpen(
      WidgetTester tester, {
      List<KBarAction> actions = const <KBarAction>[],
    }) async {
      await pumpApp(tester, actions: actions);
      controller.open();
      await tester.pump();
    }

    testWidgetsOn('Escape closes', (WidgetTester tester) async {
      await pumpOpen(tester);
      await press(tester, LogicalKeyboardKey.escape);
      expect(controller.isOpen, isFalse);
    });

    testWidgetsOn('arrows and Ctrl+N/P move the highlight', (
      WidgetTester tester,
    ) async {
      await pumpOpen(
        tester,
        actions: <KBarAction>[
          const KBarAction(id: 'a', name: 'Alpha'),
          const KBarAction(id: 'b', name: 'Beta'),
          const KBarAction(id: 'c', name: 'Gamma'),
        ],
      );
      expect(controller.state.activeIndex, 0);

      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(controller.state.activeIndex, 1);

      await press(
        tester,
        LogicalKeyboardKey.keyN,
        modifiers: <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft],
      );
      expect(controller.state.activeIndex, 2);

      await press(
        tester,
        LogicalKeyboardKey.keyP,
        modifiers: <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft],
      );
      expect(controller.state.activeIndex, 1);

      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(controller.state.activeIndex, 0);
    });

    testWidgetsOn('Enter performs the highlighted action', (
      WidgetTester tester,
    ) async {
      final List<String> performed = <String>[];
      await pumpOpen(
        tester,
        actions: <KBarAction>[
          KBarAction(
            id: 'a',
            name: 'Alpha',
            perform: (_) => performed.add('a'),
          ),
          KBarAction(id: 'b', name: 'Beta', perform: (_) => performed.add('b')),
        ],
      );

      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.enter);
      await tester.pump();

      expect(performed, <String>['b']);
      expect(controller.isOpen, isFalse);
    });

    testWidgetsOn('Backspace leaves a nested action only when empty', (
      WidgetTester tester,
    ) async {
      await pumpOpen(
        tester,
        actions: <KBarAction>[
          const KBarAction(id: 'p', name: 'Parent'),
          const KBarAction(id: 'c', name: 'Child', parent: 'p'),
        ],
      );
      controller.setCurrentRootAction('p');
      await tester.pump();

      controller.setSearch('x');
      await tester.pump();
      await press(tester, LogicalKeyboardKey.backspace);
      expect(
        controller.state.currentRootActionId,
        'p',
        reason: 'Backspace should delete text, not navigate',
      );

      controller.setSearch('');
      await tester.pump();
      await press(tester, LogicalKeyboardKey.backspace);
      expect(controller.state.currentRootActionId, isNull);
    });

    testWidgetsOn('ordinary characters are left for the search field', (
      WidgetTester tester,
    ) async {
      int fired = 0;
      await pumpOpen(
        tester,
        actions: <KBarAction>[
          KBarAction(
            id: 'a',
            name: 'Alpha',
            shortcut: const <String>['a'],
            perform: (_) => fired++,
          ),
        ],
      );

      await press(tester, LogicalKeyboardKey.keyA);
      expect(fired, 0, reason: 'a is text while the palette is open');
    });
  });

  group('lifecycle', () {
    testWidgetsOn('the global handler is removed on unmount', (
      WidgetTester tester,
    ) async {
      int fired = 0;
      await pumpApp(
        tester,
        actions: <KBarAction>[
          KBarAction(
            id: 'a',
            name: 'Alpha',
            shortcut: const <String>['a'],
            perform: (_) => fired++,
          ),
        ],
      );
      await press(tester, LogicalKeyboardKey.keyA);
      expect(fired, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await press(tester, LogicalKeyboardKey.keyA);
      expect(fired, 1, reason: 'a detached service must not still respond');
    });
  });
}
