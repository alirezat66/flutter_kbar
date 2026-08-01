import 'dart:async';

import 'package:flutter/services.dart';

import 'kbar_key_names.dart';
import 'kbar_shortcut.dart';

/// Matches key events against a set of shortcuts, tracking partially-typed
/// sequences.
///
/// One binder owns one sequence cursor and one timeout, which is how the
/// palette runs the toggle bindings on a 1000 ms window and action shortcuts on
/// a 400 ms window without the two interfering.
class KBarShortcutBinder {
  /// Creates a binder whose sequences expire after [timeout].
  KBarShortcutBinder({required this.timeout});

  /// How long a partially-typed sequence stays armed.
  Duration timeout;

  final List<_Binding> _bindings = <_Binding>[];
  int _index = 0;
  Timer? _timer;

  /// Whether a sequence is part-way typed.
  bool get isArmed => _index > 0;

  /// Registers [shortcut] to invoke [onFire].
  ///
  /// Bindings are kept sorted longest-sequence-first, which is what makes
  /// `t s` win over a bare `s`: the first match fires and the loop stops, so no
  /// per-event bookkeeping is needed to suppress the shorter binding.
  void bind(KBarShortcut shortcut, VoidCallback onFire) {
    _bindings.add(_Binding(shortcut, onFire));
    _bindings.sort(
      (_Binding a, _Binding b) =>
          b.shortcut.presses.length.compareTo(a.shortcut.presses.length),
    );
  }

  /// Removes every binding and disarms any sequence in progress.
  void clear() {
    _bindings.clear();
    reset();
  }

  /// Abandons a partially-typed sequence.
  void reset() {
    _index = 0;
    _timer?.cancel();
    _timer = null;
  }

  /// Offers [event] to the bindings.
  ///
  /// Returns true only when a shortcut fired, which is the signal to consume
  /// the event.
  bool handle(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    // A bare modifier press neither completes nor breaks a sequence.
    if (kbarIsModifierKey(event.logicalKey)) return false;

    bool advanced = false;
    for (final _Binding binding in _bindings) {
      final List<KBarKeyPress> presses = binding.shortcut.presses;
      if (_index >= presses.length) continue;
      if (!presses[_index].matches(event)) continue;

      if (_index == presses.length - 1) {
        reset();
        binding.onFire();
        return true;
      }
      advanced = true;
    }

    // tinykeys resets outright on a mismatch rather than retrying the event as
    // the start of a new sequence.
    _index = advanced ? _index + 1 : 0;
    _timer?.cancel();
    _timer = _index > 0 ? Timer(timeout, reset) : null;
    return false;
  }

  /// Cancels any pending sequence timer.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _bindings.clear();
  }
}

class _Binding {
  const _Binding(this.shortcut, this.onFire);

  final KBarShortcut shortcut;
  final VoidCallback onFire;
}
