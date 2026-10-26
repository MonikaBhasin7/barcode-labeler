import 'package:barcode_labeler/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens on the home screen with the app name', (tester) async {
    await tester.pumpWidget(const BarcodeLabelerApp());

    expect(find.text('Barcode Labeler'), findsOneWidget);
    expect(find.text('No label designs yet'), findsOneWidget);
  });
}
