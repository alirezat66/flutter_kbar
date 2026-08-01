import 'package:fake_async/fake_async.dart';
import 'package:flutter_kbar/flutter_kbar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KBarController controller;

  tearDown(() => controller.dispose());

  group('visibility', () {
    test('toggle runs the full open then close lifecycle', () {
      fakeAsync((FakeAsync async) {
        controller = KBarController();
        expect(controller.state.visualState, KBarVisualState.hidden);

        controller.toggle();
        expect(controller.state.visualState, KBarVisualState.animatingIn);

        async.elapse(const Duration(milliseconds: 200));
        expect(controller.state.visualState, KBarVisualState.showing);

        controller.toggle();
        expect(controller.state.visualState, KBarVisualState.animatingOut);

        async.elapse(const Duration(milliseconds: 100));
        expect(controller.state.visualState, KBarVisualState.hidden);
      });
    });

    test('closing resets the query and the nested action', () {
      fakeAsync((FakeAsync async) {
        controller = KBarController(
          actions: <KBarAction>[
            const KBarAction(id: 'parent', name: 'Parent'),
            const KBarAction(id: 'child', name: 'Child', parent: 'parent'),
          ],
        );
        controller
          ..open()
          ..setCurrentRootAction('parent')
          ..setSearch('hello');
        async.elapse(const Duration(seconds: 1));

        expect(controller.state.currentRootActionId, 'parent');
        expect(controller.state.searchQuery, 'hello');

        controller.close();
        async.elapse(const Duration(seconds: 1));

        expect(controller.state.visualState, KBarVisualState.hidden);
        expect(controller.state.currentRootActionId, isNull);
        expect(controller.state.searchQuery, isEmpty);
        expect(controller.searchController.text, isEmpty);
      });
    });

    test('resetOnClose false keeps the query for the next open', () {
      fakeAsync((FakeAsync async) {
        controller = KBarController(
          options: const KBarOptions(resetOnClose: false),
        )..open();
        async.elapse(const Duration(seconds: 1));
        controller
          ..setSearch('keep me')
          ..close();
        async.elapse(const Duration(seconds: 1));

        expect(controller.state.searchQuery, 'keep me');
      });
    });

    test('an interrupted exit re-opens without waiting for it to finish', () {
      fakeAsync((FakeAsync async) {
        controller = KBarController()..open();
        async.elapse(const Duration(milliseconds: 200));
        controller.close();
        async.elapse(const Duration(milliseconds: 40));
        expect(controller.state.visualState, KBarVisualState.animatingOut);

        controller.open();
        expect(controller.state.visualState, KBarVisualState.animatingIn);

        // The cancelled exit timer must not fire and hide the palette.
        async.elapse(const Duration(milliseconds: 200));
        expect(controller.state.visualState, KBarVisualState.showing);
      });
    });

    test('disable closes immediately and blocks reopening', () {
      fakeAsync((FakeAsync async) {
        controller = KBarController()..open();
        async.elapse(const Duration(seconds: 1));
        expect(controller.isOpen, isTrue);

        controller.disable(true);
        expect(controller.state.visualState, KBarVisualState.hidden);

        controller.open();
        expect(controller.state.visualState, KBarVisualState.hidden);

        controller.disable(false);
        controller.open();
        expect(controller.state.visualState, KBarVisualState.animatingIn);
      });
    });
  });

  group('search', () {
    test('setSearch updates the visible field but not onQueryChange', () {
      final List<String> changes = <String>[];
      controller = KBarController(
        options: KBarOptions(
          callbacks: KBarCallbacks(onQueryChange: changes.add),
        ),
      )..setSearch('programmatic');

      expect(controller.state.searchQuery, 'programmatic');
      expect(controller.searchController.text, 'programmatic');
      expect(
        changes,
        isEmpty,
        reason: 'onQueryChange reports user typing only',
      );
    });

    test('typing updates state and fires onQueryChange exactly once', () {
      final List<String> changes = <String>[];
      controller = KBarController(
        options: KBarOptions(
          callbacks: KBarCallbacks(onQueryChange: changes.add),
        ),
      );

      controller.searchController.text = 'typed';

      expect(controller.state.searchQuery, 'typed');
      expect(changes, <String>['typed']);
    });

    test('setSearch does not feed back into onQueryChange', () {
      final List<String> changes = <String>[];
      controller = KBarController(
        options: KBarOptions(
          callbacks: KBarCallbacks(onQueryChange: changes.add),
        ),
      );

      controller.searchController.text = 'a';
      controller.setSearch('b');
      controller.searchController.text = 'c';

      expect(changes, <String>['a', 'c']);
      expect(controller.state.searchQuery, 'c');
    });
  });

  group('navigation', () {
    setUp(() {
      controller = KBarController(
        actions: <KBarAction>[
          const KBarAction(id: 'root', name: 'Root'),
          const KBarAction(id: 'mid', name: 'Mid', parent: 'root'),
          const KBarAction(id: 'leaf', name: 'Leaf', parent: 'mid'),
        ],
      );
    });

    test('entering a nested action clears the query', () {
      controller
        ..setSearch('something')
        ..setCurrentRootAction('root');
      expect(controller.state.searchQuery, isEmpty);
      expect(controller.searchController.text, isEmpty);
      expect(controller.state.currentRootActionId, 'root');
    });

    test('goToParent walks up one level, then to the top', () {
      controller.setCurrentRootAction('mid');
      controller.goToParent();
      expect(controller.state.currentRootActionId, 'root');

      controller.goToParent();
      expect(controller.state.currentRootActionId, isNull);

      controller.goToParent();
      expect(controller.state.currentRootActionId, isNull);
    });

    test('an action without perform descends into its children', () async {
      await controller.performAction(controller.state.actions['root']!);
      expect(controller.state.currentRootActionId, 'root');
      expect(controller.isOpen, isFalse);
    });

    test('an action with perform runs it and closes', () async {
      bool ran = false;
      controller
        ..registerActions(<KBarAction>[
          KBarAction(id: 'go', name: 'Go', perform: (_) => ran = true),
        ])
        ..open();

      await controller.performAction(controller.state.actions['go']!);

      expect(ran, isTrue);
      expect(controller.state.visualState.isClosing, isTrue);
    });

    test('onSelectAction fires for both kinds of action', () async {
      final List<String> selected = <String>[];
      controller
        ..options = KBarOptions(
          callbacks: KBarCallbacks(
            onSelectAction: (KBarActionNode a) => selected.add(a.id),
          ),
        )
        ..registerActions(<KBarAction>[
          KBarAction(id: 'go', name: 'Go', perform: (_) {}),
        ]);

      await controller.performAction(controller.state.actions['root']!);
      await controller.performAction(controller.state.actions['go']!);

      expect(selected, <String>['root', 'go']);
    });

    test('an async perform is awaited', () async {
      bool finished = false;
      controller.registerActions(<KBarAction>[
        KBarAction(
          id: 'slow',
          name: 'Slow',
          perform: (_) async {
            await Future<void>.delayed(Duration.zero);
            finished = true;
          },
        ),
      ]);

      await controller.performAction(controller.state.actions['slow']!);
      expect(finished, isTrue);
    });
  });

  group('registerActions', () {
    test('adds actions and the disposer removes them', () {
      controller = KBarController();
      final KBarUnregister remove = controller.registerActions(<KBarAction>[
        const KBarAction(id: 'a', name: 'A'),
        const KBarAction(id: 'b', name: 'B', parent: 'a'),
      ]);
      expect(controller.state.actions.length, 2);

      remove();
      expect(controller.state.actions.isEmpty, isTrue);
    });

    test('the disposer is idempotent', () {
      controller = KBarController();
      final KBarUnregister removeFirst = controller.registerActions(
        <KBarAction>[const KBarAction(id: 'a', name: 'A')],
      );
      controller.registerActions(<KBarAction>[
        const KBarAction(id: 'b', name: 'B'),
      ]);

      removeFirst();
      removeFirst();

      expect(controller.state.actions.length, 1);
      expect(controller.state.actions.contains('b'), isTrue);
    });

    test('removing a parent cascades to children registered separately', () {
      controller = KBarController();
      final KBarUnregister removeParent = controller.registerActions(
        <KBarAction>[const KBarAction(id: 'p', name: 'P')],
      );
      controller.registerActions(<KBarAction>[
        const KBarAction(id: 'c', name: 'C', parent: 'p'),
      ]);
      expect(controller.state.actions.length, 2);

      removeParent();
      expect(controller.state.actions.isEmpty, isTrue);
    });
  });

  group('options', () {
    test('are live, unlike kbar which freezes them', () {
      controller = KBarController();
      expect(controller.options.enableHistory, isFalse);
      controller.options = const KBarOptions(enableHistory: true);
      expect(controller.options.enableHistory, isTrue);
    });

    test('a new animation duration applies to the next transition', () {
      fakeAsync((FakeAsync async) {
        controller = KBarController()
          ..options = const KBarOptions(animations: KBarAnimations.none)
          ..open();
        async.elapse(Duration.zero);
        expect(controller.state.visualState, KBarVisualState.showing);
      });
    });
  });
}
