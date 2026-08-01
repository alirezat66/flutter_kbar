import 'package:flutter/foundation.dart';

import '../match/kbar_matcher.dart';
import 'kbar_action_registry.dart';

/// Durations for the palette's enter and exit animations.
@immutable
class KBarAnimations {
  /// Creates an animation configuration. Defaults match kbar.
  const KBarAnimations({
    this.enter = const Duration(milliseconds: 200),
    this.exit = const Duration(milliseconds: 100),
  });

  /// Disables animation entirely. Useful for golden tests.
  static const KBarAnimations none = KBarAnimations(
    enter: Duration.zero,
    exit: Duration.zero,
  );

  /// How long the entrance animation runs.
  ///
  /// The results-height animation runs at half this duration.
  final Duration enter;

  /// How long the exit animation runs.
  final Duration exit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KBarAnimations && other.enter == enter && other.exit == exit;

  @override
  int get hashCode => Object.hash(enter, exit);
}

/// Hooks fired as the user drives the palette.
@immutable
class KBarCallbacks {
  /// Creates a callback set.
  const KBarCallbacks({
    this.onOpen,
    this.onClose,
    this.onQueryChange,
    this.onSelectAction,
  });

  /// Fired when the user opens the palette with a shortcut.
  ///
  /// Following kbar, this does *not* fire for a programmatic
  /// `KBarController.open()` or `toggle()`.
  final VoidCallback? onOpen;

  /// Fired when the user closes the palette by shortcut, Escape, or an outside
  /// tap. Not fired for a programmatic close.
  final VoidCallback? onClose;

  /// Fired when the user types in the search field.
  ///
  /// Deliberately not fired by `KBarController.setSearch`, matching kbar.
  final ValueChanged<String>? onQueryChange;

  /// Fired when an action is chosen, whether by Enter, tap, or shortcut.
  final void Function(KBarActionNode action)? onSelectAction;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KBarCallbacks &&
          other.onOpen == onOpen &&
          other.onClose == onClose &&
          other.onQueryChange == onQueryChange &&
          other.onSelectAction == onSelectAction;

  @override
  int get hashCode =>
      Object.hash(onOpen, onClose, onQueryChange, onSelectAction);
}

/// Configuration for a `KBarProvider`.
///
/// Unlike kbar — which captures its options in a ref on first render and never
/// looks at them again — these are live: changing them on the provider takes
/// effect immediately.
@immutable
class KBarOptions {
  /// Creates an options set. Every default matches kbar's behaviour.
  const KBarOptions({
    this.animations = const KBarAnimations(),
    this.callbacks = const KBarCallbacks(),
    this.enableHistory = false,
    this.toggleShortcuts = const <String>[r'$mod+k'],
    this.searchThrottle = const Duration(milliseconds: 100),
    this.toggleSequenceTimeout = const Duration(milliseconds: 1000),
    this.actionSequenceTimeout = const Duration(milliseconds: 400),
    this.closeOnOutsideTap = true,
    this.closeOnEscape = true,
    this.restoreFocusOnClose = true,
    this.resetOnClose = true,
    this.shouldIgnoreShortcuts,
    this.matcher,
  });

  /// Enter and exit animation durations.
  final KBarAnimations animations;

  /// Lifecycle hooks.
  final KBarCallbacks callbacks;

  /// Whether performing an action records an undo entry.
  final bool enableHistory;

  /// Bindings that open and close the palette.
  ///
  /// `$mod` resolves to Command on Apple platforms and Control everywhere else.
  ///
  /// This is a list, where kbar allows only one, because Firefox binds
  /// `Ctrl/Cmd+K` to its own search bar and has historically ignored
  /// `preventDefault` for it. Web apps should register a fallback:
  ///
  /// ```dart
  /// const KBarOptions(toggleShortcuts: [r'$mod+k', r'$mod+shift+p'])
  /// ```
  final List<String> toggleShortcuts;

  /// How long typing is coalesced before the query is re-run.
  final Duration searchThrottle;

  /// How long a partially-typed [toggleShortcuts] sequence stays armed.
  final Duration toggleSequenceTimeout;

  /// How long a partially-typed action shortcut sequence stays armed.
  ///
  /// Shorter than [toggleSequenceTimeout], matching kbar, because action
  /// sequences like `g` `h` are typed quickly and should not swallow ordinary
  /// keystrokes for a full second.
  final Duration actionSequenceTimeout;

  /// Whether tapping outside the palette closes it.
  final bool closeOnOutsideTap;

  /// Whether Escape closes the palette.
  final bool closeOnEscape;

  /// Whether the palette explicitly returns focus to whatever held it before
  /// opening.
  ///
  /// Setting this false does not guarantee focus goes nowhere: Flutter hands
  /// focus back to the enclosing scope's most recent node when a child scope is
  /// removed, so the previously focused widget often regains it regardless.
  ///
  /// Focus is never restored if something else claimed it while the palette was
  /// closing — an action that opens a dialog, for instance — so the dialog keeps
  /// the focus it asked for.
  final bool restoreFocusOnClose;

  /// Whether closing clears the search query and returns to the top level.
  ///
  /// kbar always does this; set false to have the palette reopen where the user
  /// left off.
  final bool resetOnClose;

  /// Suppresses action shortcuts while this returns true.
  ///
  /// Defaults to "a text field currently has focus", so typing `g` in a form
  /// does not fire the `g` shortcut. Override for custom editors that Flutter
  /// cannot recognise as text fields.
  final bool Function()? shouldIgnoreShortcuts;

  /// How results are scored and ordered.
  ///
  /// Defaults to `KBarFuseMatcher()`, which reproduces kbar's ranking.
  final KBarMatcher? matcher;

  /// Returns a copy with the given fields replaced.
  KBarOptions copyWith({
    KBarAnimations? animations,
    KBarCallbacks? callbacks,
    bool? enableHistory,
    List<String>? toggleShortcuts,
    Duration? searchThrottle,
    Duration? toggleSequenceTimeout,
    Duration? actionSequenceTimeout,
    bool? closeOnOutsideTap,
    bool? closeOnEscape,
    bool? restoreFocusOnClose,
    bool? resetOnClose,
    bool Function()? shouldIgnoreShortcuts,
    KBarMatcher? matcher,
  }) {
    return KBarOptions(
      animations: animations ?? this.animations,
      callbacks: callbacks ?? this.callbacks,
      enableHistory: enableHistory ?? this.enableHistory,
      toggleShortcuts: toggleShortcuts ?? this.toggleShortcuts,
      searchThrottle: searchThrottle ?? this.searchThrottle,
      toggleSequenceTimeout:
          toggleSequenceTimeout ?? this.toggleSequenceTimeout,
      actionSequenceTimeout:
          actionSequenceTimeout ?? this.actionSequenceTimeout,
      closeOnOutsideTap: closeOnOutsideTap ?? this.closeOnOutsideTap,
      closeOnEscape: closeOnEscape ?? this.closeOnEscape,
      restoreFocusOnClose: restoreFocusOnClose ?? this.restoreFocusOnClose,
      resetOnClose: resetOnClose ?? this.resetOnClose,
      shouldIgnoreShortcuts:
          shouldIgnoreShortcuts ?? this.shouldIgnoreShortcuts,
      matcher: matcher ?? this.matcher,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KBarOptions &&
          other.animations == animations &&
          other.callbacks == callbacks &&
          other.enableHistory == enableHistory &&
          listEquals(other.toggleShortcuts, toggleShortcuts) &&
          other.searchThrottle == searchThrottle &&
          other.toggleSequenceTimeout == toggleSequenceTimeout &&
          other.actionSequenceTimeout == actionSequenceTimeout &&
          other.closeOnOutsideTap == closeOnOutsideTap &&
          other.closeOnEscape == closeOnEscape &&
          other.restoreFocusOnClose == restoreFocusOnClose &&
          other.resetOnClose == resetOnClose &&
          other.shouldIgnoreShortcuts == shouldIgnoreShortcuts &&
          other.matcher == matcher;

  @override
  int get hashCode => Object.hash(
    animations,
    callbacks,
    enableHistory,
    Object.hashAll(toggleShortcuts),
    searchThrottle,
    toggleSequenceTimeout,
    actionSequenceTimeout,
    closeOnOutsideTap,
    closeOnEscape,
    restoreFocusOnClose,
    resetOnClose,
    shouldIgnoreShortcuts,
    matcher,
  );
}
