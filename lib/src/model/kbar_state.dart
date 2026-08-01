import 'package:flutter/foundation.dart';

import 'kbar_action_registry.dart';
import 'kbar_visual_state.dart';

/// An immutable snapshot of everything the palette knows about itself.
///
/// This is what `KBarSelector` slices; because it is a value type, selecting a
/// field and comparing with `==` is enough to decide whether to rebuild.
@immutable
class KBarState {
  /// Creates a state snapshot. Defaults describe a closed, empty palette.
  const KBarState({
    this.searchQuery = '',
    this.visualState = KBarVisualState.hidden,
    this.actions = KBarActionRegistry.empty,
    this.currentRootActionId,
    this.activeIndex = 0,
    this.disabled = false,
  });

  /// The current search text.
  final String searchQuery;

  /// Where the palette is in its show/hide lifecycle.
  final KBarVisualState visualState;

  /// Every registered action.
  final KBarActionRegistry actions;

  /// The action whose children are currently being browsed, or null at the top
  /// level.
  ///
  /// kbar keeps no explicit navigation stack; "go back" simply walks to this
  /// action's parent.
  final String? currentRootActionId;

  /// Index of the highlighted row in the flattened result list.
  final int activeIndex;

  /// When true the palette cannot be opened and no shortcuts fire.
  final bool disabled;

  /// The node named by [currentRootActionId], if it is still registered.
  KBarActionNode? get currentRootAction => actions[currentRootActionId];

  /// Whether the palette subtree is mounted. See [KBarVisualState.isVisible].
  bool get isVisible => visualState.isVisible;

  /// Whether the palette is open or opening. See [KBarVisualState.isOpening].
  bool get isOpen => visualState.isOpening;

  /// Returns a copy with the given fields replaced.
  ///
  /// Pass `clearRoot: true` to set [currentRootActionId] back to null, since
  /// passing null for the field itself means "leave unchanged".
  KBarState copyWith({
    String? searchQuery,
    KBarVisualState? visualState,
    KBarActionRegistry? actions,
    String? currentRootActionId,
    bool clearRoot = false,
    int? activeIndex,
    bool? disabled,
  }) {
    return KBarState(
      searchQuery: searchQuery ?? this.searchQuery,
      visualState: visualState ?? this.visualState,
      actions: actions ?? this.actions,
      currentRootActionId: clearRoot
          ? null
          : (currentRootActionId ?? this.currentRootActionId),
      activeIndex: activeIndex ?? this.activeIndex,
      disabled: disabled ?? this.disabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KBarState &&
          other.searchQuery == searchQuery &&
          other.visualState == visualState &&
          other.actions == actions &&
          other.currentRootActionId == currentRootActionId &&
          other.activeIndex == activeIndex &&
          other.disabled == disabled;

  @override
  int get hashCode => Object.hash(
    searchQuery,
    visualState,
    actions,
    currentRootActionId,
    activeIndex,
    disabled,
  );

  @override
  String toString() =>
      'KBarState(${visualState.name}, query: "$searchQuery", '
      'root: $currentRootActionId, activeIndex: $activeIndex, '
      'actions: ${actions.length}${disabled ? ', disabled' : ''})';
}
