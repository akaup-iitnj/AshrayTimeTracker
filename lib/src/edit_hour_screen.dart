import 'package:flutter/material.dart';

import 'app_store.dart';
import 'bold.dart';
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
  bool? _productive;
  bool _saving = false;

  HourEntry? get _existing =>
      widget.store.entryFor(widget.date, widget.hourStart);

  // A full log needs a task and a category; a productive rating alone is
  // also enough, matching what the notification buttons record.
  bool get _canSave =>
      !_saving &&
      (_productive != null ||
          (_taskController.text.trim().isNotEmpty && _categoryId != null));

  @override
  void initState() {
    super.initState();
    final existing = _existing;
    _taskController = TextEditingController(text: existing?.task ?? '')
      ..addListener(_refresh);
    _categoryId = existing?.categoryId;
    _productive = existing?.productive;
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
      categoryId: _categoryId,
      productive: _productive,
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

  /// Tapping the selected rating again clears it.
  void _toggleRating(bool value) {
    setState(() => _productive = _productive == value ? null : value);
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
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 2),
                Text(dateText, style: dmSans(600, size: 15, color: Bold.muted)),
                const SizedBox(height: 26),
                const _SectionLabel('What did you do?'),
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
                const SizedBox(height: 24),
                const _SectionLabel('Category'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in widget.store.categories)
                      ChoiceChip(
                        label: Text(category.name),
                        avatar: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Color(category.colorValue),
                            shape: BoxShape.circle,
                            border: Border.all(color: Bold.ink),
                          ),
                        ),
                        selected: _categoryId == category.id,
                        onSelected: (_) {
                          setState(() => _categoryId = category.id);
                        },
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18, color: Bold.ink),
                      label: const Text('New category'),
                      backgroundColor: Bold.soft,
                      onPressed: _addCategory,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Was it productive?'),
                Row(
                  children: [
                    Expanded(
                      child: _RatingTile(
                        label: 'Productive',
                        icon: Icons.thumb_up_alt_rounded,
                        color: Bold.sky,
                        selected: _productive == true,
                        onTap: () => _toggleRating(true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _RatingTile(
                        label: 'Not productive',
                        icon: Icons.thumb_down_alt_rounded,
                        color: Bold.coral,
                        selected: _productive == false,
                        onTap: () => _toggleRating(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                BoldButton(
                  label: _saving ? 'Saving…' : 'Save hour',
                  icon: const Icon(Icons.check_rounded),
                  expand: true,
                  onPressed: _canSave ? _save : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: dmSans(
          800,
          size: 12,
          color: Bold.ink,
        ).copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: BoldCard(
        color: selected ? color : Bold.panel,
        radius: Bold.radiusSm,
        shadow: selected ? Bold.shadow : Bold.shadowSm,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Bold.ink),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: dmSans(selected ? 800 : 600, size: 14, color: Bold.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
