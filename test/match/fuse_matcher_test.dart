@Tags(<String>['oracle'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

import 'package:flutter_kbar/flutter_kbar.dart';
import 'package:flutter_test/flutter_test.dart';

/// Validates the hand-ported bitap against a fixture captured from real
/// fuse.js 6.6.2, configured exactly as kbar configures it.
///
/// Regenerate with `cd tool/fuse_oracle && npm install && node generate.mjs`.
void main() {
  final Map<String, dynamic> fixture =
      jsonDecode(File('test/match/fuse_oracle_fixture.json').readAsStringSync())
          as Map<String, dynamic>;

  final List<Map<String, dynamic>> rawActions =
      (fixture['actions'] as List<dynamic>).cast<Map<String, dynamic>>();
  final List<Map<String, dynamic>> cases = (fixture['cases'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  // Preserve corpus order: fuse breaks score ties by index.
  final List<String> ids = <String>[
    for (final Map<String, dynamic> a in rawActions) a['id'] as String,
  ];
  final Map<String, KBarSearchable> searchables = <String, KBarSearchable>{
    for (final Map<String, dynamic> a in rawActions)
      a['id'] as String: KBarSearchable(
        name: a['name'] as String,
        keywords: (a['keywords'] as String).split(','),
        subtitle: a['subtitle'] as String,
      ),
  };

  const KBarFuseMatcher matcher = KBarFuseMatcher();

  /// Runs the Dart matcher over the whole corpus the way the engine does.
  List<({String id, double score})> rank(String query) {
    final List<({String id, double score, int index})> hits =
        <({String id, double score, int index})>[];
    for (int i = 0; i < ids.length; i++) {
      final KBarMatch? match = matcher.match(query, searchables[ids[i]]!);
      if (match != null) {
        hits.add((id: ids[i], score: match.score, index: i));
      }
    }
    hits.sort((({String id, double score, int index}) a, b) {
      // Higher kbar score first; fuse breaks ties by corpus index.
      final int byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.index.compareTo(b.index);
    });
    return <({String id, double score})>[
      for (final ({String id, double score, int index}) h in hits)
        (id: h.id, score: h.score),
    ];
  }

  test('fixture is non-trivial', () {
    expect(cases, isNotEmpty);
    final int pairs = cases.fold<int>(
      0,
      (int n, Map<String, dynamic> c) =>
          n + (c['results'] as List<dynamic>).length,
    );
    expect(pairs, greaterThan(200), reason: 'oracle should exercise the port');
  });

  group('matches fuse.js', () {
    for (final Map<String, dynamic> testCase in cases) {
      final String query = testCase['query'] as String;
      final List<Map<String, dynamic>> expected =
          (testCase['results'] as List<dynamic>).cast<Map<String, dynamic>>();
      final List<String> expectedIds = <String>[
        for (final Map<String, dynamic> r in expected) r['id'] as String,
      ];

      test('"$query"', () {
        final List<({String id, double score})> actual = rank(query);
        final List<String> actualIds = <({String id, double score})>[
          ...actual,
        ].map((({String id, double score}) h) => h.id).toList();

        expect(
          actualIds.toSet(),
          expectedIds.toSet(),
          reason:
              'matched set differs for "$query"\n'
              '  missing: ${expectedIds.toSet().difference(actualIds.toSet())}\n'
              '  extra:   ${actualIds.toSet().difference(expectedIds.toSet())}',
        );

        expect(actualIds, expectedIds, reason: 'ranking differs for "$query"');

        for (int i = 0; i < expected.length; i++) {
          expect(
            actual[i].score,
            closeTo(expected[i]['kbarScore'] as double, 1e-9),
            reason: 'score differs for "$query" at rank $i (${actual[i].id})',
          );
        }
      });
    }
  });

  group('match ranges agree with fuse', () {
    for (final Map<String, dynamic> testCase in cases) {
      final String query = testCase['query'] as String;
      final List<Map<String, dynamic>> expected =
          (testCase['results'] as List<dynamic>).cast<Map<String, dynamic>>();
      if (expected.isEmpty) continue;

      test('"$query"', () {
        for (final Map<String, dynamic> result in expected) {
          final String id = result['id'] as String;
          final KBarMatch? match = matcher.match(query, searchables[id]!);
          expect(match, isNotNull, reason: '$id should match "$query"');

          for (final String field in <String>['name', 'subtitle']) {
            final Map<String, dynamic>? fuseMatch =
                (result['matches'] as List<dynamic>)
                    .cast<Map<String, dynamic>>()
                    .where((Map<String, dynamic> m) => m['key'] == field)
                    .firstOrNull;

            final List<KBarTextRange> expectedRanges = <KBarTextRange>[
              if (fuseMatch != null)
                for (final List<dynamic> pair
                    in (fuseMatch['indices'] as List<dynamic>)
                        .cast<List<dynamic>>())
                  // fuse reports inclusive pairs.
                  KBarTextRange(pair[0] as int, (pair[1] as int) + 1),
            ];

            final List<KBarTextRange> actualRanges =
                match!.ranges[field == 'name'
                    ? KBarMatchField.name
                    : KBarMatchField.subtitle] ??
                const <KBarTextRange>[];

            expect(
              actualRanges,
              expectedRanges,
              reason: 'ranges differ for "$query" on $id.$field',
            );
          }
        }
      });
    }
  });

  group('range semantics', () {
    test('a substring hit also reports the incidental character hits', () {
      // fuse's mask marks every character present in the pattern, not just the
      // contiguous run, so highlighting is intentionally speckled.
      final KBarMatch? match = matcher.match(
        'theme',
        const KBarSearchable(name: 'Toggle theme'),
      );
      expect(match!.nameRanges, contains(const KBarTextRange(7, 12)));
    });

    test('a perfect match scores just under 1 after inversion', () {
      final KBarMatch? match = matcher.match(
        'save',
        const KBarSearchable(name: 'Save'),
      );
      expect(match!.nameRanges, <KBarTextRange>[const KBarTextRange(0, 4)]);
      // score 0 becomes epsilon before exponentiation, so the inverted score
      // approaches but never reaches 1.
      expect(match.score, lessThan(1.0));
      expect(match.score, greaterThan(0.9999));
    });

    test('are not reported for keywords, which are scored per element', () {
      final KBarMatch? match = matcher.match(
        'vcs',
        const KBarSearchable(name: 'Git status', keywords: <String>['vcs']),
      );
      expect(match, isNotNull);
      expect(match!.ranges.containsKey(KBarMatchField.keywords), isFalse);
    });
  });

  group('non-matches', () {
    test('return null rather than a zero score', () {
      expect(
        matcher.match('qqqq', const KBarSearchable(name: 'Toggle theme')),
        isNull,
      );
    });

    test('an empty query never reaches the matcher', () {
      expect(matcher.match('', const KBarSearchable(name: 'Anything')), isNull);
    });
  });
}
