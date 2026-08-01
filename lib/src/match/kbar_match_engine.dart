import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/kbar_action_registry.dart';
import '../model/kbar_result_item.dart';
import '../model/kbar_section.dart';
import '../model/kbar_state.dart';
import 'kbar_matcher.dart';

/// Turns palette state into the ordered, grouped list of rows to render.
///
/// Where kbar re-runs its whole pipeline inside every `useMatches()` call — a
/// React re-render artefact — this computes once per change and publishes the
/// result through [results], so any number of consumers share one computation.
class KBarMatchEngine {
  /// Creates an engine.
  KBarMatchEngine({required KBarMatcher matcher, required Duration throttle})
    : _matcher = matcher,
      _throttle = throttle;

  final ValueNotifier<KBarMatches> _results = ValueNotifier<KBarMatches>(
    const KBarMatches(),
  );

  KBarMatcher _matcher;
  Duration _throttle;

  KBarState? _state;
  KBarActionRegistry? _lastRegistry;
  String? _lastRootId;
  String? _lastQuery;

  Timer? _cooldown;
  bool _pending = false;
  bool _disposed = false;

  final Map<String, KBarSearchable> _searchableCache =
      <String, KBarSearchable>{};
  int _searchableRevision = -1;

  /// The current results.
  ValueListenable<KBarMatches> get results => _results;

  /// The matcher in use.
  KBarMatcher get matcher => _matcher;

  set matcher(KBarMatcher value) {
    if (_matcher == value) return;
    _matcher = value;
    _runNow();
  }

  /// How long typing is coalesced before re-matching.
  Duration get throttle => _throttle;

  set throttle(Duration value) {
    if (_throttle == value) return;
    _throttle = value;
  }

  /// Feeds new state in, recomputing if any relevant input changed.
  ///
  /// Query changes are throttled; action-tree and nested-action changes are
  /// applied immediately, because those are structural and the user is not
  /// mid-keystroke.
  void update(KBarState state) {
    _state = state;

    final bool registryChanged = state.actions != _lastRegistry;
    final bool rootChanged = state.currentRootActionId != _lastRootId;
    final bool queryChanged = state.searchQuery != _lastQuery;

    if (!registryChanged && !rootChanged && !queryChanged) return;

    if (registryChanged || rootChanged) {
      _runNow();
      return;
    }

    // Leading-edge, then coalesced: the first keystroke shows results
    // immediately and subsequent ones are batched to at most one run per
    // throttle window.
    if (_throttle == Duration.zero) {
      _runNow();
      return;
    }
    if (_cooldown == null) {
      _runNow();
      _startCooldown();
    } else {
      _pending = true;
    }
  }

  void _startCooldown() {
    _cooldown = Timer(_throttle, () {
      _cooldown = null;
      if (_pending) {
        _pending = false;
        _runNow();
        _startCooldown();
      }
    });
  }

  void _runNow() {
    final KBarState? state = _state;
    if (state == null || _disposed) return;
    _lastRegistry = state.actions;
    _lastRootId = state.currentRootActionId;
    _lastQuery = state.searchQuery;
    _results.value = _compute(state);
  }

  KBarSearchable _searchableOf(KBarActionNode node, int revision) {
    if (_searchableRevision != revision) {
      _searchableCache.clear();
      _searchableRevision = revision;
    }
    return _searchableCache[node.id] ??= KBarSearchable(
      name: node.name,
      keywords: node.searchKeywords,
      subtitle: node.subtitle,
    );
  }

  KBarMatches _compute(KBarState state) {
    final KBarActionRegistry registry = state.actions;
    final String? rootId = state.currentRootActionId;
    final String query = state.searchQuery;

    // Candidates are the current level only: top-level actions, or the nested
    // action's direct children.
    final List<KBarActionNode> level = registry.childrenOf(rootId);
    final List<KBarActionNode> candidates = _stableSortedDesc(
      level,
      (KBarActionNode n) => n.priority.toDouble(),
    );

    // An empty query shows just that level; searching flattens the whole
    // subtree beneath it.
    final List<KBarActionNode> pool = query.isEmpty
        ? candidates
        : _deepResults(candidates);

    final List<_Scored> scored = <_Scored>[];
    if (query.isEmpty) {
      for (final KBarActionNode node in pool) {
        scored.add(_Scored(node, 0, null));
      }
    } else {
      for (final KBarActionNode node in pool) {
        final KBarMatch? match = _matcher.match(
          query,
          _searchableOf(node, registry.revision),
        );
        if (match != null) scored.add(_Scored(node, match.score, match));
      }
      _stableSortDescInPlace(scored, (_Scored s) => s.score);
    }

    return KBarMatches(
      items: _group(scored),
      query: query,
      rootAction: registry[rootId],
    );
  }

  /// Groups scored actions into sections and flattens to render order.
  ///
  /// Two inherited kbar behaviours are preserved deliberately:
  ///
  ///  * A section's ordering weight comes from its **first matching member
  ///    only** and is never revisited.
  ///  * An explicit non-zero [KBarSection.priority] *replaces* the match score
  ///    rather than adding to it. In kbar this falls out of
  ///    `section.priority || (0 + score)`, which is almost certainly an
  ///    operator-precedence accident — but it is the shipped behaviour.
  List<KBarResultItem> _group(List<_Scored> scored) {
    final Map<String, List<_Scored>> groups = <String, List<_Scored>>{};
    final List<_SectionEntry> order = <_SectionEntry>[];

    for (final _Scored entry in scored) {
      final KBarSection? section = entry.action.section;
      final bool isNone = section == null || section.isNone;
      final String name = isNone ? KBarSection.none.name : section.name;
      final int? explicit = section?.priority;
      final double priority = (explicit != null && explicit != 0)
          ? explicit.toDouble()
          : entry.score;

      final List<_Scored>? existing = groups[name];
      if (existing == null) {
        groups[name] = <_Scored>[entry];
        order.add(
          _SectionEntry(name: name, priority: priority, isNone: isNone),
        );
      } else {
        existing.add(entry);
      }
    }

    _stableSortDescInPlace(order, (_SectionEntry e) => e.priority);

    final List<KBarResultItem> items = <KBarResultItem>[];
    for (final _SectionEntry entry in order) {
      final List<_Scored> members = groups[entry.name]!;
      _stableSortDescInPlace(
        members,
        (_Scored s) => s.action.priority + s.score,
      );

      if (!entry.isNone) {
        items.add(
          KBarSectionHeader(title: entry.name, priority: entry.priority),
        );
      }
      for (final _Scored member in members) {
        items.add(
          KBarActionResult(
            action: member.action,
            score: member.score,
            match: member.match,
          ),
        );
      }
    }
    return items;
  }

  /// Appends every descendant of [roots], level by level, as kbar does.
  static List<KBarActionNode> _deepResults(List<KBarActionNode> roots) {
    final List<KBarActionNode> all = <KBarActionNode>[...roots];
    final Set<String> seen = <String>{
      for (final KBarActionNode n in roots) n.id,
    };

    void collect(List<KBarActionNode> nodes) {
      for (final KBarActionNode node in nodes) {
        final List<KBarActionNode> children = node.children;
        if (children.isEmpty) continue;
        // `seen` guards against a parent chain that was made cyclic by
        // re-registering an action beneath its own descendant.
        final List<KBarActionNode> fresh = <KBarActionNode>[
          for (final KBarActionNode child in children)
            if (seen.add(child.id)) child,
        ];
        if (fresh.isEmpty) continue;
        all.addAll(fresh);
        collect(fresh);
      }
    }

    collect(roots);
    return all;
  }

  /// Sorts descending by [key], preserving the relative order of equal
  /// elements.
  ///
  /// Dart's [List.sort] is not stable, but kbar relies on JavaScript's stable
  /// sort to break ties by registration order — so ties must be broken here
  /// explicitly or ordering diverges.
  static List<T> _stableSortedDesc<T>(List<T> list, double Function(T) key) {
    final List<T> copy = <T>[...list];
    _stableSortDescInPlace(copy, key);
    return copy;
  }

  static void _stableSortDescInPlace<T>(List<T> list, double Function(T) key) {
    if (list.length < 2) return;
    final List<T> original = <T>[...list];
    final List<int> indices = List<int>.generate(list.length, (int i) => i);
    indices.sort((int a, int b) {
      final int byKey = key(original[b]).compareTo(key(original[a]));
      return byKey != 0 ? byKey : a.compareTo(b);
    });
    for (int i = 0; i < list.length; i++) {
      list[i] = original[indices[i]];
    }
  }

  /// Releases timers and listeners.
  void dispose() {
    _disposed = true;
    _cooldown?.cancel();
    _cooldown = null;
    _results.dispose();
  }
}

class _Scored {
  const _Scored(this.action, this.score, this.match);

  final KBarActionNode action;
  final double score;
  final KBarMatch? match;
}

class _SectionEntry {
  const _SectionEntry({
    required this.name,
    required this.priority,
    required this.isNone,
  });

  final String name;
  final double priority;
  final bool isNone;
}
