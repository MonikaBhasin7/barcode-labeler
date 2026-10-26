import 'package:barcode_labeler/core/settings/app_settings_store.dart';
import 'package:barcode_labeler/features/design/data/models/label_design.dart';
import 'package:barcode_labeler/features/design/data/models/label_item.dart';
import 'package:barcode_labeler/features/design/data/models/label_value.dart';
import 'package:barcode_labeler/features/designer/presentation/designer_screen.dart';
import 'package:barcode_labeler/features/designer/presentation/widgets/label_item_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

const LabelDesign boxedLabelDesign = LabelDesign(
  id: 'boxed',
  name: 'Boxed label',
  sheet: SheetLayout(
    paper: PaperSize.custom,
    pageWidthMm: 100,
    pageHeightMm: 50,
    labelWidthMm: 100,
    labelHeightMm: 50,
  ),
  items: [
    TextItem(
      id: 'caption',
      name: 'Caption',
      frame: ItemFrame(x: 60, y: 20, width: 30, height: 10),
      value: LabelValue(fixedText: 'Hello'),
    ),
    ShapeItem(
      id: 'border',
      name: 'Border',
      frame: ItemFrame(x: 0, y: 0, width: 100, height: 50),
    ),
    ShapeItem(
      id: 'inner',
      name: 'Inner box',
      frame: ItemFrame(x: 5, y: 5, width: 40, height: 30),
    ),
  ],
);

Future<void> openDesigner(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(home: DesignerScreen(initialDesign: boxedLabelDesign)),
  );
  await tester.pumpAndSettle();
}

Rect rectOfItem(WidgetTester tester, String itemId) {
  return tester.getRect(
    find.byWidgetPredicate(
      (widget) => widget is LabelItemView && widget.item.id == itemId,
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.put(AppSettingsStore(await SharedPreferences.getInstance()));
  });

  tearDown(Get.reset);

  testWidgets('clicking inside an empty box selects the box', (tester) async {
    await openDesigner(tester);

    await tester.tapAt(rectOfItem(tester, 'inner').center);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Inner box'), findsOneWidget);
  });

  testWidgets('text inside a border box is still easy to select', (
    tester,
  ) async {
    await openDesigner(tester);

    await tester.tapAt(rectOfItem(tester, 'caption').center);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Caption'), findsOneWidget);
  });

  testWidgets('an empty spot inside the border selects the border', (
    tester,
  ) async {
    await openDesigner(tester);
    await tester.tapAt(rectOfItem(tester, 'inner').center);
    await tester.pumpAndSettle();

    await tester.tapAt(
      rectOfItem(tester, 'border').bottomRight - const Offset(5, 5),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Border'), findsOneWidget);
  });
}
