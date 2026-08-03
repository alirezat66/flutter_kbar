import 'package:flutter/material.dart';
import 'package:flutter_kbar_example/main.dart';
import 'package:flutter_kbar_example/setup_guide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('guide presents copyable setup steps in order', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Setup guide'));
    await tester.pumpAndSettle();

    expect(find.byType(SetupGuidePage), findsOneWidget);
    expect(find.text('Add flutter_kbar in five steps.'), findsOneWidget);
    expect(find.text('Add the package'), findsOneWidget);
    expect(find.text('Define your commands'), findsOneWidget);
    expect(find.text('Wrap your app'), findsOneWidget);
    expect(find.text('Open the palette'), findsOneWidget);
    expect(find.text('Register page commands'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Copy'), findsNWidgets(5));
  });
}
