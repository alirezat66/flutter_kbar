library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'kbar_action.dart';
import 'kbar_section.dart';

part 'kbar_action_node.dart';

/// Thrown when an action is registered before the parent it points at.
///
/// kbar has the same constraint: a child cannot be created until its parent
/// exists in the store. Note that [KBarActionRegistry.addAll] relaxes this for
/// actions registered together in one batch — see its documentation.
class KBarUnknownParentError extends ArgumentError {
  /// Creates an error describing an action whose parent is missing.
  KBarUnknownParentError({required this.actionId, required this.parentId})
    : super.value(
        parentId,
        'parent',
        'Cannot register action "$actionId": its parent "$parentId" is not '
            'registered. Register the parent action first.',
      );

  /// The id of the action that could not be registered.
  final String actionId;

  /// The id of the parent that was not found.
  final String parentId;
}

/// An immutable snapshot of the registered action tree.
///
/// Every mutating method returns a new registry rather than modifying this one,
/// which is what lets the store hand out stable snapshots and lets selectors
/// detect change by comparison.
@immutable
class KBarActionRegistry {
  const KBarActionRegistry._(this._definitions, this._nodes, this.revision);

  /// Builds a registry from a flat list of actions.
  ///
  /// Equivalent to `KBarActionRegistry.empty.addAll(actions)`.
  factory KBarActionRegistry.of(Iterable<KBarAction> actions) =>
      empty.addAll(actions);

  /// A registry with no actions.
  static const KBarActionRegistry empty = KBarActionRegistry._(
    <String, KBarAction>{},
    <String, KBarActionNode>{},
    0,
  );

  final Map<String, KBarAction> _definitions;
  final Map<String, KBarActionNode> _nodes;

  /// Incremented on every mutation. Useful as a cheap cache key.
  final int revision;

  /// The node registered under [id], or null.
  KBarActionNode? operator [](String? id) => id == null ? null : _nodes[id];

  /// Whether an action with [id] is registered.
  bool contains(String id) => _nodes.containsKey(id);

  /// How many actions are registered, at every level of the tree.
  int get length => _nodes.length;

  /// Whether no actions are registered.
  bool get isEmpty => _nodes.isEmpty;

  /// Whether at least one action is registered.
  bool get isNotEmpty => _nodes.isNotEmpty;

  /// Every registered node, in registration order.
  Iterable<KBarActionNode> get all => _nodes.values;

  /// The top-level nodes — those with no parent — in registration order.
  List<KBarActionNode> get roots => <KBarActionNode>[
    for (final KBarActionNode node in _nodes.values)
      if (node.parentId == null) node,
  ];

  /// The direct children of [parentId], or [roots] when it is null.
  List<KBarActionNode> childrenOf(String? parentId) =>
      parentId == null ? roots : (this[parentId]?.children ?? const []);

  /// Registers a single action, replacing any existing action with the same id.
  ///
  /// Throws [KBarUnknownParentError] if [action] names a parent that is not
  /// already registered.
  KBarActionRegistry add(KBarAction action) {
    final String? parentId = action.parent;
    if (parentId != null && !_definitions.containsKey(parentId)) {
      throw KBarUnknownParentError(actionId: action.id, parentId: parentId);
    }
    return KBarActionRegistry._build(
      Map<String, KBarAction>.of(_definitions)..[action.id] = action,
      revision + 1,
    );
  }

  /// Registers several actions at once.
  ///
  /// Unlike [add], the batch is topologically ordered first, so a child may
  /// appear before its parent within [actions] as long as the parent is either
  /// already registered or present in the same batch. Anything kbar accepts is
  /// accepted here; some orderings kbar rejects are accepted.
  ///
  /// Throws [KBarUnknownParentError] if an action's parent is neither already
  /// registered nor part of this batch.
  KBarActionRegistry addAll(Iterable<KBarAction> actions) {
    final List<KBarAction> pending = actions.toList();
    if (pending.isEmpty) return this;

    final Map<String, KBarAction> definitions = Map<String, KBarAction>.of(
      _definitions,
    );
    bool progressed = true;
    while (pending.isNotEmpty && progressed) {
      progressed = false;
      pending.removeWhere((KBarAction action) {
        final String? parentId = action.parent;
        if (parentId == null || definitions.containsKey(parentId)) {
          definitions[action.id] = action;
          progressed = true;
          return true;
        }
        return false;
      });
    }
    if (pending.isNotEmpty) {
      final KBarAction unresolved = pending.first;
      throw KBarUnknownParentError(
        actionId: unresolved.id,
        parentId: unresolved.parent!,
      );
    }
    return KBarActionRegistry._build(definitions, revision + 1);
  }

  /// Unregisters [id] and every one of its descendants.
  KBarActionRegistry remove(String id) => removeAll(<String>[id]);

  /// Unregisters each of [ids] and every one of their descendants.
  KBarActionRegistry removeAll(Iterable<String> ids) {
    final Set<String> doomed = <String>{};
    final List<String> queue = ids.toList();
    while (queue.isNotEmpty) {
      final String id = queue.removeLast();
      if (!_definitions.containsKey(id) || !doomed.add(id)) continue;
      final KBarActionNode? node = _nodes[id];
      if (node != null) queue.addAll(node._childIds);
    }
    if (doomed.isEmpty) return this;
    return KBarActionRegistry._build(
      Map<String, KBarAction>.of(_definitions)
        ..removeWhere((String id, _) => doomed.contains(id)),
      revision + 1,
    );
  }

  /// Rebuilds the whole node graph from [definitions].
  ///
  /// Nodes are cheap and the action count is small, so a full rebuild is
  /// simpler than incremental patching — and it fixes an upstream kbar bug
  /// where replacing an action orphaned its existing children.
  static KBarActionRegistry _build(
    Map<String, KBarAction> definitions,
    int revision,
  ) {
    final Map<String, List<String>> childIds = <String, List<String>>{
      for (final String id in definitions.keys) id: <String>[],
    };
    for (final KBarAction definition in definitions.values) {
      final String? parentId = definition.parent;
      if (parentId != null && childIds.containsKey(parentId)) {
        childIds[parentId]!.add(definition.id);
      }
    }

    final Map<String, KBarActionNode> nodes = <String, KBarActionNode>{
      for (final KBarAction definition in definitions.values)
        definition.id: KBarActionNode._(definition, childIds[definition.id]!),
    };

    final KBarActionRegistry registry = KBarActionRegistry._(
      definitions,
      nodes,
      revision,
    );
    for (final KBarActionNode node in nodes.values) {
      node._registry = registry;
    }
    return registry;
  }

  /// Equality ignores [revision]: two registries holding the same actions are
  /// equal regardless of how they got there.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KBarActionRegistry &&
          mapEquals(other._definitions, _definitions);

  @override
  int get hashCode => Object.hashAll(_definitions.values);

  @override
  String toString() => 'KBarActionRegistry(${_nodes.length} actions)';
}
