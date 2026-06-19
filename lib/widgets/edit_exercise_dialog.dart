import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../app/theme.dart';
import '../models/exercise.dart';

class EditExerciseDialog extends StatefulWidget {
  final Exercise exercise;

  const EditExerciseDialog({super.key, required this.exercise});

  @override
  State<EditExerciseDialog> createState() => _EditExerciseDialogState();
}

class _EditExerciseDialogState extends State<EditExerciseDialog> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _setsCtrl;
  late final TextEditingController _repsCtrl;

  @override
  void initState() {
    super.initState();
    final w = widget.exercise.weight;
    _weightCtrl = TextEditingController(
      text: w == w.truncateToDouble() ? w.toInt().toString() : w.toString(),
    );
    _setsCtrl = TextEditingController(text: widget.exercise.sets.toString());
    _repsCtrl = TextEditingController(text: widget.exercise.reps.toString());
    _weightCtrl.addListener(() => setState(() {}));
    _setsCtrl.addListener(() => setState(() {}));
    _repsCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _setsCtrl.text.isNotEmpty && _repsCtrl.text.isNotEmpty;

  void _save() {
    final newSets = int.tryParse(_setsCtrl.text) ?? widget.exercise.sets;
    final newReps = int.tryParse(_repsCtrl.text) ?? widget.exercise.reps;
    final newWeight =
        double.tryParse(_weightCtrl.text) ?? widget.exercise.weight;

    // Preserve existing completedSets as much as possible.
    final old = widget.exercise.completedSets;
    final List<bool> newCompleted;
    if (newSets == old.length) {
      newCompleted = List<bool>.from(old);
    } else if (newSets < old.length) {
      newCompleted = old.sublist(0, newSets);
    } else {
      newCompleted = [...old, ...List.filled(newSets - old.length, false)];
    }

    Navigator.of(context).pop(Exercise(
      code: widget.exercise.code,
      name: widget.exercise.name,
      weight: newWeight,
      sets: newSets,
      reps: newReps,
      completedSets: newCompleted,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        widget.exercise.name,
        style: const TextStyle(fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _weightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Вес (кг), 0 = без веса'),
            ),
            const Gap(8),
            TextField(
              controller: _setsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Подходы'),
            ),
            const Gap(8),
            TextField(
              controller: _repsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Повторения'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _canSave ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
          ),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
