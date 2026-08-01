import '../kbar_matcher.dart';
import 'command_score.dart';

/// An alternative matcher that ports cmdk's `command-score`.
///
/// Noticeably better than [KBarFuseMatcher] for short, command-like names,
/// because it rewards word-start and acronym matches instead of treating the
/// query as an approximate substring. Typing `gs` ranks "Git status" first
/// here; under fuse it barely matches at all.
///
/// Opt in with:
///
/// ```dart
/// KBarProvider(
///   options: const KBarOptions(matcher: KBarCommandScoreMatcher()),
///   child: ...,
/// )
/// ```
///
/// The trade-off is that ranking no longer matches kbar's.
class KBarCommandScoreMatcher implements KBarMatcher {
  /// Creates a command-score matcher.
  const KBarCommandScoreMatcher({
    this.minScore = 0,
    this.includeRanges = true,
    this.searchSubtitle = true,
  });

  /// Scores at or below this are treated as no match.
  ///
  /// Raise it to hide weak fuzzy hits; `0.1` is a reasonable floor if the
  /// default feels too permissive.
  final double minScore;

  /// Whether to compute match ranges for highlighting.
  ///
  /// Costs a second pass over the name. Disable if you never highlight.
  final bool includeRanges;

  /// Whether [KBarSearchable.subtitle] participates in matching.
  ///
  /// cmdk has no notion of a subtitle; when true it is appended alongside the
  /// keywords, so subtitle text is searchable just as it is under fuse.
  final bool searchSubtitle;

  @override
  KBarMatch? match(String query, KBarSearchable candidate) {
    if (query.isEmpty) return null;

    final List<String> aliases = <String>[
      for (final String keyword in candidate.keywords)
        if (keyword.trim().isNotEmpty) keyword.trim(),
      if (searchSubtitle &&
          candidate.subtitle != null &&
          candidate.subtitle!.trim().isNotEmpty)
        candidate.subtitle!.trim(),
    ];

    final CommandScoreResult result = commandScore(
      candidate.name,
      query,
      aliases: aliases,
    );
    if (result.score <= minScore) return null;

    Map<KBarMatchField, List<KBarTextRange>> ranges =
        const <KBarMatchField, List<KBarTextRange>>{};

    if (includeRanges) {
      // Re-score against the name alone. Indices from the combined string would
      // run past the end of the name and cannot be rendered; scoring the name
      // on its own yields ranges only when the whole query fits inside it,
      // which is exactly when highlighting is meaningful.
      final CommandScoreResult nameOnly = commandScore(candidate.name, query);
      if (nameOnly.score > 0 && nameOnly.indices.isNotEmpty) {
        ranges = <KBarMatchField, List<KBarTextRange>>{
          KBarMatchField.name: _toRanges(nameOnly.indices),
        };
      }
    }

    return KBarMatch(score: result.score, ranges: ranges);
  }

  /// Collapses ascending indices into contiguous half-open ranges.
  static List<KBarTextRange> _toRanges(List<int> indices) {
    final List<int> sorted = <int>[...indices]..sort();
    final List<KBarTextRange> ranges = <KBarTextRange>[];
    int start = sorted.first;
    int previous = sorted.first;

    for (int i = 1; i < sorted.length; i++) {
      final int current = sorted[i];
      if (current == previous) continue;
      if (current != previous + 1) {
        ranges.add(KBarTextRange(start, previous + 1));
        start = current;
      }
      previous = current;
    }
    ranges.add(KBarTextRange(start, previous + 1));
    return ranges;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KBarCommandScoreMatcher &&
          other.minScore == minScore &&
          other.includeRanges == includeRanges &&
          other.searchSubtitle == searchSubtitle;

  @override
  int get hashCode => Object.hash(minScore, includeRanges, searchSubtitle);
}
