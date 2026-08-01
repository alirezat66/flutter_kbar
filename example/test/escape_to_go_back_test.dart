import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_kbar/flutter_kbar.dart';
import 'package:flutter_kbar_example/feedback_dialog.dart';
import 'package:flutter_kbar_example/headless_example.dart';
import 'package:flutter_kbar_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

/// App-wide Escape handling: close the top thing, or do nothing at the root.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pumpAndSettle();
  }

  Future<void> pressEscape(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }

  testWidgets('does nothing on the home page', (WidgetTester tester) async {
    await pumpApp(tester);
    expect(find.text('flutter_kbar'), findsOneWidget);

    await pressEscape(tester);

    // Still home, nothing popped, no crash.
    expect(find.text('flutter_kbar'), findsOneWidget);
    expect(find.byType(HeadlessExamplePage), findsNothing);
  });

  testWidgets('goes back from a pushed page', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Headless example'));
    await tester.pumpAndSettle();
    expect(find.byType(HeadlessExamplePage), findsOneWidget);

    await pressEscape(tester);

    expect(find.byType(HeadlessExamplePage), findsNothing);
    expect(find.text('flutter_kbar'), findsOneWidget);
  });

  testWidgets('closes a dialog without popping the page under it', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    // Push a page first, so a stray second pop would be visible.
    await tester.tap(find.text('Headless example'));
    await tester.pumpAndSettle();

    final KBarController kbar = KBarController.of(
      tester.element(find.byType(HeadlessExamplePage)),
    );
    kbar.open();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'feedback');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send feedback…'));
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackDialog), findsOneWidget);

    await pressEscape(tester);

    expect(find.byType(FeedbackDialog), findsNothing);
    expect(
      find.byType(HeadlessExamplePage),
      findsOneWidget,
      reason: 'only the dialog should have been popped',
    );
  });

  testWidgets('closes the palette without popping the page under it', (
    WidgetTester tester,
  ) async {
    // The interaction a global key handler would get wrong: Escape while the
    // palette is open must close only the palette.
    await pumpApp(tester);

    await tester.tap(find.text('Headless example'));
    await tester.pumpAndSettle();

    final KBarController kbar = KBarController.of(
      tester.element(find.byType(HeadlessExamplePage)),
    );
    kbar.open();
    await tester.pumpAndSettle();
    expect(find.text('Change theme'), findsOneWidget);

    await pressEscape(tester);

    expect(kbar.isOpen, isFalse);
    expect(find.text('Change theme'), findsNothing);
    expect(
      find.byType(HeadlessExamplePage),
      findsOneWidget,
      reason: 'the page behind the palette must survive',
    );
  });

  testWidgets('a second Escape then goes back from the page', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Headless example'));
    await tester.pumpAndSettle();

    final KBarController kbar = KBarController.of(
      tester.element(find.byType(HeadlessExamplePage)),
    );
    kbar.open();
    await tester.pumpAndSettle();

    await pressEscape(tester);
    expect(find.byType(HeadlessExamplePage), findsOneWidget);

    await pressEscape(tester);
    expect(find.byType(HeadlessExamplePage), findsNothing);
    expect(find.text('flutter_kbar'), findsOneWidget);
  });
}
