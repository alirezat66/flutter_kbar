import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../match/fuse/kbar_fuse_matcher.dart';
import '../match/kbar_match_engine.dart';
import '../match/kbar_matcher.dart';
import '../model/kbar_action.dart';
import '../model/kbar_action_registry.dart';
import '../model/kbar_options.dart';
import '../model/kbar_result_item.dart';
import '../model/kbar_state.dart';
import '../model/kbar_visual_state.dart';
import 'kbar_history.dart';
import 'kbar_scope.dart';

/// Removes actions that were added by `KBarController.registerActions`.
///
/// Calling it more than once is harmless.
typedef KBarUnregister = void Function();

/// Owns all palette state and every operation that changes it.
///
/// This merges kbar's `KBarState` and `KBarQuery` into one object. It is a
/// [ChangeNotifier], but prefer `KBarSelector` over listening directly:
/// listeners fire on *every* change, whereas a selector only rebuilds when its
/// own slice differs.
///
/// A controller is normally created for you by `KBarProvider`. Create one
/// yourself only when you need to drive the palette from outside the widget
/// tree, and pass it to `KBarProvider.controller`.
class KBarController extends ChangeNotifier {
  /// Creates a controller seeded with [actions].
  KBarController({
    List<KBarAction> actions = const <KBarAction>[],
    KBarOptions options = const KBarOptions(),
  }) : _options = options,
       _state = KBarState(actions: KBarActionRegistry.of(actions)) {
    _searchController.addListener(_handleSearchInput);
    _engine = KBarMatchEngine(
      matcher: options.matcher ?? const KBarFuseMatcher(),
      throttle: options.searchThrottle,
    )..results.addListener(_handleMatchesChanged);
    _engine.update(_state);
  }

  /// Finds the nearest controller, throwing a descriptive error if there is
  /// none.
  static KBarController of(BuildContext context) {
    final KBarController? controller = maybeOf(context);
    assert(() {
      if (controller == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('No KBarProvider found above this widget.'),
          ErrorDescription(
            'KBarController.of() was called with a context that does not have '
            'a KBarProvider ancestor.',
          ),
          ErrorHint(
            'Wrap your app — typically above MaterialApp — in a KBarProvider.',
          ),
          context.describeElement('The context used was'),
        ]);
      }
      return true;
    }());
    return controller!;
  }

  /// Finds the nearest controller, or returns null if there is none.
  static KBarController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KBarScope>()?.controller;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'kbar.search');
  late final KBarMatchEngine _engine;
  final KBarHistory _history = KBarHistory();

  String? _lastMatchedQuery;
  String? _lastMatchedRoot;

  KBarState _state;
  KBarOptions _options;
  Timer? _transitionTimer;
  bool _applyingSearchFromStore = false;
  bool _notifyScheduled = false;
  bool _disposed = false;

  /// The current immutable state snapshot.
  KBarState get state => _state;

  /// The active configuration.
  KBarOptions get options => _options;

  /// Replaces the configuration.
  ///
  /// Unlike kbar, which freezes its options on first render, this takes effect
  /// immediately.
  set options(KBarOptions value) {
    if (_options == value) return;
    _options = value;
    _engine
      ..matcher = value.matcher ?? const KBarFuseMatcher()
      ..throttle = value.searchThrottle;
    notifyListeners();
  }

  /// The current results: section headings and action rows, ready to render.
  ///
  /// Computed once per change and shared by every consumer, so listening from
  /// several places costs nothing extra. Prefer `KBarMatchesBuilder` in widgets.
  ValueListenable<KBarMatches> get matches => _engine.results;

  /// The matcher currently scoring results.
  KBarMatcher get matcher => _engine.matcher;

  /// Undo and redo stacks.
  ///
  /// Populated only when `KBarOptions.enableHistory` is set and an action calls
  /// [KBarActionContext.undoWith].
  KBarHistory get history => _history;

  /// The text controller backing the search field.
  ///
  /// Owned by the controller — not the search widget — so that [setSearch]
  /// actually updates what the user sees. kbar keeps this state local to its
  /// input, which is why programmatic `setSearch` silently fails there.
  TextEditingController get searchController => _searchController;

  /// The focus node attached to the search field.
  FocusNode get searchFocusNode => _searchFocusNode;

  /// Whether the palette is open or opening.
  bool get isOpen => _state.visualState.isOpening;

  /// The action whose children are currently being browsed, if any.
  KBarActionNode? get currentRootAction => _state.currentRootAction;

  /// Reads a slice of state without subscribing to changes.
  T select<T>(T Function(KBarState state) selector) => selector(_state);

  // ---------------------------------------------------------------------------
  // Visibility
  // ---------------------------------------------------------------------------

  /// Opens the palette if closed, closes it if open.
  ///
  /// Following kbar, a programmatic toggle fires neither `onOpen` nor
  /// `onClose`; those are reserved for user-driven opens and closes.
  void toggle() => isOpen ? close() : open();

  /// Opens the palette. No-op while [KBarState.disabled].
  void open() {
    if (_state.disabled || isOpen) return;
    setVisualState(KBarVisualState.animatingIn);
  }

  /// Closes the palette.
  void close() {
    if (_state.visualState.isClosing) return;
    setVisualState(KBarVisualState.animatingOut);
  }

  /// Moves the palette to [visualState] and schedules the follow-on transition.
  ///
  /// The controller — not the animator — owns the timing, so state stays
  /// correct even when no animator is mounted.
  void setVisualState(KBarVisualState visualState) {
    if (_state.visualState == visualState) return;
    _transitionTimer?.cancel();
    _transitionTimer = null;

    KBarState next = _state.copyWith(visualState: visualState);
    if (visualState == KBarVisualState.hidden && _options.resetOnClose) {
      next = next.copyWith(searchQuery: '', clearRoot: true, activeIndex: 0);
    }
    _setState(next);

    if (visualState == KBarVisualState.hidden && _options.resetOnClose) {
      _writeSearchText('');
    }

    switch (visualState) {
      case KBarVisualState.animatingIn:
        _scheduleTransition(_options.animations.enter, KBarVisualState.showing);
      case KBarVisualState.animatingOut:
        _scheduleTransition(_options.animations.exit, KBarVisualState.hidden);
      case KBarVisualState.showing:
      case KBarVisualState.hidden:
        break;
    }
  }

  /// Advances to [next] after [duration].
  ///
  /// A zero duration transitions synchronously rather than through a
  /// zero-delay timer. That keeps `KBarAnimations.none` genuinely instant, and
  /// means widget tests never trip over a pending timer they would otherwise
  /// have to pump away.
  void _scheduleTransition(Duration duration, KBarVisualState next) {
    if (duration <= Duration.zero) {
      setVisualState(next);
      return;
    }
    _transitionTimer = Timer(duration, () => setVisualState(next));
  }

  /// Moves the palette to the state produced by [update].
  void updateVisualState(KBarVisualState Function(KBarVisualState) update) =>
      setVisualState(update(_state.visualState));

  /// Disables or re-enables the palette.
  ///
  /// While disabled the palette cannot be opened and no shortcut fires.
  /// Disabling an open palette closes it immediately.
  void disable(bool disabled) {
    if (_state.disabled == disabled) return;
    _setState(_state.copyWith(disabled: disabled));
    if (disabled && _state.visualState.isVisible) {
      _transitionTimer?.cancel();
      setVisualState(KBarVisualState.hidden);
    }
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Sets the search query programmatically.
  ///
  /// Updates the visible field as well, and deliberately does *not* fire
  /// `KBarCallbacks.onQueryChange` — that hook reports user typing only.
  void setSearch(String search) {
    if (_state.searchQuery == search) return;
    _writeSearchText(search);
    _setState(_state.copyWith(searchQuery: search));
  }

  /// Moves focus to the search field.
  void focusSearchField() {
    if (!_searchFocusNode.hasFocus && _searchFocusNode.canRequestFocus) {
      _searchFocusNode.requestFocus();
    }
  }

  void _writeSearchText(String text) {
    if (_searchController.text == text) return;
    _applyingSearchFromStore = true;
    _searchController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _applyingSearchFromStore = false;
  }

  void _handleSearchInput() {
    if (_applyingSearchFromStore) return;
    final String text = _searchController.text;
    if (text == _state.searchQuery) return;
    _setState(_state.copyWith(searchQuery: text));
    _options.callbacks.onQueryChange?.call(text);
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  /// Scopes the palette to the children of [actionId], or back to the top level
  /// when null.
  ///
  /// Clears the search query, matching kbar.
  void setCurrentRootAction(String? actionId) {
    if (_state.currentRootActionId == actionId && _state.searchQuery.isEmpty) {
      return;
    }
    _writeSearchText('');
    _setState(
      _state.copyWith(
        searchQuery: '',
        currentRootActionId: actionId,
        clearRoot: actionId == null,
        activeIndex: 0,
      ),
    );
  }

  /// Leaves the current nested action for its parent, or the top level.
  ///
  /// This is what Backspace does when the query is empty.
  void goToParent() {
    final KBarActionNode? root = _state.currentRootAction;
    if (root == null) return;
    setCurrentRootAction(root.parentId);
  }

  /// Highlights the row at [index].
  void setActiveIndex(int index) {
    if (_state.activeIndex == index) return;
    _setState(_state.copyWith(activeIndex: index));
  }

  /// Moves the highlight by [delta] rows, skipping section headings.
  ///
  /// Clamps at both ends rather than wrapping, matching kbar.
  void moveActiveIndex(int delta) {
    if (delta == 0) return;
    final List<KBarResultItem> items = matches.value.items;
    if (items.isEmpty) return;

    final int step = delta.sign;
    int index = (_state.activeIndex + delta).clamp(0, items.length - 1);

    // Walk past headings in the direction of travel.
    while (index >= 0 && index < items.length && !items[index].isSelectable) {
      index += step;
    }
    if (index < 0 || index >= items.length) {
      // Ran off the end landing on headings only — fall back to the nearest
      // selectable row in the opposite direction.
      index = (_state.activeIndex + delta).clamp(0, items.length - 1);
      while (index >= 0 && index < items.length && !items[index].isSelectable) {
        index -= step;
      }
    }
    if (index < 0 || index >= items.length) return;
    setActiveIndex(index);
  }

  /// The action currently highlighted, or null when the list is empty or the
  /// highlight sits on a heading.
  KBarActionNode? get activeAction =>
      matches.value.actionAt(_state.activeIndex);

  /// Performs the highlighted action, if there is one.
  ///
  /// This is what Enter does.
  Future<void> performActiveAction() async {
    final KBarActionNode? action = activeAction;
    if (action != null) await performAction(action);
  }

  /// Keeps [KBarState.activeIndex] pointing at a selectable row as results
  /// change.
  ///
  /// Resets to the top when the query or nested action changes; otherwise
  /// clamps and steps off any heading it landed on.
  void _handleMatchesChanged() {
    final KBarMatches current = matches.value;
    final String? rootId = current.rootAction?.id;
    final bool contextChanged =
        current.query != _lastMatchedQuery || rootId != _lastMatchedRoot;
    _lastMatchedQuery = current.query;
    _lastMatchedRoot = rootId;

    if (current.items.isEmpty) {
      setActiveIndex(0);
      return;
    }

    if (contextChanged) {
      setActiveIndex(current.firstSelectableIndex ?? 0);
      return;
    }

    int index = _state.activeIndex;
    if (index >= current.items.length) {
      setActiveIndex(current.lastSelectableIndex ?? 0);
      return;
    }
    if (!current.items[index].isSelectable) {
      while (index < current.items.length &&
          !current.items[index].isSelectable) {
        index++;
      }
      if (index >= current.items.length) {
        index = current.lastSelectableIndex ?? 0;
      }
      setActiveIndex(index);
    }
  }

  /// Runs [action], or descends into it when it has no
  /// [KBarAction.perform].
  ///
  /// This is the single code path behind Enter, a tap, and a shortcut, so all
  /// three behave identically.
  Future<void> performAction(KBarActionNode action) async {
    _options.callbacks.onSelectAction?.call(action);

    final KBarPerform? perform = action.perform;
    if (perform == null) {
      setCurrentRootAction(action.id);
      return;
    }

    close();

    final String actionId = action.id;
    await perform(
      KBarActionContext(
        action: action,
        recordUndo: (KBarUndo undo) {
          if (!_options.enableHistory) return;
          _history.record(
            KBarHistoryEntry(
              actionId: actionId,
              undo: undo,
              // Redoing re-performs the action, which records a fresh undo
              // entry and so makes the step undoable again.
              redo: () async {
                final KBarActionNode? current = _state.actions[actionId];
                if (current != null) await performAction(current);
              },
            ),
          );
        },
      ),
    );
  }

  /// Undoes the most recent undoable action.
  Future<void> undo() => _history.undo();

  /// Redoes the most recently undone action.
  Future<void> redo() => _history.redo();

  // ---------------------------------------------------------------------------
  // Action registration
  // ---------------------------------------------------------------------------

  /// Registers [actions] and returns a function that removes them again.
  ///
  /// Actions may reference a parent that appears later in the same list; the
  /// batch is ordered before it is applied. Removing an action also removes its
  /// descendants.
  KBarUnregister registerActions(List<KBarAction> actions) {
    if (actions.isEmpty) return () {};
    final List<String> ids = <String>[
      for (final KBarAction action in actions) action.id,
    ];
    _setState(_state.copyWith(actions: _state.actions.addAll(actions)));

    bool removed = false;
    return () {
      if (removed || _disposed) return;
      removed = true;
      _setState(_state.copyWith(actions: _state.actions.removeAll(ids)));
    };
  }

  void _setState(KBarState next) {
    if (_state == next) return;
    _state = next;
    _engine.update(next);
    _notify();
  }

  /// Notifies listeners, deferring to the end of the frame if we are currently
  /// inside one.
  ///
  /// Registering actions from `initState`/`didUpdateWidget` is the normal way to
  /// use this package, and those run during the build phase. Notifying
  /// synchronously there would make every listening `KBarSelector` call
  /// `setState` during build, which Flutter rejects.
  void _notify() {
    if (_disposed) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notifyScheduled) return;
      _notifyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        notifyListeners();
      });
      return;
    }
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _transitionTimer?.cancel();
    _engine.results.removeListener(_handleMatchesChanged);
    _engine.dispose();
    _history.dispose();
    _searchController
      ..removeListener(_handleSearchInput)
      ..dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}

/// Convenience access to the nearest [KBarController].
extension KBarBuildContext on BuildContext {
  /// The nearest [KBarController].
  ///
  /// Reading this does not subscribe the widget to state changes — use
  /// `KBarSelector` for that.
  KBarController get kbar => KBarController.of(this);
}
