import 'dart:math' as math;

import '../kbar_matcher.dart';
import 'bitap.dart';

final RegExp _tokens = RegExp(r'[^ ]+');

/// Fuse's field-length norm: shorter fields score better.
///
/// `1 / sqrt(tokenCount)`, rounded to three decimals exactly as fuse does — the
/// rounding is load-bearing, since the value becomes an exponent.
double _fieldNorm(String value) {
  final int tokenCount = _tokens.allMatches(value).length;
  if (tokenCount == 0) return 1;
  final double norm = 1 / math.sqrt(tokenCount);
  return (norm * 1000).round() / 1000;
}

bool _isBlank(String value) => value.trim().isEmpty;

/// One-entry memo so a keystroke compiles its pattern once rather than once per
/// candidate. The palette re-scores every action on every keystroke, and
/// [KBarMatcher.match] is called per candidate with the same query.
BitapSearcher? _cachedSearcher;
String? _cachedKey;

BitapSearcher _searcherFor(String query, String cacheKey, KBarFuseMatcher m) {
  if (_cachedKey == cacheKey && _cachedSearcher != null) {
    return _cachedSearcher!;
  }
  final BitapSearcher searcher = BitapSearcher(
    query,
    location: m.location,
    distance: m.distance,
    threshold: m.threshold,
    minMatchCharLength: m.minMatchCharLength,
    isCaseSensitive: m.isCaseSensitive,
    ignoreLocation: m.ignoreLocation,
  );
  _cachedKey = cacheKey;
  _cachedSearcher = searcher;
  return searcher;
}

/// The default matcher: a port of fuse.js 6.6.2 configured exactly as kbar
/// configures it.
///
/// Ranking parity with kbar is verified against a fixture captured from real
/// fuse.js — see `tool/fuse_oracle/` and `test/match/fuse_matcher_test.dart`.
///
/// ## A note on weights
///
/// kbar declares `name: 0.5`, `keywords: 0.5` and leaves `subtitle` at fuse's
/// default of `1`, which makes **subtitle the heaviest field** — twice the
/// weight of the name. That is almost certainly not what kbar intended, but it
/// is what kbar ships, so it is reproduced here. Pass equal weights to opt out:
///
/// ```dart
/// const KBarFuseMatcher(nameWeight: 1, keywordsWeight: 1, subtitleWeight: 1)
/// ```
///
/// If short command names matter more to you than kbar parity, consider
/// [KBarCommandScoreMatcher] instead.
class KBarFuseMatcher implements KBarMatcher {
  /// Creates a matcher. Defaults reproduce kbar exactly.
  const KBarFuseMatcher({
    this.threshold = 0.2,
    this.ignoreLocation = true,
    this.minMatchCharLength = 1,
    this.location = 0,
    this.distance = 100,
    this.nameWeight = 0.5,
    this.keywordsWeight = 0.5,
    this.subtitleWeight = 1.0,
    this.ignoreFieldNorm = false,
    this.isCaseSensitive = false,
  });

  /// Maximum acceptable per-field score, where 0 is perfect. Lower is stricter.
  final double threshold;

  /// Whether where the match occurs in the string is ignored. kbar sets true.
  final bool ignoreLocation;

  /// Shortest run of matched characters that counts as a match.
  final int minMatchCharLength;

  /// Where in the string a match is expected. Unused when [ignoreLocation].
  final int location;

  /// How far a match may drift from [location] before being penalised.
  final int distance;

  /// Relative weight of [KBarSearchable.name].
  final double nameWeight;

  /// Relative weight of [KBarSearchable.keywords].
  final double keywordsWeight;

  /// Relative weight of [KBarSearchable.subtitle].
  final double subtitleWeight;

  /// Whether to ignore the field-length norm that favours shorter fields.
  final bool ignoreFieldNorm;

  /// Whether matching is case-sensitive.
  final bool isCaseSensitive;

  @override
  KBarMatch? match(String query, KBarSearchable candidate) {
    if (query.isEmpty) return null;

    final String cacheKey =
        '$query|$threshold|$ignoreLocation|$minMatchCharLength|'
        '$location|$distance|$isCaseSensitive';
    final BitapSearcher searcher = _searcherFor(query, cacheKey, this);

    double totalScore = 1;
    bool matched = false;
    final Map<KBarMatchField, List<KBarTextRange>> ranges =
        <KBarMatchField, List<KBarTextRange>>{};

    // Weights are used raw. Fuse's KeyStore does normalise them so they sum to
    // one, but that normalised copy is never the one scoring sees: the index
    // builds its own key objects from the same source and those keep the
    // original weights. Dividing here would put every exponent out by a
    // constant factor and break parity.
    void accumulate(double score, double weight, double norm) {
      matched = true;
      totalScore *= math.pow(
        score == 0 ? kEpsilon : score,
        weight * (ignoreFieldNorm ? 1 : norm),
      );
    }

    // name
    if (!_isBlank(candidate.name)) {
      final BitapResult result = searcher.searchIn(candidate.name);
      if (result.isMatch) {
        accumulate(result.score, nameWeight, _fieldNorm(candidate.name));
        ranges[KBarMatchField.name] = result.ranges;
      }
    }

    // keywords — an array-valued key, so every matching element contributes its
    // own factor, exactly as fuse does.
    //
    // Ranges are deliberately not reported for keywords: each element is scored
    // against its own string, so the indices are only meaningful relative to
    // that element and cannot be mapped onto anything the UI renders.
    for (final String keyword in candidate.keywords) {
      if (_isBlank(keyword)) continue;
      final BitapResult result = searcher.searchIn(keyword);
      if (result.isMatch) {
        accumulate(result.score, keywordsWeight, _fieldNorm(keyword));
      }
    }

    // subtitle
    final String? subtitle = candidate.subtitle;
    if (subtitle != null && !_isBlank(subtitle)) {
      final BitapResult result = searcher.searchIn(subtitle);
      if (result.isMatch) {
        accumulate(result.score, subtitleWeight, _fieldNorm(subtitle));
        ranges[KBarMatchField.subtitle] = result.ranges;
      }
    }

    if (!matched) return null;

    // kbar flips fuse's "lower is better" into "higher is better", landing in
    // (0.5, 1] for any real match.
    return KBarMatch(score: 1 / (totalScore + 1), ranges: ranges);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KBarFuseMatcher &&
          other.threshold == threshold &&
          other.ignoreLocation == ignoreLocation &&
          other.minMatchCharLength == minMatchCharLength &&
          other.location == location &&
          other.distance == distance &&
          other.nameWeight == nameWeight &&
          other.keywordsWeight == keywordsWeight &&
          other.subtitleWeight == subtitleWeight &&
          other.ignoreFieldNorm == ignoreFieldNorm &&
          other.isCaseSensitive == isCaseSensitive;

  @override
  int get hashCode => Object.hash(
    threshold,
    ignoreLocation,
    minMatchCharLength,
    location,
    distance,
    nameWeight,
    keywordsWeight,
    subtitleWeight,
    ignoreFieldNorm,
    isCaseSensitive,
  );
}
