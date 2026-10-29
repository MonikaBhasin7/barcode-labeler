import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/fonts/installed_font_files.dart';
import '../../../../core/fonts/installed_fonts.dart';
import '../../../design/data/models/label_font.dart';

class FontField extends StatelessWidget {
  const FontField({
    super.key,
    required this.font,
    required this.installedFonts,
    required this.onChanged,
  });

  final TextFont font;
  final InstalledFonts installedFonts;
  final ValueChanged<TextFont> onChanged;

  Future<void> _pickFont(BuildContext context) async {
    final picked = await showDialog<TextFont>(
      context: context,
      builder: (_) =>
          _FontPickerDialog(current: font, installedFonts: installedFonts),
    );
    if (picked != null && picked != font) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return switch (font) {
      BuiltInFont() => _field(context, problem: null),
      final InstalledFont installed => Obx(
        () => _field(context, problem: installedFonts.problemWith(installed)),
      ),
    };
  }

  Widget _field(BuildContext context, {required String? problem}) {
    return InkWell(
      onTap: () => _pickFont(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Font',
          errorText: problem,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          font.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: font.screenFamily,
            fontFamilyFallback: const ['Roboto'],
          ),
        ),
      ),
    );
  }
}

class _FontPickerDialog extends StatefulWidget {
  const _FontPickerDialog({
    required this.current,
    required this.installedFonts,
  });

  final TextFont current;
  final InstalledFonts installedFonts;

  @override
  State<_FontPickerDialog> createState() => _FontPickerDialogState();
}

class _FontPickerDialogState extends State<_FontPickerDialog> {
  String _search = '';

  InstalledFonts get _installedFonts => widget.installedFonts;

  @override
  void initState() {
    super.initState();
    _installedFonts.lookAgain();
  }

  bool _matchesSearch(String name) => name.toLowerCase().contains(_search);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose a font'),
      content: SizedBox(
        width: 460,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search fonts',
              ),
              onChanged: (text) =>
                  setState(() => _search = text.trim().toLowerCase()),
            ),
            const SizedBox(height: 8),
            Expanded(child: Obx(() => _fontList(context))),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Look for new fonts'),
          onPressed: _installedFonts.lookAgain,
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _fontList(BuildContext context) {
    final builtIn = LabelFont.values
        .where((font) => _matchesSearch(font.label))
        .toList();
    final installed = _installedFonts.families
        .where((family) => _matchesSearch(family.name))
        .toList();
    final rows = <Widget>[
      _heading(context, 'Built into this app'),
      for (final font in builtIn) _builtInRow(font),
      if (builtIn.isEmpty) _note(context, 'No built-in font matches.'),
      _heading(context, 'Fonts on this PC'),
      ..._installedStatus(context, matchCount: installed.length),
      for (final family in installed) _installedRow(context, family),
    ];
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index],
    );
  }

  List<Widget> _installedStatus(
    BuildContext context, {
    required int matchCount,
  }) {
    final problem = _installedFonts.searchProblem.value;
    if (problem != null) return [_note(context, problem)];
    if (_installedFonts.lookingForFonts.value) {
      return [_note(context, 'Looking for fonts on this PC…')];
    }
    if (_installedFonts.families.isEmpty) {
      return [_note(context, 'No fonts were found on this PC.')];
    }
    if (matchCount == 0) return [_note(context, 'No font on this PC matches.')];
    return const [];
  }

  Widget _builtInRow(LabelFont font) {
    final choice = BuiltInFont(font);
    return ListTile(
      dense: true,
      title: Text(font.label, style: TextStyle(fontFamily: font.familyName)),
      trailing: choice == widget.current ? const Icon(Icons.check) : null,
      onTap: () => Navigator.pop(context, choice),
    );
  }

  Widget _installedRow(BuildContext context, InstalledFontFamily family) {
    final choice = InstalledFont(family.name);
    return ListTile(
      dense: true,
      enabled: family.canPrint,
      title: Text(family.name),
      subtitle: switch ((family.canPrint, family.hasBold)) {
        (false, _) => const Text('This kind of font file cannot be printed'),
        (true, false) => const Text('No bold'),
        (true, true) => null,
      },
      trailing: choice == widget.current ? const Icon(Icons.check) : null,
      onTap: () => Navigator.pop(context, choice),
    );
  }

  Widget _heading(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  Widget _note(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
