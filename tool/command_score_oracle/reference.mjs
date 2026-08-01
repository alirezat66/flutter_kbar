// Verbatim copy of cmdk's command-score.ts (types stripped), used only to
// generate the oracle fixture the Dart port is validated against.
//
// Source: https://github.com/pacocoursey/cmdk/blob/main/cmdk/src/command-score.ts

var SCORE_CONTINUE_MATCH = 1,
  SCORE_SPACE_WORD_JUMP = 0.9,
  SCORE_NON_SPACE_WORD_JUMP = 0.8,
  SCORE_CHARACTER_JUMP = 0.17,
  SCORE_TRANSPOSITION = 0.1,
  PENALTY_SKIPPED = 0.999,
  PENALTY_CASE_MISMATCH = 0.9999,
  PENALTY_NOT_COMPLETE = 0.99;

var IS_GAP_REGEXP = /[\\\/_+.#"@\[\(\{&]/,
  COUNT_GAPS_REGEXP = /[\\\/_+.#"@\[\(\{&]/g,
  IS_SPACE_REGEXP = /[\s-]/,
  COUNT_SPACE_REGEXP = /[\s-]/g;

function commandScoreInner(
  string,
  abbreviation,
  lowerString,
  lowerAbbreviation,
  stringIndex,
  abbreviationIndex,
  memoizedResults,
) {
  if (abbreviationIndex === abbreviation.length) {
    if (stringIndex === string.length) {
      return SCORE_CONTINUE_MATCH;
    }
    return PENALTY_NOT_COMPLETE;
  }

  var memoizeKey = `${stringIndex},${abbreviationIndex}`;
  if (memoizedResults[memoizeKey] !== undefined) {
    return memoizedResults[memoizeKey];
  }

  var abbreviationChar = lowerAbbreviation.charAt(abbreviationIndex);
  var index = lowerString.indexOf(abbreviationChar, stringIndex);
  var highScore = 0;

  var score, transposedScore, wordBreaks, spaceBreaks;

  while (index >= 0) {
    score = commandScoreInner(
      string,
      abbreviation,
      lowerString,
      lowerAbbreviation,
      index + 1,
      abbreviationIndex + 1,
      memoizedResults,
    );
    if (score > highScore) {
      if (index === stringIndex) {
        score *= SCORE_CONTINUE_MATCH;
      } else if (IS_GAP_REGEXP.test(string.charAt(index - 1))) {
        score *= SCORE_NON_SPACE_WORD_JUMP;
        wordBreaks = string.slice(stringIndex, index - 1).match(COUNT_GAPS_REGEXP);
        if (wordBreaks && stringIndex > 0) {
          score *= Math.pow(PENALTY_SKIPPED, wordBreaks.length);
        }
      } else if (IS_SPACE_REGEXP.test(string.charAt(index - 1))) {
        score *= SCORE_SPACE_WORD_JUMP;
        spaceBreaks = string.slice(stringIndex, index - 1).match(COUNT_SPACE_REGEXP);
        if (spaceBreaks && stringIndex > 0) {
          score *= Math.pow(PENALTY_SKIPPED, spaceBreaks.length);
        }
      } else {
        score *= SCORE_CHARACTER_JUMP;
        if (stringIndex > 0) {
          score *= Math.pow(PENALTY_SKIPPED, index - stringIndex);
        }
      }

      if (string.charAt(index) !== abbreviation.charAt(abbreviationIndex)) {
        score *= PENALTY_CASE_MISMATCH;
      }
    }

    if (
      (score < SCORE_TRANSPOSITION &&
        lowerString.charAt(index - 1) === lowerAbbreviation.charAt(abbreviationIndex + 1)) ||
      (lowerAbbreviation.charAt(abbreviationIndex + 1) === lowerAbbreviation.charAt(abbreviationIndex) &&
        lowerString.charAt(index - 1) !== lowerAbbreviation.charAt(abbreviationIndex))
    ) {
      transposedScore = commandScoreInner(
        string,
        abbreviation,
        lowerString,
        lowerAbbreviation,
        index + 1,
        abbreviationIndex + 2,
        memoizedResults,
      );

      if (transposedScore * SCORE_TRANSPOSITION > score) {
        score = transposedScore * SCORE_TRANSPOSITION;
      }
    }

    if (score > highScore) {
      highScore = score;
    }

    index = lowerString.indexOf(abbreviationChar, index + 1);
  }

  memoizedResults[memoizeKey] = highScore;
  return highScore;
}

function formatInput(string) {
  return string.toLowerCase().replace(COUNT_SPACE_REGEXP, ' ');
}

export function commandScore(string, abbreviation, aliases) {
  string = aliases && aliases.length > 0 ? `${string + ' ' + aliases.join(' ')}` : string;
  return commandScoreInner(
    string,
    abbreviation,
    formatInput(string),
    formatInput(abbreviation),
    0,
    0,
    {},
  );
}
