import 'package:flutter/widgets.dart';
import 'package:flutter_kbar/flutter_kbar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late KBarController controller;

  setUp(() {
    controller = KBarController(
      actions: <KBarAction>[
        const KBarAction(id: 'a', name: 'Alpha'),
        const KBarAction(id: 'b', name: 'Beta'),
      ],
    );
  });

  tearDown(() => controller.dispose());

  Future<void> pumpSelector<T>(
    WidgetTester tester, {
    required T Function(KBarState) selector,
    required VoidCallback onBuild,
  }) {
    return tester.pumpWidget(
      KBarProvider(
        controller: controller,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: KBarSelector<T>(
            selector: selector,
            builder: (BuildContext context, T value, KBarController kbar, _) {
              onBuild();
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  testWidgets('does not rebuild when an unrelated slice changes', (
    WidgetTester tester,
  ) async {
    int builds = 0;
    await pumpSelector<String>(
      tester,
      selector: (KBarState s) => s.searchQuery,
      onBuild: () => builds++,
    );
    expect(builds, 1);

    controller.setActiveIndex(4);
    await tester.pump();
    expect(builds, 1, reason: 'activeIndex is not part of the slice');

    controller.disable(true);
    await tester.pump();
    expect(builds, 1, reason: 'disabled is not part of the slice');

    controller.setSearch('hello');
    await tester.pump();
    expect(builds, 2);

    // Let the match engine's throttle window close so no timer outlives the
    // test.
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('does not rebuild when the slice is set to an equal value', (
    WidgetTester tester,
  ) async {
    int builds = 0;
    await pumpSelector<int>(
      tester,
      selector: (KBarState s) => s.activeIndex,
      onBuild: () => builds++,
    );
    expect(builds, 1);

    controller.setActiveIndex(3);
    await tester.pump();
    expect(builds, 2);

    controller.setActiveIndex(3);
    await tester.pump();
    expect(builds, 2);
  });

  testWidgets('a collection slice compares deeply, not by identity', (
    WidgetTester tester,
  ) async {
    int builds = 0;
    await pumpSelector<List<String>>(
      tester,
      // A fresh list on every call — identity always differs.
      selector: (KBarState s) =>
          s.actions.roots.map((KBarActionNode n) => n.name).toList(),
      onBuild: () => builds++,
    );
    expect(builds, 1);

    controller.setSearch('irrelevant');
    await tester.pump(const Duration(milliseconds: 100));
    expect(builds, 1, reason: 'a new list with equal contents is not a change');

    controller.registerActions(<KBarAction>[
      const KBarAction(id: 'c', name: 'Gamma'),
    ]);
    await tester.pump();
    expect(builds, 2);
  });

  testWidgets('KBarBuilder rebuilds on any change', (
    WidgetTester tester,
  ) async {
    int builds = 0;
    await tester.pumpWidget(
      KBarProvider(
        controller: controller,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: KBarBuilder(
            builder: (BuildContext _, KBarState _, KBarController _, _) {
              builds++;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(builds, 1);

    controller.setActiveIndex(1);
    await tester.pump();
    expect(builds, 2);
  });

  testWidgets('stops listening once disposed', (WidgetTester tester) async {
    int builds = 0;
    await pumpSelector<int>(
      tester,
      selector: (KBarState s) => s.activeIndex,
      onBuild: () => builds++,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    controller.setActiveIndex(9);
    await tester.pump();

    expect(builds, 1);
  });

  testWidgets('KBarController.of throws a helpful error with no provider', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      Builder(
        builder: (BuildContext context) {
          expect(KBarController.maybeOf(context), isNull);
          expect(
            () => KBarController.of(context),
            throwsA(
              isA<FlutterError>().having(
                (FlutterError e) => e.message,
                'message',
                contains('No KBarProvider found'),
              ),
            ),
          );
          return const SizedBox.shrink();
        },
      ),
    );
  });
}
