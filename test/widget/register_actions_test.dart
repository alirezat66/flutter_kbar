import 'package:flutter/widgets.dart';
import 'package:flutter_kbar/flutter_kbar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late KBarController controller;

  setUp(() => controller = KBarController());
  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    KBarProvider(
      controller: controller,
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    ),
  );

  testWidgets('registers on mount and unregisters on unmount', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      KBarRegisterActions(
        actions: <KBarAction>[const KBarAction(id: 'page', name: 'Page')],
        child: const SizedBox.shrink(),
      ),
    );
    expect(controller.state.actions.contains('page'), isTrue);

    await pump(tester, const SizedBox.shrink());
    expect(controller.state.actions.contains('page'), isFalse);
  });

  testWidgets('a changed definition re-registers', (WidgetTester tester) async {
    await pump(
      tester,
      KBarRegisterActions(
        actions: <KBarAction>[const KBarAction(id: 'x', name: 'Before')],
        child: const SizedBox.shrink(),
      ),
    );
    expect(controller.state.actions['x']!.name, 'Before');

    await pump(
      tester,
      KBarRegisterActions(
        actions: <KBarAction>[const KBarAction(id: 'x', name: 'After')],
        child: const SizedBox.shrink(),
      ),
    );
    expect(controller.state.actions['x']!.name, 'After');
  });

  testWidgets('a rebuilt perform closure does not re-register', (
    WidgetTester tester,
  ) async {
    int registrations = 0;
    controller.addListener(() => registrations++);

    for (int i = 0; i < 3; i++) {
      await pump(
        tester,
        KBarRegisterActions(
          // A brand-new closure every time, as `build` would produce.
          actions: <KBarAction>[
            KBarAction(id: 'x', name: 'X', perform: (_) {}),
          ],
          child: const SizedBox.shrink(),
        ),
      );
    }

    expect(
      registrations,
      1,
      reason: 'only the initial registration should notify',
    );
  });

  testWidgets('deps drive re-registration when given', (
    WidgetTester tester,
  ) async {
    Future<void> pumpWithDeps(int dep, String name) => pump(
      tester,
      KBarRegisterActions(
        deps: <Object?>[dep],
        actions: <KBarAction>[KBarAction(id: 'x', name: name)],
        child: const SizedBox.shrink(),
      ),
    );

    await pumpWithDeps(1, 'First');
    expect(controller.state.actions['x']!.name, 'First');

    // Same deps: the changed name is deliberately ignored, matching React.
    await pumpWithDeps(1, 'Ignored');
    expect(controller.state.actions['x']!.name, 'First');

    await pumpWithDeps(2, 'Second');
    expect(controller.state.actions['x']!.name, 'Second');
  });

  testWidgets('nested registrations can reference an ancestor parent', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      KBarRegisterActions(
        actions: <KBarAction>[const KBarAction(id: 'p', name: 'Parent')],
        child: KBarRegisterActions(
          actions: <KBarAction>[
            const KBarAction(id: 'c', name: 'Child', parent: 'p'),
          ],
          child: const SizedBox.shrink(),
        ),
      ),
    );

    expect(controller.state.actions['p']!.children.single.id, 'c');
  });

  testWidgets('KBarProvider keeps its own action list in sync', (
    WidgetTester tester,
  ) async {
    Future<void> pumpProvider(List<KBarAction> actions) => tester.pumpWidget(
      KBarProvider(
        controller: controller,
        actions: actions,
        child: const SizedBox.shrink(),
      ),
    );

    await pumpProvider(<KBarAction>[const KBarAction(id: 'a', name: 'A')]);
    expect(controller.state.actions.contains('a'), isTrue);

    await pumpProvider(<KBarAction>[const KBarAction(id: 'b', name: 'B')]);
    expect(controller.state.actions.contains('a'), isFalse);
    expect(controller.state.actions.contains('b'), isTrue);
  });

  testWidgets('the mixin registers and refreshes', (WidgetTester tester) async {
    await pump(tester, const _MixinPage());
    expect(controller.state.actions['counter']!.name, 'Count 0');

    final _MixinPageState state = tester.state<_MixinPageState>(
      find.byType(_MixinPage),
    );
    state.increment();
    await tester.pump();

    expect(controller.state.actions['counter']!.name, 'Count 1');

    await pump(tester, const SizedBox.shrink());
    expect(controller.state.actions.contains('counter'), isFalse);
  });
}

class _MixinPage extends StatefulWidget {
  const _MixinPage();

  @override
  State<_MixinPage> createState() => _MixinPageState();
}

class _MixinPageState extends State<_MixinPage>
    with KBarActionsMixin<_MixinPage> {
  int _count = 0;

  void increment() {
    setState(() => _count++);
    refreshKBarActions();
  }

  @override
  List<KBarAction> buildKBarActions() => <KBarAction>[
    KBarAction(id: 'counter', name: 'Count $_count'),
  ];

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
