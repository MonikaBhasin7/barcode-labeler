import 'package:barcode_labeler/app/barcode_labeler_app.dart';
import 'package:barcode_labeler/core/fonts/installed_fonts.dart';
import 'package:barcode_labeler/core/settings/app_settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.put(AppSettingsStore(await SharedPreferences.getInstance()));
    Get.put(InstalledFonts(folders: const []));
  });

  tearDown(Get.reset);

  testWidgets('opens on the home screen', (tester) async {
    await tester.pumpWidget(const BarcodeLabelerApp());

    expect(find.text('Barcode Labeler'), findsOneWidget);
    expect(find.text('New design'), findsOneWidget);
    expect(
      find.text('No designs yet. Start with "New design".'),
      findsOneWidget,
    );
  });

  testWidgets('a new design opens the designer with an empty A4 label', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const BarcodeLabelerApp());

    await tester.tap(find.text('New design'));
    await tester.pumpAndSettle();

    expect(find.text('Sheet setup'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Untitled'), findsOneWidget);
    expect(find.text('Size: 210 × 297 mm'), findsOneWidget);
  });

  testWidgets('adding a barcode selects it and shows its settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const BarcodeLabelerApp());
    await tester.tap(find.text('New design'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Barcode').first);
    await tester.pumpAndSettle();

    expect(find.text('Barcode type'), findsOneWidget);
    expect(find.text('Value comes from'), findsOneWidget);
    expect(find.text('Number font'), findsOneWidget);
    expect(find.text('Number size'), findsOneWidget);
    expect(find.text('Untitled •'), findsOneWidget);
  });

  testWidgets('a text item has a font choice next to its text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const BarcodeLabelerApp());
    await tester.tap(find.text('New design'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Text').first);
    await tester.pumpAndSettle();

    expect(find.text('Font'), findsOneWidget);
    expect(find.text('Roboto'), findsOneWidget);
    expect(find.text('Text size'), findsOneWidget);
  });

  testWidgets('choosing a font from the font list changes the text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const BarcodeLabelerApp());
    await tester.tap(find.text('New design'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Text').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Roboto'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a font'), findsOneWidget);
    expect(find.text('No fonts were found on this PC.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'times');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tinos (like Times New Roman)'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a font'), findsNothing);
    expect(find.text('Tinos (like Times New Roman)'), findsOneWidget);
  });
}
