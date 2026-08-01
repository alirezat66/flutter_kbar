import 'package:flutter/foundation.dart';

/// A half-open range of characters within a searched string.
///
/// Returned by a [KBarMatcher] so the UI can highlight exactly the characters
/// that matched. kbar asks fuse.js for this information and then discards it;
/// surfacing it is the main reason this abstraction exists.
@immutable
class KBarTextRange {
  /// Creates a range covering `[start, end)`.
  const KBarTextRange(this.start, this.end) : assert(start <= end);

  /// Index of the first matched character, inclusive.
  final int start;

  /// Index one past the last matched character.
  final int end;

  /// Number of characters covered.
  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KBarTextRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'KBarTextRange($start, $end)';
}

/// Which field of an action a set of match ranges belongs to.
enum KBarMatchField {
  /// [KBarSearchable.name].
  name,

  /// One of [KBarSearchable.keywords].
  keywords,

  /// [KBarSearchable.subtitle].
  subtitle,
}

/// The searchable projection of an action.
///
/// Built once per action and cached against the registry revision, so matchers
/// never touch the action tree.
@immutable
class KBarSearchable {
  /// Creates a searchable projection.
  const KBarSearchable({
    required this.name,
    this.keywords = const <String>[],
    this.subtitle,
  });

  /// The action's primary label.
  final String name;

  /// Additional search terms, already split and with the section name appended.
  final List<String> keywords;

  /// The action's secondary text, if any.
  final String? subtitle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KBarSearchable &&
          other.name == name &&
          other.subtitle == subtitle &&
          listEquals(other.keywords, keywords);

  @override
  int get hashCode => Object.hash(name, subtitle, Object.hashAll(keywords));

  @override
  String toString() => 'KBarSearchable("$name")';
}

/// The outcome of matching a query against one [KBarSearchable].
@immutable
class KBarMatch {
  /// Creates a match result.
  const KBarMatch({required this.score, this.ranges = const {}});

  /// How well the candidate matched, in `(0, 1]`. **Higher is better.**
  ///
  /// Normalising the direction is the matcher's job, not the engine's, which is
  /// what lets a differently-scaled algorithm drop in without touching the
  /// ranking maths. Note that fuse.js scores the other way round — 0 is a
  /// perfect match — so [KBarFuseMatcher] inverts before returning.
  final double score;

  /// The matched character ranges, keyed by the field they were found in.
  ///
  /// Ranges within a field are ordered and non-overlapping.
  final Map<KBarMatchField, List<KBarTextRange>> ranges;

  /// Matched ranges within [KBarSearchable.name], or empty.
  List<KBarTextRange> get nameRanges =>
      ranges[KBarMatchField.name] ?? const <KBarTextRange>[];

  /// Matched ranges within [KBarSearchable.subtitle], or empty.
  List<KBarTextRange> get subtitleRanges =>
      ranges[KBarMatchField.subtitle] ?? const <KBarTextRange>[];

  @override
  String toString() =>
      'KBarMatch(score: ${score.toStringAsFixed(4)}, '
      'fields: ${ranges.keys.map((KBarMatchField f) => f.name).join(',')})';
}

/// Scores a query against a candidate action.
///
/// Supply a custom implementation through `KBarOptions.matcher`. Two are
/// bundled:
///
///  * [KBarFuseMatcher] — the default; reproduces kbar's fuse.js ranking.
///  * [KBarCommandScoreMatcher] — a port of cmdk's `command-score`, which is
///    noticeably better for short, command-like names.
abstract interface class KBarMatcher {
  /// Scores [query] against [candidate], or returns null if it does not match.
  ///
  /// [query] is never empty: the engine short-circuits an empty query before
  /// any matcher runs, exactly as kbar does.
  KBarMatch? match(String query, KBarSearchable candidate);
}
