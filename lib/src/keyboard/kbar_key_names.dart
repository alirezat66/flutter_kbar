import 'package:flutter/services.dart';

/// DOM `KeyboardEvent.key` names for keys whose [LogicalKeyboardKey.keyLabel]
/// is absent or differently spelled.
///
/// Printable keys fall through to `keyLabel`, which is release-safe. The
/// non-printables need a table: Flutter spells the arrows `Arrow Down` with a
/// space, where the web platform — and therefore kbar's shortcut strings —
/// spells them `ArrowDown`.
final Map<LogicalKeyboardKey, String> _logicalKeyNames =
    <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.backspace: 'Backspace',
      LogicalKeyboardKey.tab: 'Tab',
      LogicalKeyboardKey.enter: 'Enter',
      LogicalKeyboardKey.numpadEnter: 'Enter',
      LogicalKeyboardKey.escape: 'Escape',
      LogicalKeyboardKey.delete: 'Delete',
      LogicalKeyboardKey.space: ' ',
      LogicalKeyboardKey.capsLock: 'CapsLock',
      LogicalKeyboardKey.arrowDown: 'ArrowDown',
      LogicalKeyboardKey.arrowLeft: 'ArrowLeft',
      LogicalKeyboardKey.arrowRight: 'ArrowRight',
      LogicalKeyboardKey.arrowUp: 'ArrowUp',
      LogicalKeyboardKey.end: 'End',
      LogicalKeyboardKey.home: 'Home',
      LogicalKeyboardKey.pageDown: 'PageDown',
      LogicalKeyboardKey.pageUp: 'PageUp',
      LogicalKeyboardKey.insert: 'Insert',
      LogicalKeyboardKey.contextMenu: 'ContextMenu',
      LogicalKeyboardKey.f1: 'F1',
      LogicalKeyboardKey.f2: 'F2',
      LogicalKeyboardKey.f3: 'F3',
      LogicalKeyboardKey.f4: 'F4',
      LogicalKeyboardKey.f5: 'F5',
      LogicalKeyboardKey.f6: 'F6',
      LogicalKeyboardKey.f7: 'F7',
      LogicalKeyboardKey.f8: 'F8',
      LogicalKeyboardKey.f9: 'F9',
      LogicalKeyboardKey.f10: 'F10',
      LogicalKeyboardKey.f11: 'F11',
      LogicalKeyboardKey.f12: 'F12',
      LogicalKeyboardKey.control: 'Control',
      LogicalKeyboardKey.controlLeft: 'Control',
      LogicalKeyboardKey.controlRight: 'Control',
      LogicalKeyboardKey.shift: 'Shift',
      LogicalKeyboardKey.shiftLeft: 'Shift',
      LogicalKeyboardKey.shiftRight: 'Shift',
      LogicalKeyboardKey.alt: 'Alt',
      LogicalKeyboardKey.altLeft: 'Alt',
      LogicalKeyboardKey.altRight: 'Alt',
      LogicalKeyboardKey.meta: 'Meta',
      LogicalKeyboardKey.metaLeft: 'Meta',
      LogicalKeyboardKey.metaRight: 'Meta',
    };

/// DOM `KeyboardEvent.code` names.
///
/// This table is not optional. [PhysicalKeyboardKey] exposes no `keyLabel`, and
/// its `debugName` is wrapped in an assert — meaning it is **null in release
/// builds**. Deriving codes from `debugName` produces a package that works
/// under `flutter run` and silently fails every `KeyK`-style binding in
/// `flutter build`.
final Map<PhysicalKeyboardKey, String> _physicalKeyCodes =
    <PhysicalKeyboardKey, String>{
      PhysicalKeyboardKey.keyA: 'KeyA',
      PhysicalKeyboardKey.keyB: 'KeyB',
      PhysicalKeyboardKey.keyC: 'KeyC',
      PhysicalKeyboardKey.keyD: 'KeyD',
      PhysicalKeyboardKey.keyE: 'KeyE',
      PhysicalKeyboardKey.keyF: 'KeyF',
      PhysicalKeyboardKey.keyG: 'KeyG',
      PhysicalKeyboardKey.keyH: 'KeyH',
      PhysicalKeyboardKey.keyI: 'KeyI',
      PhysicalKeyboardKey.keyJ: 'KeyJ',
      PhysicalKeyboardKey.keyK: 'KeyK',
      PhysicalKeyboardKey.keyL: 'KeyL',
      PhysicalKeyboardKey.keyM: 'KeyM',
      PhysicalKeyboardKey.keyN: 'KeyN',
      PhysicalKeyboardKey.keyO: 'KeyO',
      PhysicalKeyboardKey.keyP: 'KeyP',
      PhysicalKeyboardKey.keyQ: 'KeyQ',
      PhysicalKeyboardKey.keyR: 'KeyR',
      PhysicalKeyboardKey.keyS: 'KeyS',
      PhysicalKeyboardKey.keyT: 'KeyT',
      PhysicalKeyboardKey.keyU: 'KeyU',
      PhysicalKeyboardKey.keyV: 'KeyV',
      PhysicalKeyboardKey.keyW: 'KeyW',
      PhysicalKeyboardKey.keyX: 'KeyX',
      PhysicalKeyboardKey.keyY: 'KeyY',
      PhysicalKeyboardKey.keyZ: 'KeyZ',
      PhysicalKeyboardKey.digit1: 'Digit1',
      PhysicalKeyboardKey.digit2: 'Digit2',
      PhysicalKeyboardKey.digit3: 'Digit3',
      PhysicalKeyboardKey.digit4: 'Digit4',
      PhysicalKeyboardKey.digit5: 'Digit5',
      PhysicalKeyboardKey.digit6: 'Digit6',
      PhysicalKeyboardKey.digit7: 'Digit7',
      PhysicalKeyboardKey.digit8: 'Digit8',
      PhysicalKeyboardKey.digit9: 'Digit9',
      PhysicalKeyboardKey.digit0: 'Digit0',
      PhysicalKeyboardKey.enter: 'Enter',
      PhysicalKeyboardKey.escape: 'Escape',
      PhysicalKeyboardKey.backspace: 'Backspace',
      PhysicalKeyboardKey.tab: 'Tab',
      PhysicalKeyboardKey.space: 'Space',
      PhysicalKeyboardKey.minus: 'Minus',
      PhysicalKeyboardKey.equal: 'Equal',
      PhysicalKeyboardKey.bracketLeft: 'BracketLeft',
      PhysicalKeyboardKey.bracketRight: 'BracketRight',
      PhysicalKeyboardKey.backslash: 'Backslash',
      PhysicalKeyboardKey.semicolon: 'Semicolon',
      PhysicalKeyboardKey.quote: 'Quote',
      PhysicalKeyboardKey.backquote: 'Backquote',
      PhysicalKeyboardKey.comma: 'Comma',
      PhysicalKeyboardKey.period: 'Period',
      PhysicalKeyboardKey.slash: 'Slash',
      PhysicalKeyboardKey.capsLock: 'CapsLock',
      PhysicalKeyboardKey.f1: 'F1',
      PhysicalKeyboardKey.f2: 'F2',
      PhysicalKeyboardKey.f3: 'F3',
      PhysicalKeyboardKey.f4: 'F4',
      PhysicalKeyboardKey.f5: 'F5',
      PhysicalKeyboardKey.f6: 'F6',
      PhysicalKeyboardKey.f7: 'F7',
      PhysicalKeyboardKey.f8: 'F8',
      PhysicalKeyboardKey.f9: 'F9',
      PhysicalKeyboardKey.f10: 'F10',
      PhysicalKeyboardKey.f11: 'F11',
      PhysicalKeyboardKey.f12: 'F12',
      PhysicalKeyboardKey.insert: 'Insert',
      PhysicalKeyboardKey.home: 'Home',
      PhysicalKeyboardKey.pageUp: 'PageUp',
      PhysicalKeyboardKey.delete: 'Delete',
      PhysicalKeyboardKey.end: 'End',
      PhysicalKeyboardKey.pageDown: 'PageDown',
      PhysicalKeyboardKey.arrowRight: 'ArrowRight',
      PhysicalKeyboardKey.arrowLeft: 'ArrowLeft',
      PhysicalKeyboardKey.arrowDown: 'ArrowDown',
      PhysicalKeyboardKey.arrowUp: 'ArrowUp',
      PhysicalKeyboardKey.controlLeft: 'ControlLeft',
      PhysicalKeyboardKey.shiftLeft: 'ShiftLeft',
      PhysicalKeyboardKey.altLeft: 'AltLeft',
      PhysicalKeyboardKey.metaLeft: 'MetaLeft',
      PhysicalKeyboardKey.controlRight: 'ControlRight',
      PhysicalKeyboardKey.shiftRight: 'ShiftRight',
      PhysicalKeyboardKey.altRight: 'AltRight',
      PhysicalKeyboardKey.metaRight: 'MetaRight',
    };

/// The DOM `key` name for [key], or null if there is no sensible one.
///
/// Printable keys resolve through [LogicalKeyboardKey.keyLabel], which is safe
/// in release builds.
String? kbarLogicalKeyName(LogicalKeyboardKey key) {
  final String? mapped = _logicalKeyNames[key];
  if (mapped != null) return mapped;
  final String label = key.keyLabel;
  return label.isEmpty ? null : label;
}

/// The DOM `code` name for [key], or null if it is not in the table.
String? kbarPhysicalKeyCode(PhysicalKeyboardKey key) => _physicalKeyCodes[key];

/// Whether [key] is a modifier, which must not advance or break a shortcut
/// sequence.
bool kbarIsModifierKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.shift ||
    key == LogicalKeyboardKey.shiftLeft ||
    key == LogicalKeyboardKey.shiftRight ||
    key == LogicalKeyboardKey.control ||
    key == LogicalKeyboardKey.controlLeft ||
    key == LogicalKeyboardKey.controlRight ||
    key == LogicalKeyboardKey.alt ||
    key == LogicalKeyboardKey.altLeft ||
    key == LogicalKeyboardKey.altRight ||
    key == LogicalKeyboardKey.meta ||
    key == LogicalKeyboardKey.metaLeft ||
    key == LogicalKeyboardKey.metaRight ||
    key == LogicalKeyboardKey.capsLock ||
    key == LogicalKeyboardKey.numLock ||
    key == LogicalKeyboardKey.scrollLock;
