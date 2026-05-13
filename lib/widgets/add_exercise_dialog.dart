import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../app/theme.dart';
import '../models/exercise.dart';
import '../models/key_dictionary.dart';
import '../providers/settings_provider.dart';

class AddExerciseDialog extends ConsumerStatefulWidget {
  const AddExerciseDialog({super.key});

  @override
  ConsumerState<AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends ConsumerState<AddExerciseDialog> {
  String? _selectedCode;
  final _weightCtrl = TextEditingController(text: '0');
  final _setsCtrl = TextEditingController();
  final _repsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
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

  bool _canSubmit(KeyDictionary dict) =>
      _selectedCode != null &&
      !dict.isEmpty &&
      _setsCtrl.text.isNotEmpty &&
      _repsCtrl.text.isNotEmpty;

  void _submit(KeyDictionary dict) {
    Navigator.of(context).pop(Exercise(
      code: _selectedCode!,
      name: dict.nameFor(_selectedCode!),
      weight: double.tryParse(_weightCtrl.text) ?? 0,
      sets: int.tryParse(_setsCtrl.text) ?? 1,
      reps: int.tryParse(_repsCtrl.text) ?? 1,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dictAsync = ref.watch(dictionaryProvider);
    final dict = dictAsync.valueOrNull ?? KeyDictionary.empty;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Добавить упражнение'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dict.isEmpty)
              const Text(
                'Сначала настройте Key 1 в настройках',
                style: TextStyle(color: Colors.orange, fontSize: 13),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedCode,
                hint: const Text('Выберите упражнение'),
                dropdownColor: AppColors.surfaceVariant,
                decoration: const InputDecoration(labelText: 'Упражнение'),
                items: dict.sortedEntries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value,
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCode = v),
              ),
            const Gap(12),
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
          onPressed: _canSubmit(dict) ? () => _submit(dict) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
          ),
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}
