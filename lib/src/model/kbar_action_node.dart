part of 'kbar_action_registry.dart';

/// The runtime form of a [KBarAction], with its position in the action tree
/// resolved.
///
/// This is the equivalent of kbar's `ActionImpl`. Nodes are created and owned by
/// a [KBarActionRegistry]; a fresh set is built whenever the registry changes.
///
/// Note on equality: [operator ==] compares this node's definition and its child
/// *ids* — it never dereferences [children] or [ancestors]. Walking the object
/// graph would recurse forever, since a parent reaches its child and the child
/// reaches back through its ancestors. Keeping equality shallow is what lets
/// `DeepCollectionEquality` run over the whole action map in O(n) without
/// blowing the stack.
class KBarActionNode {
  KBarActionNode._(this.definition, this._childIds);

  /// The immutable definition this node was built from.
  final KBarAction definition;

  final List<String> _childIds;

  late final KBarActionRegistry _registry;

  List<KBarActionNode>? _childrenCache;
  List<KBarActionNode>? _ancestorsCache;
  List<String>? _searchKeywordsCache;

  /// Unique identifier. See [KBarAction.id].
  String get id => definition.id;

  /// The primary label. See [KBarAction.name].
  String get name => definition.name;

  /// Key bindings for this action. See [KBarAction.shortcut].
  List<String> get shortcut => definition.shortcut;

  /// Raw additional search terms. See [KBarAction.keywords].
  ///
  /// For the terms actually handed to the matcher — which include the section
  /// name — use [searchKeywords].
  String? get keywords => definition.keywords;

  /// The group this action is listed under. See [KBarAction.section].
  KBarSection? get section => definition.section;

  /// Leading widget. See [KBarAction.icon].
  Widget? get icon => definition.icon;

  /// Secondary text. See [KBarAction.subtitle].
  String? get subtitle => definition.subtitle;

  /// What running this action does. See [KBarAction.perform].
  KBarPerform? get perform => definition.perform;

  /// Ordering weight. See [KBarAction.priority].
  int get priority => definition.priority;

  /// The id of this action's parent, or null if it is top-level.
  String? get parentId => definition.parent;

  /// Whether selecting this action descends into its children rather than
  /// performing it.
  ///
  /// True when the action has no [perform] but does have [children].
  bool get isNavigational => definition.perform == null && _childIds.isNotEmpty;

  /// The ids of this node's direct children, in registration order.
  List<String> get childIds => List<String>.unmodifiable(_childIds);

  /// This node's direct children, in registration order.
  List<KBarActionNode> get children =>
      _childrenCache ??= List<KBarActionNode>.unmodifiable(<KBarActionNode>[
        for (final String childId in _childIds)
          if (_registry[childId] case final KBarActionNode child) child,
      ]);

  /// This node's ancestors, ordered root first and excluding itself.
  ///
  /// Computed lazily by walking [parentId] rather than stored, so that node
  /// equality never has to traverse it.
  List<KBarActionNode> get ancestors => _ancestorsCache ??= _computeAncestors();

  /// This node's direct parent, or null if it is top-level.
  KBarActionNode? get parent => _registry[parentId];

  /// The terms handed to the matcher for the `keywords` field.
  ///
  /// [KBarAction.keywords] split on commas, with the [section] name appended so
  /// that typing a section name surfaces its members. kbar does the same in its
  /// `ActionImpl` constructor.
  List<String> get searchKeywords =>
      _searchKeywordsCache ??= _computeSearchKeywords();

  List<KBarActionNode> _computeAncestors() {
    final List<KBarActionNode> result = <KBarActionNode>[];
    final Set<String> seen = <String>{id};
    String? cursor = parentId;
    // `seen` also guards against a malformed cyclic parent chain.
    while (cursor != null && seen.add(cursor)) {
      final KBarActionNode? node = _registry[cursor];
      if (node == null) break;
      result.add(node);
      cursor = node.parentId;
    }
    return List<KBarActionNode>.unmodifiable(result.reversed);
  }

  List<String> _computeSearchKeywords() {
    final List<String> terms = <String>[
      for (final String term in (definition.keywords ?? '').split(','))
        if (term.trim().isNotEmpty) term.trim(),
    ];
    final KBarSection? section = definition.section;
    if (section != null && !section.isNone && section.name.trim().isNotEmpty) {
      terms.add(section.name.trim());
    }
    return List<String>.unmodifiable(terms);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KBarActionNode &&
          other.definition == definition &&
          listEquals(other._childIds, _childIds);

  @override
  int get hashCode => Object.hash(definition, Object.hashAll(_childIds));

  @override
  String toString() =>
      'KBarActionNode($id, "$name", children: ${_childIds.length})';
}
