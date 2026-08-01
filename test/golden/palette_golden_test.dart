@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_kbar/flutter_kbar.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layout and colour regression coverage for the bundled palette.
///
/// Run with `flutter test --tags golden`, and update with
/// `flutter test --tags golden --update-goldens`. Excluded from the default run
/// because font rasterisation differs between platforms; generate them on one
/// platform only.
void main() {
  late KBarController controller;

  List<KBarAction> actions() => <KBarAction>[
    KBarAction(
      id: 'save',
      name: 'Save file',
      subtitle: 'Write the current file to disk',
      icon: const Icon(Icons.save_outlined),
      section: const KBarSection('File'),
      shortcut: const <String>[r'$mod+s'],
      perform: (_) {},
    ),
    KBarAction(
      id: 'open',
      name: 'Open file',
      icon: const Icon(Icons.folder_open_outlined),
      section: const KBarSection('File'),
      shortcut: const <String>['g', 'o'],
      perform: (_) {},
    ),
    const KBarAction(
      id: 'theme',
      name: 'Change theme',
      subtitle: 'Light, dark, or system',
      icon: Icon(Icons.brightness_6_outlined),
      section: KBarSection('Preferences'),
    ),
    KBarAction(
      id: 'theme.dark',
      name: 'Dark',
      parent: 'theme',
      icon: const Icon(Icons.dark_mode_outlined),
      perform: (_) {},
    ),
    KBarAction(
      id: 'theme.light',
      name: 'Light',
      parent: 'theme',
      icon: const Icon(Icons.light_mode_outlined),
      perform: (_) {},
    ),
  ];

  Future<void> pumpPalette(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      KBarProvider(
        actions: actions(),
        options: const KBarOptions(
          animations: KBarAnimations.none,
          searchThrottle: Duration.zero,
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: brightness,
            colorSchemeSeed: const Color(0xFF6C8CFF),
          ),
          builder: (BuildContext context, Widget? child) =>
              KBarPalette(child: child),
          home: Builder(
            builder: (BuildContext context) {
              controller = KBarController.of(context);
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.open();
    await tester.pumpAndSettle();
  }

  testWidgets('light', (WidgetTester tester) async {
    await pumpPalette(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/palette_light.png'),
    );
  });

  testWidgets('dark', (WidgetTester tester) async {
    await pumpPalette(tester, brightness: Brightness.dark);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/palette_dark.png'),
    );
  });

  testWidgets('filtered with highlighting', (WidgetTester tester) async {
    await pumpPalette(tester);
    await tester.enterText(find.byType(TextField), 'file');
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/palette_filtered.png'),
    );
  });

  testWidgets('empty state', (WidgetTester tester) async {
    await pumpPalette(tester);
    await tester.enterText(find.byType(TextField), 'zzzzzz');
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/palette_empty.png'),
    );
  });

  testWidgets('nested with breadcrumbs', (WidgetTester tester) async {
    await pumpPalette(tester);
    controller.setCurrentRootAction('theme');
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/palette_nested.png'),
    );
  });
}
