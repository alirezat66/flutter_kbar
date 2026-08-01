import 'package:flutter_kbar/flutter_kbar.dart';
import 'package:flutter_test/flutter_test.dart';

KBarAction action(String id, {String? parent, String? name}) =>
    KBarAction(id: id, name: name ?? id, parent: parent);

void main() {
  group('add', () {
    test('registers a top-level action', () {
      final KBarActionRegistry registry = KBarActionRegistry.empty.add(
        action('a'),
      );
      expect(registry.length, 1);
      expect(registry['a']!.name, 'a');
      expect(registry.roots.map((KBarActionNode n) => n.id), <String>['a']);
    });

    test('throws when the parent is not already registered', () {
      expect(
        () => KBarActionRegistry.empty.add(action('child', parent: 'missing')),
        throwsA(
          isA<KBarUnknownParentError>()
              .having(
                (KBarUnknownParentError e) => e.actionId,
                'actionId',
                'child',
              )
              .having(
                (KBarUnknownParentError e) => e.parentId,
                'parentId',
                'missing',
              ),
        ),
      );
    });

    test('replacing an action keeps its existing children wired', () {
      // kbar orphans the children here; the full-rebuild approach does not.
      final KBarActionRegistry registry = KBarActionRegistry.of(<KBarAction>[
        action('parent'),
        action('child', parent: 'parent'),
      ]).add(action('parent', name: 'renamed'));

      expect(registry['parent']!.name, 'renamed');
      expect(
        registry['parent']!.children.map((KBarActionNode n) => n.id),
        <String>['child'],
      );
    });

    test('does not mutate the receiver', () {
      const KBarActionRegistry empty = KBarActionRegistry.empty;
      empty.add(action('a'));
      expect(empty.isEmpty, isTrue);
    });

    test('bumps the revision', () {
      final KBarActionRegistry one = KBarActionRegistry.empty.add(action('a'));
      expect(one.revision, greaterThan(KBarActionRegistry.empty.revision));
    });
  });

  group('addAll', () {
    test('accepts a child listed before its parent in the same batch', () {
      final KBarActionRegistry registry = KBarActionRegistry.of(<KBarAction>[
        action('child', parent: 'parent'),
        action('parent'),
      ]);
      expect(registry['parent']!.children.single.id, 'child');
    });

    test('throws when a parent is neither registered nor in the batch', () {
      expect(
        () => KBarActionRegistry.of(<KBarAction>[action('a', parent: 'nope')]),
        throwsA(isA<KBarUnknownParentError>()),
      );
    });

    test('returns the same instance for an empty batch', () {
      const KBarActionRegistry empty = KBarActionRegistry.empty;
      expect(identical(empty.addAll(const <KBarAction>[]), empty), isTrue);
    });
  });

  group('remove', () {
    test('cascades through three levels of descendants', () {
      final KBarActionRegistry registry = KBarActionRegistry.of(<KBarAction>[
        action('root'),
        action('a', parent: 'root'),
        action('b', parent: 'a'),
        action('c', parent: 'b'),
        action('unrelated'),
      ]);
      expect(registry.length, 5);

      final KBarActionRegistry pruned = registry.remove('a');
      expect(pruned.length, 2);
      expect(pruned.contains('root'), isTrue);
      expect(pruned.contains('unrelated'), isTrue);
      for (final String id in <String>['a', 'b', 'c']) {
        expect(pruned.contains(id), isFalse, reason: '$id should be removed');
      }
      expect(pruned['root']!.children, isEmpty);
    });

    test('removing an unknown id is a no-op that preserves identity', () {
      final KBarActionRegistry registry = KBarActionRegistry.of(<KBarAction>[
        action('a'),
      ]);
      expect(identical(registry.remove('nope'), registry), isTrue);
    });
  });

  group('ancestors', () {
    test('are ordered root first and exclude self', () {
      final KBarActionRegistry registry = KBarActionRegistry.of(<KBarAction>[
        action('root'),
        action('mid', parent: 'root'),
        action('leaf', parent: 'mid'),
      ]);
      expect(
        registry['leaf']!.ancestors.map((KBarActionNode n) => n.id),
        <String>['root', 'mid'],
      );
      expect(registry['root']!.ancestors, isEmpty);
    });

    test('parent resolves to the direct parent', () {
      final KBarActionRegistry registry = KBarActionRegistry.of(<KBarAction>[
        action('root'),
        action('leaf', parent: 'root'),
      ]);
      expect(registry['leaf']!.parent!.id, 'root');
      expect(registry['root']!.parent, isNull);
    });
  });

  group('searchKeywords', () {
    test('appends the section name so sections are searchable', () {
      final KBarActionRegistry registry = KBarActionRegistry.empty.add(
        const KBarAction(
          id: 'a',
          name: 'Toggle theme',
          keywords: 'dark, light',
          section: KBarSection('Preferences'),
        ),
      );
      expect(registry['a']!.searchKeywords, <String>[
        'dark',
        'light',
        'Preferences',
      ]);
    });

    test('omits the sentinel section', () {
      final KBarActionRegistry registry = KBarActionRegistry.empty.add(
        const KBarAction(id: 'a', name: 'A', section: KBarSection.none),
      );
      expect(registry['a']!.searchKeywords, isEmpty);
    });

    test('drops empty terms', () {
      final KBarActionRegistry registry = KBarActionRegistry.empty.add(
        const KBarAction(id: 'a', name: 'A', keywords: 'x, , ,y'),
      );
      expect(registry['a']!.searchKeywords, <String>['x', 'y']);
    });
  });

  group('isNavigational', () {
    test('is true for a childful action with no perform', () {
      final KBarActionRegistry registry = KBarActionRegistry.of(<KBarAction>[
        action('parent'),
        action('child', parent: 'parent'),
      ]);
      expect(registry['parent']!.isNavigational, isTrue);
      expect(registry['child']!.isNavigational, isFalse);
    });

    test('is false when the action can perform', () {
      final KBarActionRegistry registry = KBarActionRegistry.of(<KBarAction>[
        KBarAction(id: 'parent', name: 'P', perform: (_) {}),
        action('child', parent: 'parent'),
      ]);
      expect(registry['parent']!.isNavigational, isFalse);
    });
  });

  group('equality', () {
    test('terminates on the parent/child cycle and ignores revision', () {
      final KBarActionRegistry a = KBarActionRegistry.of(<KBarAction>[
        action('root'),
        action('leaf', parent: 'root'),
      ]);
      final KBarActionRegistry b = KBarActionRegistry.empty
          .add(action('root'))
          .add(action('leaf', parent: 'root'));

      expect(a.revision, isNot(b.revision));
      expect(a, b);
      expect(a['root'], b['root']);
    });

    test('differs when a child is added', () {
      final KBarActionRegistry a = KBarActionRegistry.of(<KBarAction>[
        action('root'),
      ]);
      final KBarActionRegistry b = a.add(action('leaf', parent: 'root'));
      expect(a, isNot(b));
      expect(a['root'], isNot(b['root']));
    });

    test('ignores perform so rebuilt closures do not look like a change', () {
      final KBarActionRegistry a = KBarActionRegistry.empty.add(
        KBarAction(id: 'x', name: 'X', perform: (_) {}),
      );
      final KBarActionRegistry b = KBarActionRegistry.empty.add(
        KBarAction(id: 'x', name: 'X', perform: (_) {}),
      );
      expect(a, b);
    });
  });
}
