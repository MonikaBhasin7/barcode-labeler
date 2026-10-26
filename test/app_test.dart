import 'package:barcode_labeler/app/barcode_labeler_app.dart';
import 'package:barcode_labeler/core/settings/app_settings_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.put(AppSettingsStore(await SharedPreferences.getInstance()));
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
    expect(find.text('Untitled •'), findsOneWidget);
  });
}
