import 'package:flutter/material.dart';

import 'models.dart';

const categoryColorPalette = <int>[
  0xFF345995,
  0xFF7A5CFA,
  0xFF2A9D8F,
  0xFF596780,
  0xFFE09F3E,
  0xFFE76F51,
  0xFFBF5AF2,
  0xFF7B817A,
  0xFFC44536,
  0xFF3A7D44,
];

class CategoryDraft {
  const CategoryDraft(this.name, this.colorValue);

  final String name;
  final int colorValue;
}

Future<CategoryDraft?> showCategoryEditorDialog(
  BuildContext context, {
  TimeCategory? category,
}) {
  return showDialog<CategoryDraft>(
    context: context,
    builder: (_) => _CategoryEditorDialog(category: category),
  );
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({required this.category});

  final TimeCategory? category;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late final TextEditingController _controller;
  late int _selectedColor;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.category?.name ?? '');
    _selectedColor = widget.category?.colorValue ?? categoryColorPalette.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, CategoryDraft(name, _selectedColor));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.category == null ? 'New category' : 'Edit category'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'Category name',
                hintText: 'e.g. Deep work',
              ),
            ),
            const SizedBox(height: 20),
            Text('Color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final colorValue in categoryColorPalette)
                  Semantics(
                    label: 'Category color',
                    selected: _selectedColor == colorValue,
                    button: true,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _selectedColor = colorValue),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(colorValue),
                          shape: BoxShape.circle,
                          border: _selectedColor == colorValue
                              ? Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: _selectedColor == colorValue
                            ? const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
