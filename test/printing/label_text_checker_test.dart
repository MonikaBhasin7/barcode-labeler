import 'package:barcode_labeler/features/design/data/models/label_font.dart';
import 'package:barcode_labeler/features/design/data/models/label_item.dart';
import 'package:barcode_labeler/features/design/data/models/label_value.dart';
import 'package:barcode_labeler/features/printing/application/label_text_checker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_designs.dart';

TextItem textBox({
  double width = 40,
  double height = 6,
  double size = 10,
  LabelFont font = LabelFont.roboto,
}) {
  return TextItem(
    id: 'name',
    name: 'Name',
    frame: ItemFrame(x: 0, y: 0, width: width, height: height),
    value: const LabelValue(),
    font: font,
    fontSizePt: size,
  );
}

void main() {
  final checker = LabelTextChecker(readBundledFonts());

  test('short text fits its box', () {
    expect(checker.problemWith(textBox(), 'Cotton shirt'), isNull);
  });

  test('text that needs more lines than the box has is reported', () {
    final problem = checker.problemWith(
      textBox(),
      'Cotton shirt blue with long sleeves and two pockets',
    );

    expect(problem, contains('too long'));
  });

  test('a taller box lets long text wrap onto more lines', () {
    final problem = checker.problemWith(
      textBox(height: 30),
      'Cotton shirt blue with long sleeves and two pockets',
    );

    expect(problem, isNull);
  });

  test('turned text uses the box height as its width', () {
    final turned = textBox(width: 6, height: 40);
    final turnedItem = turned.copyWithCommon(rotation: QuarterTurn.quarter);

    expect(checker.problemWith(turnedItem, 'Cotton shirt'), isNull);
  });

  test('letters the font does not have are reported', () {
    final problem = checker.problemWith(textBox(width: 80), 'शर्ट');

    expect(problem, contains('cannot be printed'));
  });

  test('a narrow font fits text that a normal font does not', () {
    const text = 'Cotton shirt blue, size 42';

    expect(checker.problemWith(textBox(width: 36), text), contains('too long'));
    expect(
      checker.problemWith(
        textBox(width: 36, font: LabelFont.robotoCondensed),
        text,
      ),
      isNull,
    );
  });

  test('a bigger text size can make the same text too long', () {
    const text = 'Cotton shirt';

    expect(checker.problemWith(textBox(size: 10), text), isNull);
    expect(checker.problemWith(textBox(size: 30), text), contains('too long'));
  });

  test('every shipped font has a normal and a bold file', () {
    final fonts = readBundledFonts();

    for (final font in LabelFont.values) {
      expect(fonts.filesFor(font).regular, isNotEmpty, reason: font.label);
      expect(fonts.filesFor(font).bold, isNotEmpty, reason: font.label);
    }
  });
}
