import 'package:flutter/material.dart';
import 'package:flutter_kbar/flutter_kbar.dart';
import 'package:flutter_test/flutter_test.dart';

/// Focus handling around opening and closing the palette.
void main() {
  late KBarController controller;

  /// The focus node of the [TextField] identified by [key].
  FocusNode fieldFocus(WidgetTester tester, Key key) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(EditableText),
        ),
      )
      .focusNode;

  Future<void> pumpApp(
    WidgetTester tester, {
    List<KBarAction> actions = const <KBarAction>[],
  }) async {
    await tester.pumpWidget(
      KBarProvider(
        actions: actions,
        options: const KBarOptions(
          animations: KBarAnimations.none,
          searchThrottle: Duration.zero,
        ),
        child: MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              KBarPalette(child: child),
          home: Builder(
            builder: (BuildContext context) {
              controller = KBarController.of(context);
              return const Scaffold(
                body: Center(child: TextField(key: Key('page-field'))),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('focus returns to whatever held it before opening', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('page-field')));
    await tester.pumpAndSettle();
    final FocusNode pageFocus = fieldFocus(tester, const Key('page-field'));
    expect(pageFocus.hasFocus, isTrue);

    controller.open();
    await tester.pumpAndSettle();
    expect(
      pageFocus.hasFocus,
      isFalse,
      reason: 'the palette takes focus while open',
    );

    controller.close();
    await tester.pumpAndSettle();
    expect(pageFocus.hasFocus, isTrue);
  });

  testWidgets('focus is left alone when an action claims it while closing', (
    WidgetTester tester,
  ) async {
    // The regression this guards: `perform` runs as the palette closes. If it
    // opens a dialog, restoring focus afterwards would steal it back.
    await pumpApp(
      tester,
      actions: <KBarAction>[
        KBarAction(
          id: 'dialog',
          name: 'Open a dialog',
          perform: (KBarActionContext _) async {
            await showDialog<void>(
              context: tester.element(find.byType(Scaffold)),
              builder: (BuildContext context) => const AlertDialog(
                content: TextField(key: Key('dialog-field'), autofocus: true),
              ),
            );
          },
        ),
      ],
    );

    // Give the page field focus first, so there is a real restore target.
    await tester.tap(find.byKey(const Key('page-field')));
    await tester.pumpAndSettle();
    final FocusNode pageFocus = fieldFocus(tester, const Key('page-field'));
    expect(pageFocus.hasFocus, isTrue);

    controller.open();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open a dialog'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-field')), findsOneWidget);
    expect(
      pageFocus.hasFocus,
      isFalse,
      reason: 'the palette must not pull focus back out of the dialog',
    );

    final EditableText dialogField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('dialog-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(dialogField.focusNode.hasFocus, isTrue);
  });

  testWidgets('restoreFocusOnClose false still closes cleanly', (
    WidgetTester tester,
  ) async {
    // Note what this does *not* assert. Flutter returns focus to the enclosing
    // scope's most recent node when a child scope is removed, so the page field
    // regains focus either way. The option only controls whether the palette
    // asks for that explicitly.
    await tester.pumpWidget(
      KBarProvider(
        options: const KBarOptions(
          animations: KBarAnimations.none,
          searchThrottle: Duration.zero,
          restoreFocusOnClose: false,
        ),
        child: MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              KBarPalette(child: child),
          home: Builder(
            builder: (BuildContext context) {
              controller = KBarController.of(context);
              return const Scaffold(
                body: Center(child: TextField(key: Key('page-field'))),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('page-field')));
    await tester.pumpAndSettle();
    final FocusNode pageFocus = fieldFocus(tester, const Key('page-field'));

    controller.open();
    await tester.pumpAndSettle();
    expect(pageFocus.hasFocus, isFalse);

    controller.close();
    await tester.pumpAndSettle();

    expect(controller.isOpen, isFalse);
    expect(find.byKey(const Key('page-field')), findsOneWidget);
  });
}
