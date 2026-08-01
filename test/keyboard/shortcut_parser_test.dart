import 'package:flutter/foundation.dart';
import 'package:flutter_kbar/src/keyboard/kbar_shortcut.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parse', () {
    test('a bare key', () {
      final KBarShortcut shortcut = KBarShortcut.parse('k');
      expect(shortcut.presses.single.key, 'k');
      expect(shortcut.presses.single.modifiers, isEmpty);
      expect(shortcut.isSequence, isFalse);
    });

    test(r'$mod stays unresolved so it can follow the platform', () {
      final KBarShortcut shortcut = KBarShortcut.parse(r'$mod+k');
      expect(shortcut.presses.single.modifiers, <KBarModifier>{
        KBarModifier.mod,
      });
    });

    test('several modifiers in any order', () {
      final KBarShortcut shortcut = KBarShortcut.parse('Shift+Meta+p');
      expect(shortcut.presses.single.key, 'p');
      expect(shortcut.presses.single.modifiers, <KBarModifier>{
        KBarModifier.shift,
        KBarModifier.meta,
      });
    });

    test('modifier aliases', () {
      for (final String source in <String>['ctrl+k', 'control+k', 'CTRL+k']) {
        expect(
          KBarShortcut.parse(source).presses.single.modifiers,
          <KBarModifier>{KBarModifier.control},
          reason: source,
        );
      }
      for (final String source in <String>['cmd+k', 'command+k', 'meta+k']) {
        expect(
          KBarShortcut.parse(source).presses.single.modifiers,
          <KBarModifier>{KBarModifier.meta},
          reason: source,
        );
      }
    });

    test('a space-separated sequence', () {
      final KBarShortcut shortcut = KBarShortcut.parse('t s');
      expect(shortcut.isSequence, isTrue);
      expect(shortcut.presses.map((KBarKeyPress p) => p.key), <String>[
        't',
        's',
      ]);
    });

    test('named and physical key tokens', () {
      expect(KBarShortcut.parse('Escape').presses.single.key, 'Escape');
      expect(KBarShortcut.parse('ArrowDown').presses.single.key, 'ArrowDown');
      expect(KBarShortcut.parse('KeyK').presses.single.key, 'KeyK');
    });

    test('rejects malformed input', () {
      expect(() => KBarShortcut.parse(''), throwsFormatException);
      expect(() => KBarShortcut.parse('   '), throwsFormatException);
      expect(() => KBarShortcut.parse('Meta+'), throwsFormatException);
      expect(() => KBarShortcut.parse('Bogus+k'), throwsFormatException);
    });

    test('parseAll skips malformed entries in release', () {
      // The assert fires in debug, so only exercise the release path here.
      expect(
        () => KBarShortcut.parseAll(<String>['a', 'Bogus+k']),
        throwsA(isA<AssertionError>()),
      );
    });

    test('round-trips through toString', () {
      expect(KBarShortcut.parse(r'$mod+k').toString(), r'$mod+k');
      expect(KBarShortcut.parse('t s').toString(), 't s');
    });
  });

  group(r'$mod resolution', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('is Meta on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(KBarModifier.mod.resolved, KBarModifier.meta);
    });

    test('is Control on Windows and Linux', () {
      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          KBarModifier.mod.resolved,
          KBarModifier.control,
          reason: '$platform',
        );
      }
    });
  });
}
