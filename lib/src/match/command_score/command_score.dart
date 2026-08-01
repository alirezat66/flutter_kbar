import 'dart:math' as math;

/// A continuous run of matched characters scores best.
const double kScoreContinueMatch = 1;

/// Starting a new word after a space scores well.
const double kScoreSpaceWordJump = 0.9;

/// Starting a new word after punctuation scores slightly less than a space.
const double kScoreNonSpaceWordJump = 0.8;

/// Matching mid-word is allowed but heavily discounted.
const double kScoreCharacterJump = 0.17;

/// Two transposed letters are recognised, but strongly penalised.
const double kScoreTransposition = 0.1;

/// Each skipped character decays the score slightly.
const double kPenaltySkipped = 0.999;

/// A case-insensitive match scores just below an exact-case one.
const double kPenaltyCaseMismatch = 0.9999;

/// A candidate longer than the query is penalised a little.
const double kPenaltyNotComplete = 0.99;

final RegExp _isGap = RegExp(r'[\\/_+.#"@\[\(\{&]');
final RegExp _isSpace = RegExp(r'[\s-]');

/// How a query matched a candidate under [commandScore].
class CommandScoreResult {
  /// Creates a result.
  const CommandScoreResult(this.score, this.indices);

  /// No match.
  static const CommandScoreResult none = CommandScoreResult(0, <int>[]);

  /// The score, in `(0, 1]`. Higher is better; zero means no match.
  final double score;

  /// Indices into the candidate of the characters that matched, ascending.
  final List<int> indices;
}

/// JavaScript's `String.charAt`: out of range yields an empty string rather
/// than throwing.
String _charAt(String string, int index) =>
    (index >= 0 && index < string.length) ? string[index] : '';

/// JavaScript's `String.slice` for the non-negative case, tolerating
/// `end < start` by yielding an empty string.
String _slice(String string, int start, int end) {
  final int from = start.clamp(0, string.length);
  final int to = end.clamp(0, string.length);
  return to <= from ? '' : string.substring(from, to);
}

/// Lower-cases and normalises every whitespace-ish character to a plain space,
/// so that hyphens and spaces match each other.
String formatCommandScoreInput(String string) =>
    string.toLowerCase().replaceAll(_isSpace, ' ');

/// Scores how well [abbreviation] matches [string], the way cmdk does.
///
/// [aliases] are appended to [string] before matching, which is how keywords
/// participate.
///
/// Returns a score in `(0, 1]` where 1 is a perfect, complete match, plus the
/// indices of the matched characters for highlighting. A score of zero means no
/// match.
///
/// This is a direct port of cmdk's `command-score.ts` and is validated against
/// a fixture generated from that source — see `tool/command_score_oracle/`.
CommandScoreResult commandScore(
  String string,
  String abbreviation, {
  List<String> aliases = const <String>[],
}) {
  final String haystack = aliases.isNotEmpty
      ? '$string ${aliases.join(' ')}'
      : string;
  return _inner(
    haystack,
    abbreviation,
    formatCommandScoreInput(haystack),
    formatCommandScoreInput(abbreviation),
    0,
    0,
    <int, CommandScoreResult>{},
  );
}

CommandScoreResult _inner(
  String string,
  String abbreviation,
  String lowerString,
  String lowerAbbreviation,
  int stringIndex,
  int abbreviationIndex,
  Map<int, CommandScoreResult> memo,
) {
  if (abbreviationIndex == abbreviation.length) {
    return CommandScoreResult(
      stringIndex == string.length ? kScoreContinueMatch : kPenaltyNotComplete,
      const <int>[],
    );
  }

  // A single int key is cheaper than the "i,j" string cmdk builds.
  final int memoKey =
      stringIndex * (abbreviation.length + 1) + abbreviationIndex;
  final CommandScoreResult? cached = memo[memoKey];
  if (cached != null) return cached;

  final String abbreviationChar = _charAt(lowerAbbreviation, abbreviationIndex);
  int index = lowerString.indexOf(abbreviationChar, stringIndex);

  double highScore = 0;
  List<int> bestIndices = const <int>[];

  while (index >= 0) {
    final CommandScoreResult child = _inner(
      string,
      abbreviation,
      lowerString,
      lowerAbbreviation,
      index + 1,
      abbreviationIndex + 1,
      memo,
    );
    double score = child.score;
    List<int> indices = <int>[index, ...child.indices];

    // Note the faithful oddity: the multipliers are applied only when the raw
    // child score already beats the running best. When it does not, `score`
    // stays raw and is compared as such by the transposition branch below.
    if (score > highScore) {
      if (index == stringIndex) {
        score *= kScoreContinueMatch;
      } else if (_isGap.hasMatch(_charAt(string, index - 1))) {
        score *= kScoreNonSpaceWordJump;
        final int wordBreaks = _isGap
            .allMatches(_slice(string, stringIndex, index - 1))
            .length;
        if (wordBreaks > 0 && stringIndex > 0) {
          score *= math.pow(kPenaltySkipped, wordBreaks);
        }
      } else if (_isSpace.hasMatch(_charAt(string, index - 1))) {
        score *= kScoreSpaceWordJump;
        final int spaceBreaks = _isSpace
            .allMatches(_slice(string, stringIndex, index - 1))
            .length;
        if (spaceBreaks > 0 && stringIndex > 0) {
          score *= math.pow(kPenaltySkipped, spaceBreaks);
        }
      } else {
        score *= kScoreCharacterJump;
        if (stringIndex > 0) {
          score *= math.pow(kPenaltySkipped, index - stringIndex);
        }
      }

      if (_charAt(string, index) != _charAt(abbreviation, abbreviationIndex)) {
        score *= kPenaltyCaseMismatch;
      }
    }

    final String nextAbbrevChar = _charAt(
      lowerAbbreviation,
      abbreviationIndex + 1,
    );
    final String previousChar = _charAt(lowerString, index - 1);
    if ((score < kScoreTransposition && previousChar == nextAbbrevChar) ||
        (nextAbbrevChar == abbreviationChar &&
            previousChar != abbreviationChar)) {
      final CommandScoreResult transposed = _inner(
        string,
        abbreviation,
        lowerString,
        lowerAbbreviation,
        index + 1,
        abbreviationIndex + 2,
        memo,
      );
      if (transposed.score * kScoreTransposition > score) {
        score = transposed.score * kScoreTransposition;
        indices = <int>[index, ...transposed.indices];
      }
    }

    if (score > highScore) {
      highScore = score;
      bestIndices = indices;
    }

    index = lowerString.indexOf(abbreviationChar, index + 1);
  }

  final CommandScoreResult result = CommandScoreResult(highScore, bestIndices);
  memo[memoKey] = result;
  return result;
}
