import '../../../../core/ids.dart';
import '../../../../core/json_reading.dart';
import 'label_font.dart';
import 'label_item.dart';
import 'label_value.dart';

enum PaperSize {
  a4('A4', 210, 297),
  a5('A5', 148, 210),
  a3('A3', 297, 420),
  letter('Letter', 215.9, 279.4),
  legal('Legal', 215.9, 355.6),
  custom('Custom size', 0, 0);

  const PaperSize(this.label, this.widthMm, this.heightMm);

  final String label;
  final double widthMm;
  final double heightMm;
}

enum FillOrder {
  acrossThenDown('Left to right, then down'),
  downThenAcross('Top to bottom, then across');

  const FillOrder(this.label);

  final String label;
}

class SheetLayout {
  const SheetLayout({
    required this.paper,
    required this.pageWidthMm,
    required this.pageHeightMm,
    this.marginTopMm = 0,
    this.marginLeftMm = 0,
    required this.labelWidthMm,
    required this.labelHeightMm,
    this.gapAcrossMm = 0,
    this.gapDownMm = 0,
    this.columns = 1,
    this.rows = 1,
    this.fillOrder = FillOrder.acrossThenDown,
  });

  factory SheetLayout.fromJson(Map<String, dynamic> json) {
    return SheetLayout(
      paper: readEnum(PaperSize.values, json['paper'], PaperSize.custom),
      pageWidthMm: readDouble(json, 'pageWidthMm', 210),
      pageHeightMm: readDouble(json, 'pageHeightMm', 297),
      marginTopMm: readDouble(json, 'marginTopMm', 0),
      marginLeftMm: readDouble(json, 'marginLeftMm', 0),
      labelWidthMm: readDouble(json, 'labelWidthMm', 210),
      labelHeightMm: readDouble(json, 'labelHeightMm', 297),
      gapAcrossMm: readDouble(json, 'gapAcrossMm', 0),
      gapDownMm: readDouble(json, 'gapDownMm', 0),
      columns: readInt(json, 'columns', 1),
      rows: readInt(json, 'rows', 1),
      fillOrder: readEnum(
        FillOrder.values,
        json['fillOrder'],
        FillOrder.acrossThenDown,
      ),
    );
  }

  static const SheetLayout wholeA4Page = SheetLayout(
    paper: PaperSize.a4,
    pageWidthMm: 210,
    pageHeightMm: 297,
    labelWidthMm: 210,
    labelHeightMm: 297,
  );

  final PaperSize paper;
  final double pageWidthMm;
  final double pageHeightMm;
  final double marginTopMm;
  final double marginLeftMm;
  final double labelWidthMm;
  final double labelHeightMm;
  final double gapAcrossMm;
  final double gapDownMm;
  final int columns;
  final int rows;
  final FillOrder fillOrder;

  int get labelsPerSheet => columns * rows;

  SheetLayout copyWith({
    PaperSize? paper,
    double? pageWidthMm,
    double? pageHeightMm,
    double? marginTopMm,
    double? marginLeftMm,
    double? labelWidthMm,
    double? labelHeightMm,
    double? gapAcrossMm,
    double? gapDownMm,
    int? columns,
    int? rows,
    FillOrder? fillOrder,
  }) {
    return SheetLayout(
      paper: paper ?? this.paper,
      pageWidthMm: pageWidthMm ?? this.pageWidthMm,
      pageHeightMm: pageHeightMm ?? this.pageHeightMm,
      marginTopMm: marginTopMm ?? this.marginTopMm,
      marginLeftMm: marginLeftMm ?? this.marginLeftMm,
      labelWidthMm: labelWidthMm ?? this.labelWidthMm,
      labelHeightMm: labelHeightMm ?? this.labelHeightMm,
      gapAcrossMm: gapAcrossMm ?? this.gapAcrossMm,
      gapDownMm: gapDownMm ?? this.gapDownMm,
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      fillOrder: fillOrder ?? this.fillOrder,
    );
  }

  Map<String, dynamic> toJson() => {
    'paper': paper.name,
    'pageWidthMm': pageWidthMm,
    'pageHeightMm': pageHeightMm,
    'marginTopMm': marginTopMm,
    'marginLeftMm': marginLeftMm,
    'labelWidthMm': labelWidthMm,
    'labelHeightMm': labelHeightMm,
    'gapAcrossMm': gapAcrossMm,
    'gapDownMm': gapDownMm,
    'columns': columns,
    'rows': rows,
    'fillOrder': fillOrder.name,
  };
}

class DataFileLink {
  const DataFileLink({required this.path, required this.sheetName});

  factory DataFileLink.fromJson(Map<String, dynamic> json) {
    return DataFileLink(
      path: readString(json, 'path', ''),
      sheetName: readString(json, 'sheetName', ''),
    );
  }

  final String path;
  final String sheetName;

  Map<String, dynamic> toJson() => {'path': path, 'sheetName': sheetName};
}

class LabelDesign {
  const LabelDesign({
    required this.id,
    required this.name,
    required this.sheet,
    required this.items,
    this.dataFile,
  });

  factory LabelDesign.blank() {
    return LabelDesign(
      id: newRandomId(),
      name: 'Untitled',
      sheet: SheetLayout.wholeA4Page,
      items: const [],
    );
  }

  factory LabelDesign.fromJson(Map<String, dynamic> json) {
    if (json['format'] != fileFormat) {
      throw const FormatException('This is not a Barcode Labeler design file.');
    }
    final items = json['items'];
    final dataFile = json['dataFile'];
    return LabelDesign(
      id: readString(json, 'id', newRandomId()),
      name: readString(json, 'name', 'Untitled'),
      sheet: SheetLayout.fromJson(readMap(json, 'sheet')),
      items: [
        if (items is List)
          for (final item in items.whereType<Map<String, dynamic>>())
            LabelItem.fromJson(item),
      ],
      dataFile: dataFile is Map<String, dynamic>
          ? DataFileLink.fromJson(dataFile)
          : null,
    );
  }

  static const String fileFormat = 'barcode-labeler-design';
  static const int fileVersion = 1;

  final String id;
  final String name;
  final SheetLayout sheet;
  final List<LabelItem> items;
  final DataFileLink? dataFile;

  Set<String> get excelColumnsUsed => {
    for (final item in items) ...excelColumnsUsedBy(item),
  };

  bool get usesExcelColumns => excelColumnsUsed.isNotEmpty;

  Set<TextFont> get fontsUsed => {
    robotoFont,
    for (final item in items.whereType<TextItem>()) item.font,
  };

  List<SerialNumberSource> get serialNumberSources => [
    for (final item in items)
      for (final source in valueSourcesOf(item))
        if (source.value.kind == ValueSourceKind.serialNumber)
          SerialNumberSource(
            key: source.key,
            label: source.label,
            rule: source.value.serial,
          ),
  ];

  List<PrintQuestion> get printQuestions => [
    for (final item in items)
      for (final source in valueSourcesOf(item))
        if (source.value.kind == ValueSourceKind.typedWhenPrinting)
          PrintQuestion(
            key: source.key,
            label: source.label,
            question: source.value.question,
          ),
  ];

  Set<String> excelColumnsUsedBy(LabelItem item) {
    return {
      for (final source in _valueSourcesFollowingLink(item))
        if (source.value.kind == ValueSourceKind.excelColumn &&
            source.value.excelColumn.isNotEmpty)
          source.value.excelColumn,
    };
  }

  Set<String> questionKeysUsedBy(LabelItem item) {
    return {
      for (final source in _valueSourcesFollowingLink(item))
        if (source.value.kind == ValueSourceKind.typedWhenPrinting) source.key,
    };
  }

  List<ValueSource> valueSourcesOf(LabelItem item) {
    final value = item.labelValue;
    if (value == null) return const [];
    if (value.kind != ValueSourceKind.joinedParts) {
      return [ValueSource(key: item.id, label: item.name, value: value)];
    }
    return [
      for (final (index, part) in value.parts.indexed)
        ValueSource(
          key: partValueKey(item.id, part.id),
          label: '${item.name} · part ${index + 1}',
          value: part.value,
        ),
    ];
  }

  List<ValueSource> _valueSourcesFollowingLink(LabelItem item) {
    final value = item.labelValue;
    if (value?.kind != ValueSourceKind.sameAsItem) return valueSourcesOf(item);
    final linked = itemById(value!.sameAsItemId);
    if (linked == null ||
        linked.labelValue?.kind == ValueSourceKind.sameAsItem) {
      return const [];
    }
    return valueSourcesOf(linked);
  }

  LabelItem? itemById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  LabelDesign copyWith({
    String? name,
    SheetLayout? sheet,
    List<LabelItem>? items,
    DataFileLink? dataFile,
    bool removeDataFile = false,
  }) {
    return LabelDesign(
      id: id,
      name: name ?? this.name,
      sheet: sheet ?? this.sheet,
      items: items ?? this.items,
      dataFile: removeDataFile ? null : dataFile ?? this.dataFile,
    );
  }

  Map<String, dynamic> toJson() => {
    'format': fileFormat,
    'version': fileVersion,
    'id': id,
    'name': name,
    'sheet': sheet.toJson(),
    'items': [for (final item in items) item.toJson()],
    if (dataFile case final link?) 'dataFile': link.toJson(),
  };
}

String partValueKey(String itemId, String partId) => '$itemId/$partId';

class ValueSource {
  const ValueSource({
    required this.key,
    required this.label,
    required this.value,
  });

  final String key;
  final String label;
  final LabelValue value;
}

class SerialNumberSource {
  const SerialNumberSource({
    required this.key,
    required this.label,
    required this.rule,
  });

  final String key;
  final String label;
  final SerialNumberRule rule;
}

class PrintQuestion {
  const PrintQuestion({
    required this.key,
    required this.label,
    required this.question,
  });

  final String key;
  final String label;
  final String question;

  String get prompt {
    final trimmed = question.trim();
    return trimmed.isEmpty ? 'Value for $label' : trimmed;
  }
}
