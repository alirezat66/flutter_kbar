import 'package:flutter/material.dart';
import 'package:flutter_kbar_example/feedback_dialog.dart';
import 'package:flutter_kbar_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the palette → dialog handoff, which is the interesting part: the
/// palette closes and restores focus on a timer, so the dialog has to end up
/// with focus rather than losing it a moment later.
void main() {
  /// Opens the palette, finds the feedback command, and runs it.
  Future<void> openFeedbackForm(WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Open palette'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'feedback');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send feedback…'));
    await tester.pumpAndSettle();
  }

  testWidgets('a palette command opens the form', (WidgetTester tester) async {
    await openFeedbackForm(tester);

    expect(find.byType(FeedbackDialog), findsOneWidget);
    expect(find.text('Send feedback'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Message'), findsOneWidget);

    // The palette itself is gone.
    expect(find.text('Change theme'), findsNothing);
  });

  testWidgets('the first field keeps focus after the palette closes', (
    WidgetTester tester,
  ) async {
    await openFeedbackForm(tester);

    // The palette restores focus when it finishes closing, which happens after
    // the dialog is already up. Let every timer run out before asserting.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final EditableText nameField = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .first;
    expect(
      nameField.focusNode.hasFocus,
      isTrue,
      reason: 'the palette must not steal focus back from the dialog',
    );
  });

  testWidgets('validates before submitting', (WidgetTester tester) async {
    await openFeedbackForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Message is required'), findsOneWidget);
    expect(find.byType(FeedbackDialog), findsOneWidget);
  });

  testWidgets('rejects a malformed email and a too-short message', (
    WidgetTester tester,
  ) async {
    await openFeedbackForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Ada Lovelace',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'not-an-email',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Message'), 'hi');
    await tester.pumpAndSettle();

    expect(
      find.text('That does not look like an email address'),
      findsOneWidget,
    );
    expect(find.textContaining('at least 10 characters'), findsOneWidget);
  });

  testWidgets('submits and reports back to the activity log', (
    WidgetTester tester,
  ) async {
    await openFeedbackForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Ada Lovelace',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'ada@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Message'),
      'The palette is lovely, but the icons could be larger.',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    // Covers the simulated network round-trip.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackDialog), findsNothing);
    expect(
      find.text('Feedback sent — Bug report from Ada Lovelace'),
      findsOneWidget,
    );
  });

  testWidgets('cancelling records that nothing was sent', (
    WidgetTester tester,
  ) async {
    await openFeedbackForm(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackDialog), findsNothing);
    expect(find.text('Feedback cancelled'), findsOneWidget);
  });
}
