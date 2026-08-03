import 'package:flutter/material.dart';
import 'package:flutter_kbar_example/headless_example.dart';
import 'package:flutter_kbar_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('page drives the live primitive-built palette', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Headless example'));
    await tester.pumpAndSettle();
    expect(find.byType(HeadlessExamplePage), findsOneWidget);

    await tester.tap(find.text('Open custom palette'));
    await tester.pumpAndSettle();

    expect(find.text('HEADLESS'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'confetti');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Throw confetti'));
    await tester.pumpAndSettle();

    expect(find.text('🎉  Run 1'), findsOneWidget);
  });
}
