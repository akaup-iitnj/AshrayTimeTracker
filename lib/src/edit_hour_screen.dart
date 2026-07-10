import 'package:flutter/material.dart';

import 'app_store.dart';
import 'category_editor_dialog.dart';
import 'models.dart';

class EditHourScreen extends StatefulWidget {
  const EditHourScreen({
    super.key,
    required this.store,
    required this.date,
    required this.hourStart,
  });

  final AppStore store;
  final DateTime date;
  final int hourStart;

  @override
  State<EditHourScreen> createState() => _EditHourScreenState();
}

class _EditHourScreenState extends State<EditHourScreen> {
  late final TextEditingController _taskController;
  String? _categoryId;
  bool _saving = false;

  HourEntry? get _existing =>
      widget.store.entryFor(widget.date, widget.hourStart);

  bool get _canSave =>
      !_saving && _taskController.text.trim().isNotEmpty && _categoryId != null;

  @override
  void initState() {
    super.initState();
    final existing = _existing;
    _taskController = TextEditingController(text: existing?.task ?? '')
      ..addListener(_refresh);
    _categoryId = existing?.categoryId;
  }

  @override
  void dispose() {
    _taskController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    await widget.store.saveEntry(
      date: widget.date,
      hourStart: widget.hourStart,
      task: _taskController.text,
      categoryId: _categoryId!,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear this hour?'),
        content: const Text('The task and category will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.deleteEntry(widget.date, widget.hourStart);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addCategory() async {
    final draft = await showCategoryEditorDialog(context);
    if (draft == null) return;
    final category = await widget.store.addCategory(
      draft.name,
      draft.colorValue,
    );
    if (mounted && category != null) {
      setState(() => _categoryId = category.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = MaterialLocalizations.of(
      context,
    ).formatMediumDate(widget.date);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log an hour'),
        actions: [
          if (_existing != null)
            IconButton(
              tooltip: 'Clear this hour',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  hourLabel(widget.hourStart),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateText,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'What did you do?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _taskController,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'A short description is enough',
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    for (final category in widget.store.categories)
                      ChoiceChip(
                        label: Text(category.name),
                        avatar: CircleAvatar(
                          radius: 6,
                          backgroundColor: Color(category.colorValue),
                        ),
                        selected: _categoryId == category.id,
                        onSelected: (_) {
                          setState(() => _categoryId = category.id);
                        },
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('New category'),
                      onPressed: _addCategory,
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                FilledButton.icon(
                  onPressed: _canSave ? _save : null,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Saving…' : 'Save hour'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
