import 'package:barcode_labeler/features/printing/presentation/widgets/row_picker_dialog.dart';
import 'package:barcode_labeler/features/spreadsheet/data/models/spreadsheet_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final SpreadsheetTable codesTable = SpreadsheetTable(
  headers: const ['Code'],
  rows: [
    for (var i = 1; i <= 30; i++) {'Code': 'C$i'},
  ],
  excelRowNumbers: [for (var i = 1; i <= 30; i++) i + 1],
);

Future<List<int>?> openPicker(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  List<int>? picked;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            picked = await showRowPickerDialog(
              context,
              table: codesTable,
              initiallyPicked: const [3],
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return picked;
}

bool isTicked(WidgetTester tester, String code) {
  final row = find.ancestor(of: find.text(code), matching: find.byType(Row));
  final checkbox = tester.widget<Checkbox>(
    find.descendant(of: row.first, matching: find.byType(Checkbox)),
  );
  return checkbox.value ?? false;
}

void main() {
  testWidgets('rows already picked start ticked', (tester) async {
    await openPicker(tester);

    expect(isTicked(tester, 'C2'), isTrue);
    expect(isTicked(tester, 'C3'), isFalse);
    expect(find.text('1 of 30 rows picked'), findsOneWidget);
  });

  testWidgets('clicking a row ticks it and shows the tick', (tester) async {
    await openPicker(tester);

    await tester.tap(find.text('C5'));
    await tester.pumpAndSettle();

    expect(isTicked(tester, 'C5'), isTrue);
    expect(find.text('2 of 30 rows picked'), findsOneWidget);
  });

  testWidgets('tick all and untick all', (tester) async {
    await openPicker(tester);

    await tester.tap(find.text('Tick all'));
    await tester.pumpAndSettle();
    expect(find.text('30 of 30 rows picked'), findsOneWidget);
    expect(isTicked(tester, 'C7'), isTrue);

    await tester.tap(find.text('Untick all'));
    await tester.pumpAndSettle();
    expect(isTicked(tester, 'C7'), isFalse);
    expect(find.text('Use 0 rows'), findsOneWidget);
  });
}
