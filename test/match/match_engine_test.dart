import 'package:fake_async/fake_async.dart';
import 'package:flutter_kbar/flutter_kbar.dart';
import 'package:flutter_test/flutter_test.dart';

/// Names of the rows produced, with headings marked so ordering is readable.
List<String> rows(KBarMatches matches) => <String>[
  for (final KBarResultItem item in matches.items)
    switch (item) {
      KBarSectionHeader(:final String title) => '# $title',
      KBarActionResult(:final KBarActionNode action) => action.name,
    },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KBarController controller;
  tearDown(() => controller.dispose());

  KBarController build(
    List<KBarAction> actions, {
    KBarOptions options = const KBarOptions(searchThrottle: Duration.zero),
  }) => controller = KBarController(actions: actions, options: options);

  group('candidate selection', () {
    test('an empty query shows only the current level', () {
      build(<KBarAction>[
        const KBarAction(id: 'top', name: 'Top'),
        const KBarAction(id: 'child', name: 'Child', parent: 'top'),
        const KBarAction(id: 'grand', name: 'Grand', parent: 'child'),
      ]);
      expect(rows(controller.matches.value), <String>['Top']);
    });

    test('a nested root shows only its direct children', () {
      build(<KBarAction>[
        const KBarAction(id: 'top', name: 'Top'),
        const KBarAction(id: 'a', name: 'Alpha', parent: 'top'),
        const KBarAction(id: 'b', name: 'Beta', parent: 'top'),
        const KBarAction(id: 'deep', name: 'Deep', parent: 'a'),
      ]).setCurrentRootAction('top');
      expect(rows(controller.matches.value), <String>['Alpha', 'Beta']);
    });

    test('searching flattens every descendant of the current level', () {
      build(<KBarAction>[
        const KBarAction(id: 'top', name: 'Top thing'),
        const KBarAction(id: 'child', name: 'Child thing', parent: 'top'),
        const KBarAction(id: 'grand', name: 'Grand thing', parent: 'child'),
      ]).setSearch('thing');
      expect(rows(controller.matches.value), <String>[
        'Top thing',
        'Child thing',
        'Grand thing',
      ]);
    });

    test('searching inside a nested root stays within that subtree', () {
      build(<KBarAction>[
          const KBarAction(id: 'top', name: 'Top thing'),
          const KBarAction(id: 'child', name: 'Child thing', parent: 'top'),
          const KBarAction(id: 'other', name: 'Other thing'),
        ])
        ..setCurrentRootAction('top')
        ..setSearch('thing');
      expect(rows(controller.matches.value), <String>['Child thing']);
    });
  });

  group('ordering', () {
    test('an empty query sorts by priority, descending and stably', () {
      build(<KBarAction>[
        const KBarAction(id: 'n1', name: 'Normal one'),
        const KBarAction(id: 'l', name: 'Low', priority: KBarPriority.low),
        const KBarAction(id: 'h', name: 'High', priority: KBarPriority.high),
        const KBarAction(id: 'n2', name: 'Normal two'),
      ]);
      expect(rows(controller.matches.value), <String>[
        'High',
        // Equal priorities keep registration order — Dart's sort is unstable,
        // so this would break without an explicit tiebreak.
        'Normal one',
        'Normal two',
        'Low',
      ]);
    });

    test('within a section, action priority is added to the match score', () {
      build(<KBarAction>[
        const KBarAction(id: 'a', name: 'Save'),
        const KBarAction(id: 'b', name: 'Save', priority: KBarPriority.high),
      ]).setSearch('save');
      expect(
        controller.matches.value.actionResults.first.action.id,
        'b',
        reason: 'the higher-priority action wins a score tie',
      );
    });
  });

  group('sections', () {
    test('actions without a section render no heading', () {
      build(<KBarAction>[
        const KBarAction(id: 'a', name: 'Alpha'),
        const KBarAction(id: 'b', name: 'Beta', section: KBarSection.none),
      ]);
      expect(rows(controller.matches.value), <String>['Alpha', 'Beta']);
    });

    test('a heading is emitted once per section, in first-seen order', () {
      build(<KBarAction>[
        const KBarAction(id: 'a', name: 'Alpha', section: KBarSection('File')),
        const KBarAction(id: 'b', name: 'Beta', section: KBarSection('Edit')),
        const KBarAction(id: 'c', name: 'Gamma', section: KBarSection('File')),
      ]);
      expect(rows(controller.matches.value), <String>[
        '# File',
        'Alpha',
        'Gamma',
        '# Edit',
        'Beta',
      ]);
    });

    test('an empty section name still emits a heading', () {
      // Matches kbar, where `section: ""` produces a real (blank) group.
      build(<KBarAction>[
        const KBarAction(id: 'a', name: 'Alpha', section: KBarSection('')),
      ]);
      expect(rows(controller.matches.value), <String>['# ', 'Alpha']);
    });

    test('an explicit section priority orders sections', () {
      build(<KBarAction>[
        const KBarAction(
          id: 'a',
          name: 'Alpha',
          section: KBarSection('Later', priority: KBarPriority.low),
        ),
        const KBarAction(
          id: 'b',
          name: 'Beta',
          section: KBarSection('Sooner', priority: KBarPriority.high),
        ),
      ]);
      expect(rows(controller.matches.value), <String>[
        '# Sooner',
        'Beta',
        '# Later',
        'Alpha',
      ]);
    });

    test('section priority comes from the first matching member only', () {
      // "Zeta" scores best and is seen first, so Group takes its score even
      // though weaker members follow.
      build(<KBarAction>[
        const KBarAction(id: 'a', name: 'Zeta', section: KBarSection('Group')),
        const KBarAction(
          id: 'b',
          name: 'Zzzzzeta',
          section: KBarSection('Group'),
        ),
        const KBarAction(
          id: 'c',
          name: 'Zeta exact',
          section: KBarSection('Other'),
        ),
      ]).setSearch('zeta');

      final List<String> result = rows(controller.matches.value);
      expect(result.where((String r) => r.startsWith('# ')), <String>[
        '# Group',
        '# Other',
      ]);
    });

    test('the section name is searchable via keywords', () {
      build(<KBarAction>[
        const KBarAction(
          id: 'a',
          name: 'Alpha',
          section: KBarSection('Preferences'),
        ),
        const KBarAction(id: 'b', name: 'Beta'),
      ]).setSearch('preferences');
      expect(controller.matches.value.actionResults.single.action.id, 'a');
    });
  });

  group('throttle', () {
    test('runs immediately, then coalesces rapid typing', () {
      fakeAsync((FakeAsync async) {
        controller = KBarController(
          actions: <KBarAction>[
            const KBarAction(id: 'a', name: 'Alpha'),
            const KBarAction(id: 'b', name: 'Beta'),
          ],
        );

        int runs = 0;
        controller.matches.addListener(() => runs++);

        controller.setSearch('a');
        expect(runs, 1, reason: 'the first keystroke is not delayed');
        expect(controller.matches.value.query, 'a');

        controller
          ..setSearch('al')
          ..setSearch('alp')
          ..setSearch('alph');
        expect(runs, 1, reason: 'keystrokes inside the window are coalesced');
        expect(controller.matches.value.query, 'a');

        async.elapse(const Duration(milliseconds: 100));
        expect(runs, 2, reason: 'the trailing edge runs once with the latest');
        expect(controller.matches.value.query, 'alph');

        async.elapse(const Duration(milliseconds: 200));
        expect(runs, 2, reason: 'an idle window schedules nothing further');
      });
    });

    test('action registration is never throttled', () {
      fakeAsync((FakeAsync async) {
        controller = KBarController();
        controller.setSearch('a');

        controller.registerActions(<KBarAction>[
          const KBarAction(id: 'a', name: 'Alpha'),
        ]);
        expect(
          controller.matches.value.actionResults.length,
          1,
          reason: 'a structural change applies at once',
        );
        async.elapse(const Duration(milliseconds: 200));
      });
    });
  });

  group('active index', () {
    test('lands past a leading heading', () {
      build(<KBarAction>[
        const KBarAction(id: 'a', name: 'Alpha', section: KBarSection('File')),
      ]);
      expect(controller.state.activeIndex, 1);
      expect(controller.activeAction!.id, 'a');
    });

    test('moves by one, skipping headings', () {
      build(<KBarAction>[
        const KBarAction(id: 'a', name: 'Alpha', section: KBarSection('File')),
        const KBarAction(id: 'b', name: 'Beta', section: KBarSection('Edit')),
      ]);
      // # File / Alpha / # Edit / Beta
      expect(controller.state.activeIndex, 1);

      controller.moveActiveIndex(1);
      expect(controller.state.activeIndex, 3, reason: 'skips the Edit heading');

      controller.moveActiveIndex(-1);
      expect(controller.state.activeIndex, 1);
    });

    test('clamps at both ends without wrapping', () {
      build(<KBarAction>[
        const KBarAction(id: 'a', name: 'Alpha'),
        const KBarAction(id: 'b', name: 'Beta'),
      ]);
      controller.moveActiveIndex(-1);
      expect(controller.state.activeIndex, 0);

      controller
        ..moveActiveIndex(1)
        ..moveActiveIndex(1);
      expect(controller.state.activeIndex, 1);
    });

    test('resets when the query changes', () {
      build(<KBarAction>[
        const KBarAction(id: 'a', name: 'Alpha thing'),
        const KBarAction(id: 'b', name: 'Beta thing'),
      ]);
      controller.moveActiveIndex(1);
      expect(controller.state.activeIndex, 1);

      controller.setSearch('thing');
      expect(controller.state.activeIndex, 0);
    });

    test('clamps when the result list shrinks', () {
      build(<KBarAction>[
        const KBarAction(id: 'a', name: 'Alpha'),
        const KBarAction(id: 'b', name: 'Beta'),
        const KBarAction(id: 'c', name: 'Gamma'),
      ]);
      controller.setActiveIndex(2);

      controller.registerActions(<KBarAction>[]).call();
      final KBarUnregister remove = controller.registerActions(<KBarAction>[
        const KBarAction(id: 'd', name: 'Delta'),
      ]);
      controller.setActiveIndex(3);
      remove();

      expect(controller.state.activeIndex, lessThan(3));
      expect(controller.activeAction, isNotNull);
    });
  });
}
