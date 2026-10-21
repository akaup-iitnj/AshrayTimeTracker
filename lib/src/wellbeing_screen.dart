import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'date_navigator.dart';
import 'models.dart';

class WellbeingScreen extends StatefulWidget {
  const WellbeingScreen({
    super.key,
    required this.store,
    required this.date,
    required this.onDateChanged,
  });

  final AppStore store;
  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;

  @override
  State<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends State<WellbeingScreen> {
  final TextEditingController _noteController = TextEditingController();
  int _mood = 3;
  int _energy = 3;
  int _calm = 3;
  String? _loadedDate;
  DateTime? _loadedUpdatedAt;
  bool _dirty = false;
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_markDirty);
    widget.store.addListener(_handleStoreChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDate();
  }

  @override
  void didUpdateWidget(covariant WellbeingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isSameDay(oldWidget.date, widget.date)) _loadDate();
  }

  void _loadDate() {
    final key = dateKey(widget.date);
    final reflection = widget.store.reflectionFor(widget.date);
    if (_loadedDate == key &&
        (_dirty || reflection?.updatedAt == _loadedUpdatedAt)) {
      return;
    }
    _loading = true;
    _loadedDate = key;
    _loadedUpdatedAt = reflection?.updatedAt;
    _mood = reflection?.mood ?? 3;
    _energy = reflection?.energy ?? 3;
    _calm = reflection?.calm ?? 3;
    _noteController.text = reflection?.note ?? '';
    _dirty = false;
    _loading = false;
  }

  void _markDirty() {
    if (!_loading) _dirty = true;
  }

  void _handleStoreChanged() {
    if (!mounted) return;
    setState(_loadDate);
  }

  @override
  void dispose() {
    widget.store.removeListener(_handleStoreChanged);
    _noteController.removeListener(_markDirty);
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.store.saveReflection(
      date: widget.date,
      mood: _mood,
      energy: _energy,
      calm: _calm,
      note: _noteController.text,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
      _loadedUpdatedAt = widget.store.reflectionFor(widget.date)?.updatedAt;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Daily check-in saved.')));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(16.0, (constraints.maxWidth - 760) / 2);
        return ListView(
          key: PageStorageKey<String>('wellbeing-${dateKey(widget.date)}'),
          padding: EdgeInsets.fromLTRB(side, 22, side, 36),
          children: [
            Text(
              'Daily check-in',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            DateNavigator(
              date: widget.date,
              onDateChanged: widget.onDateChanged,
            ),
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How did today feel?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ScoreControl(
                      label: 'Mood',
                      lowLabel: 'Low',
                      highLabel: 'Great',
                      value: _mood,
                      onChanged: (value) => setState(() {
                        _mood = value;
                        _dirty = true;
                      }),
                    ),
                    _ScoreControl(
                      label: 'Energy',
                      lowLabel: 'Drained',
                      highLabel: 'Energized',
                      value: _energy,
                      onChanged: (value) => setState(() {
                        _energy = value;
                        _dirty = true;
                      }),
                    ),
                    _ScoreControl(
                      label: 'Calm',
                      lowLabel: 'Stressed',
                      highLabel: 'Calm',
                      value: _calm,
                      onChanged: (value) => setState(() {
                        _calm = value;
                        _dirty = true;
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reflect on your day',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'For now, type or paste a transcript. Voice recording and private transcription come next.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _noteController,
                      minLines: 5,
                      maxLines: 10,
                      maxLength: 10000,
                      decoration: const InputDecoration(
                        hintText:
                            'What happened today? What felt good or difficult?',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Save check-in'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScoreControl extends StatelessWidget {
  const _ScoreControl({
    required this.label,
    required this.lowLabel,
    required this.highLabel,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String lowLabel;
  final String highLabel;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text('$value / 5'),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$value',
            onChanged: (score) => onChanged(score.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(lowLabel), Text(highLabel)],
          ),
        ],
      ),
    );
  }
}
