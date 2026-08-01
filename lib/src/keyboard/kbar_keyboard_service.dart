import 'dart:async';

import 'package:flutter/services.dart';

import '../model/kbar_action_registry.dart';
import '../model/kbar_state.dart';
import '../store/kbar_controller.dart';
import '../store/kbar_history.dart';
import '../util/kbar_platform.dart';
import 'kbar_focus_probe.dart';
import 'kbar_shortcut.dart';
import 'kbar_shortcut_binder.dart';

/// Routes global key events to the palette.
///
/// Installs a single [HardwareKeyboard] handler, which is the closest Flutter
/// equivalent to the `window` keydown listener kbar uses: it runs **before**
/// focus-tree dispatch, so `⌘K` works even while a text field has focus.
///
/// That ordering is also the subsystem's main hazard. Because the handler sees
/// every key first, returning true indiscriminately while the palette is open
/// would starve the search field of every character the user types. The
/// handler is therefore strictly allow-listed: it consumes only the keys it
/// genuinely owns and returns false for everything else, which still lets it
/// observe events — that is how "any keystroke refocuses the search field"
/// works — while letting them reach the field. On the web, returning true also
/// causes the engine to call `preventDefault`, which is wanted for `⌘K` and
/// Escape and must not happen for ordinary characters.
class KBarKeyboardService {
  /// Creates a service driving [controller].
  KBarKeyboardService(this._controller);

  final KBarController _controller;

  late final KBarShortcutBinder _toggleBinder = KBarShortcutBinder(
    timeout: _controller.options.toggleSequenceTimeout,
  );
  late final KBarShortcutBinder _actionBinder = KBarShortcutBinder(
    timeout: _controller.options.actionSequenceTimeout,
  );

  bool _attached = false;
  KBarActionRegistry? _boundRegistry;
  List<String>? _boundToggleShortcuts;

  /// Starts listening for key events.
  void attach() {
    if (_attached) return;
    _attached = true;
    _syncToggleBindings();
    _syncActionBindings();
    _controller.addListener(_handleControllerChanged);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  /// Stops listening and releases timers.
  ///
  /// Must run before the controller is disposed, or the handler outlives it.
  void detach() {
    if (!_attached) return;
    _attached = false;
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _controller.removeListener(_handleControllerChanged);
    _toggleBinder.dispose();
    _actionBinder.dispose();
  }

  void _handleControllerChanged() {
    _toggleBinder.timeout = _controller.options.toggleSequenceTimeout;
    _actionBinder.timeout = _controller.options.actionSequenceTimeout;
    _syncToggleBindings();
    _syncActionBindings();
  }

  void _syncToggleBindings() {
    final List<String> shortcuts = _controller.options.toggleShortcuts;
    if (_boundToggleShortcuts != null &&
        _boundToggleShortcuts!.length == shortcuts.length &&
        _boundToggleShortcuts!.every(shortcuts.contains)) {
      return;
    }
    _boundToggleShortcuts = List<String>.of(shortcuts);

    _toggleBinder.clear();
    for (final KBarShortcut shortcut in KBarShortcut.parseAll(shortcuts)) {
      _toggleBinder.bind(shortcut, _handleToggle);
    }
  }

  void _syncActionBindings() {
    final KBarActionRegistry registry = _controller.state.actions;
    if (identical(registry, _boundRegistry)) return;
    _boundRegistry = registry;

    _actionBinder.clear();
    for (final KBarActionNode node in registry.all) {
      if (node.shortcut.isEmpty) continue;
      // An action's shortcut list is ONE sequence, not a list of alternatives:
      // ['t', 's'] means "press t, then s". kbar joins the entries with spaces
      // into a single tinykeys string, and so must this. (Contrast
      // KBarOptions.toggleShortcuts, which genuinely is a list of alternative
      // bindings and is parsed entry by entry.)
      final String source = node.shortcut.join(' ');
      try {
        _actionBinder.bind(
          KBarShortcut.parse(source),
          () => _handleActionShortcut(node.id),
        );
      } on FormatException catch (error) {
        assert(
          false,
          'Invalid shortcut "$source" on action "${node.id}": ${error.message}',
        );
      }
    }
  }

  void _handleToggle() {
    final bool wasOpen = _controller.isOpen;
    _controller.toggle();
    // Unlike a programmatic toggle, a user-driven one reports itself.
    if (wasOpen) {
      _controller.options.callbacks.onClose?.call();
    } else {
      _controller.options.callbacks.onOpen?.call();
    }
  }

  void _handleActionShortcut(String actionId) {
    final KBarActionNode? action = _controller.state.actions[actionId];
    if (action == null) return;

    if (action.perform == null && action.children.isNotEmpty) {
      // A shortcut on a parent opens the palette scoped to it, rather than
      // performing anything.
      _controller
        ..setCurrentRootAction(action.id)
        ..open();
      _controller.options.callbacks.onOpen?.call();
      return;
    }
    unawaited(_controller.performAction(action));
  }

  bool _handleKeyEvent(KeyEvent event) {
    final KBarState state = _controller.state;
    if (state.disabled) return false;

    // The toggle fires from anywhere, including inside a text field.
    if (_toggleBinder.handle(event)) return true;

    if (_handleHistoryKeys(event)) return true;

    if (state.visualState.isVisible) return _handleKeysWhileOpen(event, state);

    if (_shouldIgnoreShortcuts()) return false;
    return _actionBinder.handle(event);
  }

  /// Handles the undo and redo bindings.
  ///
  /// kbar binds these to Meta+Z and Meta+Shift+Z on every platform, which
  /// leaves Windows and Linux users without an undo. `$mod` is used here
  /// instead, so it is Control+Z off Apple platforms.
  bool _handleHistoryKeys(KeyEvent event) {
    if (!_controller.options.enableHistory) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyZ) return false;

    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final bool modHeld = kbarIsApplePlatform
        ? keyboard.isMetaPressed
        : keyboard.isControlPressed;
    if (!modHeld) return false;

    // Undoing while typing in some other text field would be surprising.
    if (!_controller.state.visualState.isVisible && _shouldIgnoreShortcuts()) {
      return false;
    }

    final KBarHistory history = _controller.history;
    if (keyboard.isShiftPressed) {
      if (!history.canRedo) return false;
      unawaited(_controller.redo());
    } else {
      if (!history.canUndo) return false;
      unawaited(_controller.undo());
    }
    return true;
  }

  bool _shouldIgnoreShortcuts() =>
      (_controller.options.shouldIgnoreShortcuts ?? kbarIsTextFieldFocused)();

  bool _handleKeysWhileOpen(KeyEvent event, KBarState state) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    final LogicalKeyboardKey key = event.logicalKey;
    final bool isControlHeld = HardwareKeyboard.instance.isControlPressed;

    if (key == LogicalKeyboardKey.escape) {
      if (!_controller.options.closeOnEscape) return false;
      _controller.close();
      _controller.options.callbacks.onClose?.call();
      return true;
    }

    if (key == LogicalKeyboardKey.arrowDown ||
        (isControlHeld && key == LogicalKeyboardKey.keyN)) {
      _controller.moveActiveIndex(1);
      return true;
    }

    if (key == LogicalKeyboardKey.arrowUp ||
        (isControlHeld && key == LogicalKeyboardKey.keyP)) {
      _controller.moveActiveIndex(-1);
      return true;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      unawaited(_controller.performActiveAction());
      return true;
    }

    // Backspace only navigates out of a nested action, and only when there is
    // no text for it to delete.
    if (key == LogicalKeyboardKey.backspace &&
        state.searchQuery.isEmpty &&
        state.currentRootActionId != null) {
      _controller.goToParent();
      return true;
    }

    // Everything else belongs to the search field. Observe it so a stray
    // keystroke pulls focus back, then let it through untouched.
    if (event is KeyDownEvent && key != LogicalKeyboardKey.tab) {
      _controller.focusSearchField();
    }
    return false;
  }
}
