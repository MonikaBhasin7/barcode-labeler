import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../design/application/label_value_resolver.dart';
import '../../../design/data/models/label_design.dart';
import '../../../design/data/models/label_item.dart';
import '../../application/designer_controller.dart';
import 'label_item_view.dart';
import 'label_ruler.dart';

const double _canvasPadding = 32;
const double _realSizePixelsPerMm = 96 / 25.4;
const double _minPixelsPerMm = 0.4;
const double _maxPixelsPerMm = 40;
const double _resizeHandleSize = 10;

class LabelCanvas extends StatefulWidget {
  const LabelCanvas({super.key, required this.controller});

  final DesignerController controller;

  @override
  State<LabelCanvas> createState() => _LabelCanvasState();
}

class _LabelCanvasState extends State<LabelCanvas> {
  final FocusNode _focus = FocusNode(debugLabel: 'Label canvas');
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();
  double? _chosenPixelsPerMm;

  DesignerController get _controller => widget.controller;

  @override
  void dispose() {
    _focus.dispose();
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  double _pixelsPerMmToFit(BoxConstraints constraints, SheetLayout sheet) {
    final room = _canvasPadding * 2 + rulerThickness + 16;
    final across = (constraints.maxWidth - room) / sheet.labelWidthMm;
    final down = (constraints.maxHeight - room) / sheet.labelHeightMm;
    return math.min(across, down).clamp(_minPixelsPerMm, _maxPixelsPerMm);
  }

  void _zoomBy(double factor, double currentPixelsPerMm) {
    setState(() {
      _chosenPixelsPerMm = (currentPixelsPerMm * factor).clamp(
        _minPixelsPerMm,
        _maxPixelsPerMm,
      );
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    final baseStep = _controller.snapToGrid.value
        ? _controller.settings.lengthUnit.value.snapStepMm
        : 0.1;
    final step = keyboard.isShiftPressed ? baseStep * 10 : baseStep;
    final key = event.logicalKey;
    final commandHeld = keyboard.isControlPressed || keyboard.isMetaPressed;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _controller.nudgeSelectedItem(-step, 0);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _controller.nudgeSelectedItem(step, 0);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _controller.nudgeSelectedItem(0, -step);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _controller.nudgeSelectedItem(0, step);
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _controller.deleteSelectedItem();
    } else if (key == LogicalKeyboardKey.escape) {
      _controller.selectItem(null);
    } else if (key == LogicalKeyboardKey.keyD && commandHeld) {
      _controller.duplicateSelectedItem();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Obx(() {
        final sheet = _controller.design.value.sheet;
        final pixelsPerMm =
            _chosenPixelsPerMm ?? _pixelsPerMmToFit(constraints, sheet);
        return Focus(
          focusNode: _focus,
          onKeyEvent: _handleKey,
          child: Stack(
            children: [
              Positioned.fill(child: _scrollableLabel(pixelsPerMm)),
              Positioned(
                right: 12,
                bottom: 12,
                child: _ZoomBar(
                  pixelsPerMm: pixelsPerMm,
                  snapToGrid: _controller.snapToGrid.value,
                  snapStepLabel:
                      _controller.settings.lengthUnit.value.snapStepLabel,
                  onZoomOut: () => _zoomBy(1 / 1.25, pixelsPerMm),
                  onZoomIn: () => _zoomBy(1.25, pixelsPerMm),
                  onFit: () => setState(() => _chosenPixelsPerMm = null),
                  onSnapChanged: (snap) => _controller.snapToGrid.value = snap,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _scrollableLabel(double pixelsPerMm) {
    return Scrollbar(
      controller: _vertical,
      thumbVisibility: true,
      child: Scrollbar(
        controller: _horizontal,
        thumbVisibility: true,
        notificationPredicate: (notification) => notification.depth == 1,
        child: SingleChildScrollView(
          controller: _vertical,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(_canvasPadding),
              child: _rulersAroundLabel(pixelsPerMm),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rulersAroundLabel(double pixelsPerMm) {
    final sheet = _controller.design.value.sheet;
    final unit = _controller.settings.lengthUnit.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: rulerThickness, height: rulerThickness),
            LabelRuler(
              lengthMm: sheet.labelWidthMm,
              pixelsPerMm: pixelsPerMm,
              axis: Axis.horizontal,
              unit: unit,
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabelRuler(
              lengthMm: sheet.labelHeightMm,
              pixelsPerMm: pixelsPerMm,
              axis: Axis.vertical,
              unit: unit,
            ),
            _labelSurface(pixelsPerMm),
          ],
        ),
      ],
    );
  }

  Widget _labelSurface(double pixelsPerMm) {
    final design = _controller.design.value;
    final selected = _controller.selectedItem;
    final previewValues = _previewValues(design);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: design.sheet.labelWidthMm * pixelsPerMm,
          height: design.sheet.labelHeightMm * pixelsPerMm,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black26)],
          ),
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) {
                      _controller.selectItem(null);
                      _focus.requestFocus();
                    },
                    child: CustomPaint(
                      painter: _MillimetreGridPainter(pixelsPerMm),
                    ),
                  ),
                ),
                for (final item in design.items)
                  Positioned(
                    left: item.frame.x * pixelsPerMm,
                    top: item.frame.y * pixelsPerMm,
                    child: IgnorePointer(
                      child: LabelItemView(
                        item: item,
                        value: previewValues[item.id] ?? '',
                        pixelsPerMm: pixelsPerMm,
                      ),
                    ),
                  ),
                for (final item in _itemsInClickOrder(design.items))
                  _ItemClickArea(
                    key: ValueKey(item.id),
                    item: item,
                    pixelsPerMm: pixelsPerMm,
                    controller: _controller,
                    onPressed: _focus.requestFocus,
                  ),
              ],
            ),
          ),
        ),
        if (selected != null)
          ..._selectionMarks(selected, pixelsPerMm, context),
      ],
    );
  }

  List<LabelItem> _itemsInClickOrder(List<LabelItem> items) {
    return [
      ...items.where(_isEmptyShape),
      ...items.where((item) => !_isEmptyShape(item)),
    ];
  }

  bool _isEmptyShape(LabelItem item) {
    return item is ShapeItem && !item.filled && item.shape != ShapeKind.line;
  }

  Map<String, String> _previewValues(LabelDesign design) {
    final row = _controller.previewRow;
    final missingColumns = {
      for (final column in design.excelColumnsUsed)
        if (!row.containsKey(column)) column,
    };
    final answers = _controller.lastTypedAnswers();
    final unansweredKeys = {
      for (final question in design.printQuestions)
        if (!answers.containsKey(question.key)) question.key,
    };
    final context = LabelValueContext(
      row: {...row, for (final column in missingColumns) column: '[$column]'},
      recordIndex: 0,
      serialStarts: _controller.savedSerialStarts(),
      typedAnswers: {
        ...answers,
        for (final question in design.printQuestions)
          if (unansweredKeys.contains(question.key))
            question.key: '[${question.prompt}]',
      },
      today: DateTime.now(),
    );
    final resolver = LabelValueResolver(design.items);
    return {
      for (final item in design.items)
        if (item.labelValue != null)
          item.id:
              item is BarcodeItem &&
                  _waitsForData(design, item, missingColumns, unansweredKeys)
              ? item.type.sampleData
              : resolver.resolve(item, context),
    };
  }

  bool _waitsForData(
    LabelDesign design,
    LabelItem item,
    Set<String> missingColumns,
    Set<String> unansweredKeys,
  ) {
    return design.excelColumnsUsedBy(item).any(missingColumns.contains) ||
        design.questionKeysUsedBy(item).any(unansweredKeys.contains);
  }

  List<Widget> _selectionMarks(
    LabelItem item,
    double pixelsPerMm,
    BuildContext context,
  ) {
    final color = Theme.of(context).colorScheme.primary;
    final frame = item.frame;
    final right = (frame.x + frame.width) * pixelsPerMm;
    final bottom = (frame.y + frame.height) * pixelsPerMm;
    return [
      Positioned(
        left: frame.x * pixelsPerMm - 1,
        top: frame.y * pixelsPerMm - 1,
        width: frame.width * pixelsPerMm + 2,
        height: frame.height * pixelsPerMm + 2,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 1.5),
            ),
          ),
        ),
      ),
      Positioned(
        left: right - _resizeHandleSize,
        top: bottom - _resizeHandleSize,
        child: _ResizeHandle(
          item: item,
          pixelsPerMm: pixelsPerMm,
          controller: _controller,
          color: color,
        ),
      ),
    ];
  }
}

class _ItemClickArea extends StatefulWidget {
  const _ItemClickArea({
    super.key,
    required this.item,
    required this.pixelsPerMm,
    required this.controller,
    required this.onPressed,
  });

  final LabelItem item;
  final double pixelsPerMm;
  final DesignerController controller;
  final VoidCallback onPressed;

  @override
  State<_ItemClickArea> createState() => _ItemClickAreaState();
}

class _ItemClickAreaState extends State<_ItemClickArea> {
  int _gestureId = 0;
  ItemFrame _frameAtStart = const ItemFrame(x: 0, y: 0, width: 0, height: 0);
  Offset _dragged = Offset.zero;

  void _startMove(DragStartDetails details) {
    _gestureId = widget.controller.startItemGesture(widget.item.id);
    _frameAtStart = widget.item.frame;
    _dragged = Offset.zero;
    widget.onPressed();
  }

  void _continueMove(DragUpdateDetails details) {
    _dragged += details.delta;
    final controller = widget.controller;
    final moved = _frameAtStart.copyWith(
      x: controller.snappedMm(
        _frameAtStart.x + _dragged.dx / widget.pixelsPerMm,
      ),
      y: controller.snappedMm(
        _frameAtStart.y + _dragged.dy / widget.pixelsPerMm,
      ),
    );
    controller.moveItemDuringGesture(widget.item.id, moved, _gestureId);
  }

  @override
  Widget build(BuildContext context) {
    final frame = widget.item.frame;
    return Positioned(
      left: frame.x * widget.pixelsPerMm,
      top: frame.y * widget.pixelsPerMm,
      width: frame.width * widget.pixelsPerMm,
      height: frame.height * widget.pixelsPerMm,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          widget.controller.selectItem(widget.item.id);
          widget.onPressed();
        },
        onPanStart: _startMove,
        onPanUpdate: _continueMove,
        child: const MouseRegion(cursor: SystemMouseCursors.move),
      ),
    );
  }
}

class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.item,
    required this.pixelsPerMm,
    required this.controller,
    required this.color,
  });

  final LabelItem item;
  final double pixelsPerMm;
  final DesignerController controller;
  final Color color;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  int _gestureId = 0;
  ItemFrame _frameAtStart = const ItemFrame(x: 0, y: 0, width: 0, height: 0);
  Offset _dragged = Offset.zero;

  void _startResize(DragStartDetails details) {
    _gestureId = widget.controller.startItemGesture(widget.item.id);
    _frameAtStart = widget.item.frame;
    _dragged = Offset.zero;
  }

  void _continueResize(DragUpdateDetails details) {
    _dragged += details.delta;
    final controller = widget.controller;
    final width = controller.snappedMm(
      _frameAtStart.width + _dragged.dx / widget.pixelsPerMm,
    );
    final height = controller.snappedMm(
      _frameAtStart.height + _dragged.dy / widget.pixelsPerMm,
    );
    final resized = _frameAtStart.copyWith(
      width: math.max(1, width),
      height: math.max(1, height),
    );
    controller.moveItemDuringGesture(widget.item.id, resized, _gestureId);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _startResize,
      onPanUpdate: _continueResize,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeDownRight,
        child: Container(
          width: _resizeHandleSize,
          height: _resizeHandleSize,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: widget.color, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _ZoomBar extends StatelessWidget {
  const _ZoomBar({
    required this.pixelsPerMm,
    required this.snapToGrid,
    required this.snapStepLabel,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onFit,
    required this.onSnapChanged,
  });

  final double pixelsPerMm;
  final bool snapToGrid;
  final String snapStepLabel;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onFit;
  final ValueChanged<bool> onSnapChanged;

  @override
  Widget build(BuildContext context) {
    final percent = (pixelsPerMm / _realSizePixelsPerMm * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilterChip(
              label: Text('Snap to $snapStepLabel'),
              selected: snapToGrid,
              onSelected: onSnapChanged,
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Zoom out',
              icon: const Icon(Icons.zoom_out),
              onPressed: onZoomOut,
            ),
            SizedBox(width: 48, child: Center(child: Text('$percent%'))),
            IconButton(
              tooltip: 'Zoom in',
              icon: const Icon(Icons.zoom_in),
              onPressed: onZoomIn,
            ),
            TextButton(onPressed: onFit, child: const Text('Fit')),
          ],
        ),
      ),
    );
  }
}

class _MillimetreGridPainter extends CustomPainter {
  _MillimetreGridPainter(this.pixelsPerMm);

  final double pixelsPerMm;

  @override
  void paint(Canvas canvas, Size size) {
    final stepMm = pixelsPerMm * 5 >= 12 ? 5 : 10;
    final paint = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;
    for (var mm = stepMm; mm * pixelsPerMm < size.width; mm += stepMm) {
      final x = mm * pixelsPerMm;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var mm = stepMm; mm * pixelsPerMm < size.height; mm += stepMm) {
      final y = mm * pixelsPerMm;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_MillimetreGridPainter oldDelegate) {
    return oldDelegate.pixelsPerMm != pixelsPerMm;
  }
}
