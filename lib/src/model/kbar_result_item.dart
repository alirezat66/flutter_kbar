import 'package:flutter/foundation.dart';

import '../match/kbar_matcher.dart';
import 'kbar_action_registry.dart';

/// One row in the flattened result list: either a section heading or an action.
///
/// kbar models this as `(string | ActionImpl)[]`, which forces untyped checks
/// at every call site. A sealed type makes `switch` exhaustive, so adding a row
/// kind later is a compile error rather than a silent fall-through.
///
/// ```dart
/// switch (item) {
///   case KBarSectionHeader(:final title) => SectionHeader(title),
///   case KBarActionResult(:final action) => ActionTile(action),
/// }
/// ```
sealed class KBarResultItem {
  /// Const constructor for subclasses.
  const KBarResultItem();

  /// Whether this row can be highlighted and selected.
  ///
  /// False for section headings, which keyboard navigation skips over.
  bool get isSelectable => this is KBarActionResult;
}

/// A section heading row.
final class KBarSectionHeader extends KBarResultItem {
  /// Creates a heading row.
  const KBarSectionHeader({required this.title, required this.priority});

  /// The text to render.
  final String title;

  /// The ordering weight this section was placed with.
  final double priority;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KBarSectionHeader &&
          other.title == title &&
          other.priority == priority;

  @override
  int get hashCode => Object.hash(title, priority);

  @override
  String toString() => 'KBarSectionHeader("$title")';
}

/// An action row, together with how it matched the query.
final class KBarActionResult extends KBarResultItem {
  /// Creates an action row.
  const KBarActionResult({
    required this.action,
    required this.score,
    this.match,
  });

  /// The action to render and, if chosen, perform.
  final KBarActionNode action;

  /// How well it matched, in `(0, 1]`, or 0 when the query was empty.
  final double score;

  /// Field-level match detail, or null when the query was empty.
  ///
  /// Use [KBarMatch.nameRanges] to highlight the matched characters.
  final KBarMatch? match;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KBarActionResult &&
          other.action == action &&
          other.score == score;

  @override
  int get hashCode => Object.hash(action, score);

  @override
  String toString() => 'KBarActionResult(${action.id}, score: $score)';
}

/// The complete, ordered result of matching the current query.
@immutable
class KBarMatches {
  /// Creates a result set.
  const KBarMatches({
    this.items = const <KBarResultItem>[],
    this.query = '',
    this.rootAction,
  });

  /// Section headings and action rows, interleaved and ready to render.
  final List<KBarResultItem> items;

  /// The query these results were produced for.
  ///
  /// May lag [KBarState.searchQuery] briefly, since matching is throttled.
  final String query;

  /// The nested action being browsed, if any.
  final KBarActionNode? rootAction;

  /// Just the action rows, without headings.
  List<KBarActionResult> get actionResults => <KBarActionResult>[
    for (final KBarResultItem item in items)
      if (item is KBarActionResult) item,
  ];

  /// Whether there is nothing to show.
  bool get isEmpty => items.isEmpty;

  /// Whether there is at least one row.
  bool get isNotEmpty => items.isNotEmpty;

  /// Index of the first selectable row, or null when there is none.
  ///
  /// This is where the highlight lands after the query changes — index 1 when
  /// the list opens with a section heading.
  int? get firstSelectableIndex {
    for (int i = 0; i < items.length; i++) {
      if (items[i].isSelectable) return i;
    }
    return null;
  }

  /// Index of the last selectable row, or null when there is none.
  int? get lastSelectableIndex {
    for (int i = items.length - 1; i >= 0; i--) {
      if (items[i].isSelectable) return i;
    }
    return null;
  }

  /// The action at [index], or null if that row is a heading or out of range.
  KBarActionNode? actionAt(int index) {
    if (index < 0 || index >= items.length) return null;
    final KBarResultItem item = items[index];
    return item is KBarActionResult ? item.action : null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KBarMatches &&
          other.query == query &&
          other.rootAction == rootAction &&
          listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(query, rootAction, Object.hashAll(items));

  @override
  String toString() => 'KBarMatches(${items.length} rows, query: "$query")';
}
