import 'dart:math' as math;

import '../kbar_matcher.dart';

/// Maximum pattern length the bitap bitmask can represent.
///
/// Longer patterns are split into chunks of this size and searched separately.
const int kBitapMaxBits = 32;

/// Smallest positive double such that `1 + epsilon != 1`.
///
/// Fuse substitutes `Number.EPSILON` for a perfect (zero) sub-score before
/// exponentiating, since `pow(0, x)` would collapse the whole product to zero.
const double kEpsilon = 2.220446049250313e-16;

/// The outcome of running bitap over a single string.
class BitapResult {
  /// Creates a bitap result.
  const BitapResult({
    required this.isMatch,
    required this.score,
    this.ranges = const <KBarTextRange>[],
  });

  /// A result representing "no match at all".
  static const BitapResult noMatch = BitapResult(isMatch: false, score: 1);

  /// Whether the pattern was found within the threshold.
  final bool isMatch;

  /// Fuse-style score: **0 is perfect, 1 is worst**.
  final double score;

  /// Matched character ranges, ordered and non-overlapping.
  final List<KBarTextRange> ranges;
}

/// Builds the per-character bitmask fuse's bitap loop indexes by.
///
/// Keyed by UTF-16 code unit rather than by `String` to avoid allocating a
/// single-character string for every position of every candidate.
Map<int, int> createPatternAlphabet(String pattern) {
  final Map<int, int> mask = <int, int>{};
  final int length = pattern.length;
  for (int i = 0; i < length; i++) {
    final int char = pattern.codeUnitAt(i);
    mask[char] = (mask[char] ?? 0) | (1 << (length - i - 1));
  }
  return mask;
}

/// Fuse's scoring function: fewer errors and closer to the expected location
/// score lower, and lower is better.
///
/// With [ignoreLocation] — which is what kbar uses — position is irrelevant and
/// the score is purely the error rate.
double computeBitapScore(
  int patternLength, {
  int errors = 0,
  int currentLocation = 0,
  int expectedLocation = 0,
  int distance = 100,
  bool ignoreLocation = false,
}) {
  final double accuracy = errors / patternLength;
  if (ignoreLocation) return accuracy;

  final int proximity = (expectedLocation - currentLocation).abs();
  if (distance == 0) return proximity != 0 ? 1.0 : accuracy;
  return accuracy + proximity / distance;
}

/// Reads [list] at [index], treating out-of-range as zero.
///
/// JavaScript yields `undefined` for an out-of-range array read, which coerces
/// to 0 under the bitwise operators used below. Dart would throw, so the port
/// needs this shim to stay faithful.
int _at(List<int> list, int index) =>
    (index >= 0 && index < list.length) ? list[index] : 0;

/// Converts a per-character hit mask into ordered ranges.
///
/// Runs shorter than [minMatchCharLength] are dropped, which is how fuse
/// suppresses incidental single-character hits.
List<KBarTextRange> convertMaskToRanges(
  List<int> matchMask,
  int minMatchCharLength,
) {
  final List<KBarTextRange> ranges = <KBarTextRange>[];
  int start = -1;
  int i = 0;
  final int length = matchMask.length;

  for (; i < length; i++) {
    final int match = matchMask[i];
    if (match != 0 && start == -1) {
      start = i;
    } else if (match == 0 && start != -1) {
      final int end = i - 1;
      if (end - start + 1 >= minMatchCharLength) {
        // fuse reports inclusive pairs; KBarTextRange is half-open.
        ranges.add(KBarTextRange(start, end + 1));
      }
      start = -1;
    }
  }

  if (length > 0 &&
      matchMask[length - 1] != 0 &&
      start != -1 &&
      length - start >= minMatchCharLength) {
    ranges.add(KBarTextRange(start, length));
  }

  return ranges;
}

/// Runs fuse's bitap search of [pattern] over [text].
///
/// [pattern] must be at most [kBitapMaxBits] long; [BitapSearcher] handles
/// splitting longer patterns.
BitapResult bitapSearch(
  String text,
  String pattern,
  Map<int, int> patternAlphabet, {
  int location = 0,
  int distance = 100,
  double threshold = 0.6,
  bool findAllMatches = false,
  int minMatchCharLength = 1,
  bool ignoreLocation = false,
}) {
  assert(
    pattern.length <= kBitapMaxBits,
    'Pattern length exceeds $kBitapMaxBits',
  );

  final int patternLen = pattern.length;
  final int textLen = text.length;
  final int expectedLocation = location.clamp(0, textLen);
  double currentThreshold = threshold;
  int bestLocation = expectedLocation;

  final List<int> matchMask = List<int>.filled(textLen, 0);

  // Seed the threshold and mask from any exact occurrences.
  int index = text.indexOf(pattern, bestLocation);
  while (index > -1) {
    final double score = computeBitapScore(
      patternLen,
      currentLocation: index,
      expectedLocation: expectedLocation,
      distance: distance,
      ignoreLocation: ignoreLocation,
    );
    currentThreshold = math.min(score, currentThreshold);
    bestLocation = index + patternLen;
    for (int i = 0; i < patternLen; i++) {
      matchMask[index + i] = 1;
    }
    index = text.indexOf(pattern, bestLocation);
  }

  bestLocation = -1;
  List<int> lastBitArr = <int>[];
  double finalScore = 1;
  int binMax = patternLen + textLen;
  final int mask = 1 << (patternLen - 1);

  for (int i = 0; i < patternLen; i++) {
    // Binary-search the furthest location still within the current threshold,
    // which bounds how much of the text this error count has to scan.
    int binMin = 0;
    int binMid = binMax;
    while (binMin < binMid) {
      final double score = computeBitapScore(
        patternLen,
        errors: i,
        currentLocation: expectedLocation + binMid,
        expectedLocation: expectedLocation,
        distance: distance,
        ignoreLocation: ignoreLocation,
      );
      if (score <= currentThreshold) {
        binMin = binMid;
      } else {
        binMax = binMid;
      }
      binMid = ((binMax - binMin) / 2).floor() + binMin;
    }
    binMax = binMid;

    int start = math.max(1, expectedLocation - binMid + 1);
    final int finish = findAllMatches
        ? textLen
        : math.min(expectedLocation + binMid, textLen) + patternLen;

    final List<int> bitArr = List<int>.filled(finish + 2, 0);
    bitArr[finish + 1] = (1 << i) - 1;

    for (int j = finish; j >= start; j--) {
      final int currentLocation = j - 1;
      final int charMatch = currentLocation < textLen
          ? (patternAlphabet[text.codeUnitAt(currentLocation)] ?? 0)
          : 0;

      if (currentLocation < textLen) {
        // Assignment, not OR: a later pass may legitimately clear a position
        // that the exact-match seeding above set.
        matchMask[currentLocation] = charMatch != 0 ? 1 : 0;
      }

      bitArr[j] = ((_at(bitArr, j + 1) << 1) | 1) & charMatch;
      if (i != 0) {
        bitArr[j] |=
            ((_at(lastBitArr, j + 1) | _at(lastBitArr, j)) << 1) |
            1 |
            _at(lastBitArr, j + 1);
      }

      if ((bitArr[j] & mask) != 0) {
        finalScore = computeBitapScore(
          patternLen,
          errors: i,
          currentLocation: currentLocation,
          expectedLocation: expectedLocation,
          distance: distance,
          ignoreLocation: ignoreLocation,
        );

        if (finalScore <= currentThreshold) {
          currentThreshold = finalScore;
          bestLocation = currentLocation;
          if (bestLocation <= expectedLocation) break;
          start = math.max(1, 2 * expectedLocation - bestLocation);
        }
      }
    }

    // One more error would already exceed the threshold, so stop.
    final double nextScore = computeBitapScore(
      patternLen,
      errors: i + 1,
      currentLocation: expectedLocation,
      expectedLocation: expectedLocation,
      distance: distance,
      ignoreLocation: ignoreLocation,
    );
    if (nextScore > currentThreshold) break;

    lastBitArr = bitArr;
  }

  final List<KBarTextRange> ranges = convertMaskToRanges(
    matchMask,
    minMatchCharLength,
  );

  return BitapResult(
    isMatch: bestLocation >= 0 && ranges.isNotEmpty,
    score: math.max(0.001, finalScore),
    ranges: ranges,
  );
}

/// A compiled pattern, ready to be searched against many candidate strings.
///
/// Compiling once and reusing matters: the palette re-scores every action on
/// every keystroke.
class BitapSearcher {
  /// Compiles [pattern].
  BitapSearcher(
    String pattern, {
    this.location = 0,
    this.distance = 100,
    this.threshold = 0.6,
    this.findAllMatches = false,
    this.minMatchCharLength = 1,
    this.isCaseSensitive = false,
    this.ignoreLocation = false,
  }) : pattern = isCaseSensitive ? pattern : pattern.toLowerCase() {
    if (this.pattern.isEmpty) return;

    final int length = this.pattern.length;
    if (length > kBitapMaxBits) {
      int i = 0;
      final int remainder = length % kBitapMaxBits;
      final int end = length - remainder;
      while (i < end) {
        _addChunk(this.pattern.substring(i, i + kBitapMaxBits), i);
        i += kBitapMaxBits;
      }
      if (remainder != 0) {
        // The tail chunk overlaps the previous one so it stays 32 wide.
        final int startIndex = length - kBitapMaxBits;
        _addChunk(this.pattern.substring(startIndex), startIndex);
      }
    } else {
      _addChunk(this.pattern, 0);
    }
  }

  /// The pattern being searched for, already case-folded unless
  /// [isCaseSensitive].
  final String pattern;

  /// Where in the text a match is expected. Irrelevant when [ignoreLocation].
  final int location;

  /// How far from [location] a match may drift before it is penalised.
  final int distance;

  /// Maximum acceptable score, where 0 is a perfect match.
  final double threshold;

  /// Whether to keep scanning after the first match in a string.
  final bool findAllMatches;

  /// Shortest run of matched characters that counts.
  final int minMatchCharLength;

  /// Whether case matters.
  final bool isCaseSensitive;

  /// Whether position within the string is ignored. kbar sets this true.
  final bool ignoreLocation;

  final List<_Chunk> _chunks = <_Chunk>[];

  void _addChunk(String pattern, int startIndex) =>
      _chunks.add(_Chunk(pattern, createPatternAlphabet(pattern), startIndex));

  /// Searches [text] for this pattern.
  BitapResult searchIn(String text) {
    if (_chunks.isEmpty) return BitapResult.noMatch;

    final String haystack = isCaseSensitive ? text : text.toLowerCase();

    if (pattern == haystack) {
      return BitapResult(
        isMatch: true,
        score: 0,
        ranges: <KBarTextRange>[KBarTextRange(0, haystack.length)],
      );
    }

    final List<KBarTextRange> allRanges = <KBarTextRange>[];
    double totalScore = 0;
    bool hasMatches = false;

    for (final _Chunk chunk in _chunks) {
      final BitapResult result = bitapSearch(
        haystack,
        chunk.pattern,
        chunk.alphabet,
        location: location + chunk.startIndex,
        distance: distance,
        threshold: threshold,
        findAllMatches: findAllMatches,
        minMatchCharLength: minMatchCharLength,
        ignoreLocation: ignoreLocation,
      );
      if (result.isMatch) {
        hasMatches = true;
        allRanges.addAll(result.ranges);
      }
      totalScore += result.score;
    }

    return BitapResult(
      isMatch: hasMatches,
      score: hasMatches ? totalScore / _chunks.length : 1,
      ranges: allRanges,
    );
  }
}

class _Chunk {
  const _Chunk(this.pattern, this.alphabet, this.startIndex);

  final String pattern;
  final Map<int, int> alphabet;
  final int startIndex;
}
