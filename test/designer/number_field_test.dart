import 'package:barcode_labeler/features/designer/presentation/widgets/property_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<double>> typeInto(WidgetTester tester, String text) async {
  final reported = <double>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NumberField(
          label: 'Copies',
          value: 1,
          decimals: 0,
          min: 1,
          max: 1000,
          onChanged: reported.add,
        ),
      ),
    ),
  );
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  return reported;
}

void main() {
  testWidgets('a number above the limit is refused with a message', (
    tester,
  ) async {
    final reported = await typeInto(tester, '1500');

    expect(reported, isEmpty);
    expect(find.text('At most 1000'), findsOneWidget);
  });

  testWidgets('a comma is refused instead of being dropped', (tester) async {
    final reported = await typeInto(tester, '2,5');

    expect(reported, isEmpty);
    expect(find.text('Use a dot for decimals, no commas'), findsOneWidget);
  });

  testWidgets('a good number is passed on', (tester) async {
    final reported = await typeInto(tester, '250');

    expect(reported, [250]);
    expect(find.text('At most 1000'), findsNothing);
  });
}
