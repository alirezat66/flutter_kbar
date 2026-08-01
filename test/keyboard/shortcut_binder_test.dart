import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_kbar/src/keyboard/kbar_shortcut.dart';
import 'package:flutter_kbar/src/keyboard/kbar_shortcut_binder.dart';
import 'package:flutter_test/flutter_test.dart';

/// A synthetic key-down event for [key].
KeyDownEvent down(LogicalKeyboardKey key, PhysicalKeyboardKey physical) =>
    KeyDownEvent(
      logicalKey: key,
      physicalKey: physical,
      timeStamp: Duration.zero,
      character: key.keyLabel.toLowerCase(),
    );

KeyDownEvent downT() => down(LogicalKeyboardKey.keyT, PhysicalKeyboardKey.keyT);
KeyDownEvent downS() => down(LogicalKeyboardKey.keyS, PhysicalKeyboardKey.keyS);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KBarShortcutBinder binder;
  late List<String> fired;

  setUp(() {
    fired = <String>[];
    binder = KBarShortcutBinder(timeout: const Duration(milliseconds: 400));
  });

  tearDown(() => binder.dispose());

  void bindAll() {
    binder
      ..bind(KBarShortcut.parse('s'), () => fired.add('s'))
      ..bind(KBarShortcut.parse('t s'), () => fired.add('t s'));
  }

  test('a single press fires', () {
    binder.bind(KBarShortcut.parse('s'), () => fired.add('s'));
    expect(binder.handle(downS()), isTrue);
    expect(fired, <String>['s']);
  });

  test('a sequence fires only after every press', () {
    binder.bind(KBarShortcut.parse('t s'), () => fired.add('t s'));

    expect(binder.handle(downT()), isFalse);
    expect(fired, isEmpty);
    expect(binder.isArmed, isTrue);

    expect(binder.handle(downS()), isTrue);
    expect(fired, <String>['t s']);
    expect(binder.isArmed, isFalse);
  });

  test('a longer sequence wins over a shorter binding', () {
    bindAll();

    expect(binder.handle(downT()), isFalse);
    expect(binder.handle(downS()), isTrue);
    expect(fired, <String>[
      't s',
    ], reason: 'the bare s binding must not also fire');
  });

  test('the shorter binding still fires on its own', () {
    bindAll();
    expect(binder.handle(downS()), isTrue);
    expect(fired, <String>['s']);
  });

  test('an armed sequence lapses after the timeout', () {
    fakeAsync((FakeAsync async) {
      binder.bind(KBarShortcut.parse('t s'), () => fired.add('t s'));

      binder.handle(downT());
      expect(binder.isArmed, isTrue);

      async.elapse(const Duration(milliseconds: 399));
      expect(binder.isArmed, isTrue);

      async.elapse(const Duration(milliseconds: 2));
      expect(binder.isArmed, isFalse);

      binder.handle(downS());
      expect(fired, isEmpty);
    });
  });

  test('two binders keep independent timeouts', () {
    fakeAsync((FakeAsync async) {
      final KBarShortcutBinder toggle = KBarShortcutBinder(
        timeout: const Duration(milliseconds: 1000),
      )..bind(KBarShortcut.parse('t s'), () => fired.add('toggle'));
      final KBarShortcutBinder action = KBarShortcutBinder(
        timeout: const Duration(milliseconds: 400),
      )..bind(KBarShortcut.parse('t s'), () => fired.add('action'));

      toggle.handle(downT());
      action.handle(downT());

      async.elapse(const Duration(milliseconds: 500));
      expect(action.isArmed, isFalse, reason: 'the 400ms window lapsed');
      expect(toggle.isArmed, isTrue, reason: 'the 1000ms window has not');

      toggle.dispose();
      action.dispose();
    });
  });

  test('a mismatch resets without retrying as a fresh start', () {
    // tinykeys parity: after t, an unrelated key drops the sequence outright.
    binder.bind(KBarShortcut.parse('t s'), () => fired.add('t s'));
    binder.handle(downT());
    binder.handle(down(LogicalKeyboardKey.keyX, PhysicalKeyboardKey.keyX));
    expect(binder.isArmed, isFalse);

    binder.handle(downS());
    expect(fired, isEmpty);
  });

  test('a bare modifier neither advances nor breaks a sequence', () {
    binder.bind(KBarShortcut.parse('t s'), () => fired.add('t s'));
    binder.handle(downT());
    binder.handle(
      down(LogicalKeyboardKey.shiftLeft, PhysicalKeyboardKey.shiftLeft),
    );
    expect(binder.isArmed, isTrue);

    binder.handle(downS());
    expect(fired, <String>['t s']);
  });

  test('key-up events are ignored', () {
    binder.bind(KBarShortcut.parse('s'), () => fired.add('s'));
    expect(
      binder.handle(
        const KeyUpEvent(
          logicalKey: LogicalKeyboardKey.keyS,
          physicalKey: PhysicalKeyboardKey.keyS,
          timeStamp: Duration.zero,
        ),
      ),
      isFalse,
    );
    expect(fired, isEmpty);
  });

  group(r'$mod', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('matches Meta on macOS only when Meta is held', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      binder.bind(KBarShortcut.parse(r'$mod+k'), () => fired.add('mod+k'));

      // No modifier held, so the binding must not match.
      binder.handle(down(LogicalKeyboardKey.keyK, PhysicalKeyboardKey.keyK));
      expect(fired, isEmpty);
    });
  });
}
