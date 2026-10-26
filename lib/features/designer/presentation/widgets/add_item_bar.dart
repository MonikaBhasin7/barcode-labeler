import 'package:flutter/material.dart';

import '../../../design/data/models/label_item.dart';
import '../../application/designer_controller.dart';

class AddItemBar extends StatelessWidget {
  const AddItemBar({
    super.key,
    required this.controller,
    required this.onAddPicture,
  });

  final DesignerController controller;
  final VoidCallback onAddPicture;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            _AddButton(
              icon: Icons.view_week_outlined,
              label: 'Barcode',
              onPressed: controller.addBarcodeItem,
            ),
            _AddButton(
              icon: Icons.qr_code_2,
              label: 'QR code',
              onPressed: controller.addQrCodeItem,
            ),
            _AddButton(
              icon: Icons.title,
              label: 'Text',
              onPressed: controller.addTextItem,
            ),
            _AddButton(
              icon: Icons.horizontal_rule,
              label: 'Line',
              onPressed: () => controller.addShapeItem(ShapeKind.line),
            ),
            _AddButton(
              icon: Icons.crop_square,
              label: 'Box',
              onPressed: () => controller.addShapeItem(ShapeKind.rectangle),
            ),
            _AddButton(
              icon: Icons.circle_outlined,
              label: 'Circle',
              onPressed: () => controller.addShapeItem(ShapeKind.ellipse),
            ),
            _AddButton(
              icon: Icons.image_outlined,
              label: 'Picture',
              onPressed: onAddPicture,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Add $label',
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
