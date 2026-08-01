import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../util/kbar_platform.dart';
import 'kbar_key_names.dart';

/// A modifier that must be held for a key press to match.
enum KBarModifier {
  /// Shift.
  shift,

  /// Command on Apple platforms, Windows/Super elsewhere.
  meta,

  /// Option on Apple platforms, Alt elsewhere.
  alt,

  /// Control.
  control,

  /// `$mod`: Command on Apple platforms, Control everywhere else.
  ///
  /// Left unresolved until match time so that a parsed shortcut stays
  /// platform-agnostic — and so `debugDefaultTargetPlatformOverride` actually
  /// takes effect in tests.
  mod;

  /// This modifier with `$mod` resolved for the current platform.
  KBarModifier get resolved => this != KBarModifier.mod
      ? this
      : (kbarIsApplePlatform ? KBarModifier.meta : KBarModifier.control);
}

/// A single key press: a key plus the exact set of modifiers held with it.
@immutable
class KBarKeyPress {
  /// Creates a key press.
  const KBarKeyPress({
    required this.key,
    this.modifiers = const <KBarModifier>{},
  });

  /// The key token, as written in the shortcut string.
  ///
  /// May be a DOM `key` name (`k`, `Escape`, `ArrowDown`) or a DOM `code`
  /// (`KeyK`, `Digit1`); both are accepted, as in tinykeys.
  final String key;

  /// Modifiers that must be held — no more, no fewer.
  final Set<KBarModifier> modifiers;

  /// [modifiers] with `$mod` resolved for the current platform.
  Set<KBarModifier> get resolvedModifiers => <KBarModifier>{
    for (final KBarModifier modifier in modifiers) modifier.resolved,
  };

  /// Whether [event] is this press.
  ///
  /// The modifier set must match exactly: `k` does not match Command+K.
  bool matches(KeyEvent event) {
    if (!setEquals(resolvedModifiers, kbarPressedModifiers())) return false;

    final String token = key.toLowerCase();

    final String? name = kbarLogicalKeyName(event.logicalKey);
    if (name != null && name.toLowerCase() == token) return true;

    final String? character = event.character;
    if (character != null && character.toLowerCase() == token) return true;

    return kbarPhysicalKeyCode(event.physicalKey) == key;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KBarKeyPress &&
          other.key == key &&
          setEquals(other.modifiers, modifiers);

  @override
  int get hashCode => Object.hash(key, Object.hashAllUnordered(modifiers));

  @override
  String toString() => <String>[
    for (final KBarModifier modifier in modifiers)
      modifier == KBarModifier.mod ? r'$mod' : modifier.name,
    key,
  ].join('+');
}

/// The modifiers currently held down.
Set<KBarModifier> kbarPressedModifiers() {
  final HardwareKeyboard keyboard = HardwareKeyboard.instance;
  return <KBarModifier>{
    if (keyboard.isShiftPressed) KBarModifier.shift,
    if (keyboard.isMetaPressed) KBarModifier.meta,
    if (keyboard.isAltPressed) KBarModifier.alt,
    if (keyboard.isControlPressed) KBarModifier.control,
  };
}

/// A key binding: one press, or a sequence of presses typed in order.
///
/// Written in tinykeys syntax, the same strings kbar uses:
///
/// ```dart
/// KBarShortcut.parse(r'$mod+k');   // Command+K, or Control+K off Apple
/// KBarShortcut.parse('g h');       // press g, then h
/// KBarShortcut.parse('Shift+Meta+p');
/// ```
@immutable
class KBarShortcut {
  /// Creates a shortcut from already-parsed presses.
  const KBarShortcut(this.presses, {this.source = ''});

  /// Parses one tinykeys shortcut string.
  ///
  /// Throws [FormatException] if [source] is empty or a press has no key.
  factory KBarShortcut.parse(String source) {
    final List<String> chunks = source
        .split(' ')
        .where((String chunk) => chunk.isNotEmpty)
        .toList();
    if (chunks.isEmpty) {
      throw FormatException('Empty shortcut', source);
    }

    final List<KBarKeyPress> presses = <KBarKeyPress>[];
    for (final String chunk in chunks) {
      final List<String> parts = chunk.split('+');
      final String key = parts.removeLast();
      if (key.isEmpty) {
        throw FormatException('Shortcut press "$chunk" has no key', source);
      }
      presses.add(
        KBarKeyPress(
          key: key,
          modifiers: <KBarModifier>{
            for (final String part in parts) _parseModifier(part, source),
          },
        ),
      );
    }
    return KBarShortcut(presses, source: source);
  }

  /// Parses several shortcut strings, skipping any that are malformed.
  ///
  /// A bad shortcut in a user's action list should not take down the app; the
  /// offending entry is asserted in debug and ignored in release.
  static List<KBarShortcut> parseAll(Iterable<String> sources) {
    final List<KBarShortcut> parsed = <KBarShortcut>[];
    for (final String source in sources) {
      try {
        parsed.add(KBarShortcut.parse(source));
      } on FormatException catch (error) {
        assert(false, 'Invalid kbar shortcut "$source": ${error.message}');
      }
    }
    return parsed;
  }

  static KBarModifier _parseModifier(String token, String source) {
    switch (token.toLowerCase()) {
      case r'$mod':
      case 'mod':
        return KBarModifier.mod;
      case 'shift':
        return KBarModifier.shift;
      case 'meta':
      case 'cmd':
      case 'command':
      case 'super':
      case 'win':
        return KBarModifier.meta;
      case 'alt':
      case 'option':
        return KBarModifier.alt;
      case 'control':
      case 'ctrl':
        return KBarModifier.control;
      default:
        throw FormatException('Unknown modifier "$token"', source);
    }
  }

  /// The presses to type, in order. More than one makes this a sequence.
  final List<KBarKeyPress> presses;

  /// The string this was parsed from, for diagnostics.
  final String source;

  /// Whether this shortcut requires more than one press.
  bool get isSequence => presses.length > 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KBarShortcut && listEquals(other.presses, presses);

  @override
  int get hashCode => Object.hashAll(presses);

  @override
  String toString() =>
      presses.map((KBarKeyPress press) => press.toString()).join(' ');
}
