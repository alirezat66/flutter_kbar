@Tags(<String>['oracle'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_kbar/flutter_kbar.dart';
import 'package:flutter_kbar/src/match/command_score/command_score.dart';
import 'package:flutter_test/flutter_test.dart';

/// Validates the command-score port against a fixture generated from cmdk's
/// own source.
///
/// Regenerate with `node tool/command_score_oracle/generate.mjs`.
void main() {
  final Map<String, dynamic> fixture =
      jsonDecode(
            File(
              'test/match/command_score_oracle_fixture.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final List<Map<String, dynamic>> cases = (fixture['cases'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  test('fixture is non-trivial', () {
    expect(cases.length, greaterThan(1000));
    expect(
      cases.where((Map<String, dynamic> c) => (c['score'] as num) > 0).length,
      greaterThan(500),
    );
  });

  test('every case matches cmdk exactly', () {
    final List<String> failures = <String>[];

    for (final Map<String, dynamic> testCase in cases) {
      final String string = testCase['string'] as String;
      final String abbreviation = testCase['abbreviation'] as String;
      final List<String> aliases = (testCase['aliases'] as List<dynamic>)
          .cast<String>();
      final double expected = (testCase['score'] as num).toDouble();

      final double actual = commandScore(
        string,
        abbreviation,
        aliases: aliases,
      ).score;

      if ((actual - expected).abs() > 1e-12) {
        failures.add(
          '"$string" x "$abbreviation" aliases=$aliases: '
          'expected $expected, got $actual',
        );
      }
    }

    expect(failures, isEmpty, reason: failures.take(10).join('\n'));
  });

  group('ranking behaviour', () {
    test('an acronym beats an unrelated substring', () {
      // The case fuse handles badly: "gs" should find "Git status".
      final double gitStatus = commandScore('Git status', 'gs').score;
      final double settings = commandScore('Open settings', 'gs').score;
      expect(gitStatus, greaterThan(settings));
    });

    test('a complete match outscores a prefix of a longer string', () {
      expect(
        commandScore('html', 'html').score,
        greaterThan(commandScore('html5', 'html').score),
      );
    });

    test('exact case beats mismatched case', () {
      expect(
        commandScore('HTML', 'HM').score,
        greaterThan(commandScore('haml', 'HM').score),
      );
    });

    test('a shorter candidate beats a longer one for the same letters', () {
      expect(
        commandScore('bad', 'bd').score,
        greaterThan(commandScore('bard', 'bd').score),
      );
    });

    test('no match scores zero', () {
      expect(commandScore('Git status', 'zzz').score, 0);
    });
  });

  group('KBarCommandScoreMatcher', () {
    const KBarCommandScoreMatcher matcher = KBarCommandScoreMatcher();

    test('keywords participate in matching', () {
      expect(
        matcher.match(
          'vcs',
          const KBarSearchable(name: 'Git status', keywords: <String>['vcs']),
        ),
        isNotNull,
      );
      expect(
        matcher.match('vcs', const KBarSearchable(name: 'Git status')),
        isNull,
      );
    });

    test('subtitle participates unless disabled', () {
      const KBarSearchable candidate = KBarSearchable(
        name: 'Git status',
        subtitle: 'Show the working tree',
      );
      expect(matcher.match('working', candidate), isNotNull);
      expect(
        const KBarCommandScoreMatcher(
          searchSubtitle: false,
        ).match('working', candidate),
        isNull,
      );
    });

    test('reports contiguous name ranges for a prefix match', () {
      final KBarMatch? match = matcher.match(
        'git',
        const KBarSearchable(name: 'Git status'),
      );
      expect(match!.nameRanges, <KBarTextRange>[const KBarTextRange(0, 3)]);
    });

    test('reports split ranges for an acronym match', () {
      final KBarMatch? match = matcher.match(
        'gs',
        const KBarSearchable(name: 'Git status'),
      );
      expect(match!.nameRanges, <KBarTextRange>[
        const KBarTextRange(0, 1),
        const KBarTextRange(4, 5),
      ]);
    });

    test('omits ranges when the query only matches via keywords', () {
      final KBarMatch? match = matcher.match(
        'vcs',
        const KBarSearchable(name: 'Git status', keywords: <String>['vcs']),
      );
      expect(match!.nameRanges, isEmpty);
    });

    test('minScore filters weak matches', () {
      const KBarSearchable candidate = KBarSearchable(
        name: 'Clear cache and reload the application window',
      );
      // Word-start matches score well even across a long string.
      final KBarMatch? weak = matcher.match('cw', candidate);
      expect(weak, isNotNull);
      expect(weak!.score, closeTo(0.8865, 0.001));

      expect(
        const KBarCommandScoreMatcher(minScore: 0.9).match('cw', candidate),
        isNull,
      );
    });

    test('scores are already higher-is-better, needing no inversion', () {
      // Exactly 1.0 requires an exact-case, complete match.
      expect(
        matcher.match('Save', const KBarSearchable(name: 'Save'))!.score,
        1.0,
      );
      // Lower-casing the query costs the case-mismatch penalty.
      expect(
        matcher.match('save', const KBarSearchable(name: 'Save'))!.score,
        closeTo(kPenaltyCaseMismatch, 1e-12),
      );
    });
  });
}
