import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../app/theme.dart';
import '../models/exercise.dart';
import '../models/key_dictionary.dart';
import '../models/progression_config.dart';
import '../providers/progression_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';

// Progression ladder: (sets, reps). Applies to all exercises except _noProgressionCodes.
const _ladder = [
  (3, 10), (3, 12), (3, 15),
  (4, 10), (4, 12), (4, 15),
  (5, 10), (5, 12), (5, 15),
  (6, 10), (6, 12), (6, 15),
];

// Weight-only progression exercises (sets/reps stay fixed per plan).
const _noProgressionCodes = {'BP'};

// Default weight increment when progression resets.
const _weightStep = 2.5;

({double weight, int sets, int reps, bool isProgressed}) _suggest(
  Exercise last,
  ProgressionConfig? config,
) {
  // ── Custom config: repeating ──────────────────────────────────────────────
  if (config != null && config.isRepeating) {
    return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
  }

  // ── Custom config: custom ladder ──────────────────────────────────────────
  if (config != null && config.ladder.isNotEmpty) {
    final allDone = last.completedSets.every((c) => c);
    if (!allDone) {
      return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
    }

    final stepIdx = config.ladder
        .indexWhere((s) => s.$1 == last.sets && s.$2 == last.reps);
    if (stepIdx == -1) {
      return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
    }

    final weightIdx = config.weights
        .indexWhere((w) => (w - last.weight).abs() < 0.01);

    int nextStep = stepIdx + 1;
    int nextWeightIdx = weightIdx < 0 ? 0 : weightIdx;

    if (nextStep >= config.ladder.length) {
      nextStep = 0;
      nextWeightIdx = (weightIdx < 0 ? 0 : weightIdx) + 1;
      if (nextWeightIdx >= config.weights.length) {
        return (
          weight: last.weight,
          sets: config.ladder.last.$1,
          reps: config.ladder.last.$2,
          isProgressed: false,
        );
      }
    }

    final nextWeight =
        config.weights.isNotEmpty ? config.weights[nextWeightIdx] : last.weight;
    final step = config.ladder[nextStep];
    return (weight: nextWeight, sets: step.$1, reps: step.$2, isProgressed: true);
  }

  // ── Fallback: hardcoded default ladder ────────────────────────────────────
  if (_noProgressionCodes.contains(last.code)) {
    return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
  }

  final idx = _ladder.indexWhere((s) => s.$1 == last.sets && s.$2 == last.reps);
  if (idx == -1) {
    return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
  }

  final allDone = last.completedSets.every((c) => c);
  if (!allDone) {
    return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
  }

  if (idx == _ladder.length - 1) {
    final nextWeight = last.weight > 0 ? last.weight + _weightStep : 0.0;
    return (weight: nextWeight, sets: 3, reps: 10, isProgressed: true);
  }

  final next = _ladder[idx + 1];
  return (weight: last.weight, sets: next.$1, reps: next.$2, isProgressed: true);
}

String _formatWeight(double w) =>
    w == w.truncateToDouble() ? '${w.toInt()} кг' : '$w кг';

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

  // Hint shown below the fields
  String? _hintText;
  bool _hintIsProgress = false;

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

  void _onCodeSelected(String? code) {
    setState(() {
      _selectedCode = code;
      _hintText = null;
      _hintIsProgress = false;
    });
    if (code == null) return;

    // Eagerly read from cache if already loaded, otherwise it will rebuild via watch
    final cached = ref.read(lastExerciseProvider(code)).valueOrNull;
    if (cached != null) _applyLast(cached);
  }

  void _applyLast(Exercise last) {
    final config = ref.read(progressionConfigProvider(last.code));
    final s = _suggest(last, config);

    _weightCtrl.text = s.weight == s.weight.truncateToDouble()
        ? s.weight.toInt().toString()
        : s.weight.toString();
    _setsCtrl.text = s.sets.toString();
    _repsCtrl.text = s.reps.toString();

    final allDone = last.completedSets.every((c) => c);
    if (config?.isRepeating == true) {
      final status = allDone ? '✓' : '✗';
      _hintText =
          'Повторяется: ${_formatWeight(last.weight)} × ${last.sets} × ${last.reps} $status';
      _hintIsProgress = false;
    } else if (s.isProgressed) {
      if (last.weight > 0 && (s.weight - last.weight).abs() > 0.01) {
        _hintText =
            '↑ Новый вес: ${_formatWeight(s.weight)} × ${s.sets} × ${s.reps}';
      } else {
        _hintText =
            '↑ Прогрессия: ${last.sets}×${last.reps} → ${s.sets}×${s.reps}';
      }
      _hintIsProgress = true;
    } else {
      final status = allDone ? '✓' : '✗';
      _hintText =
          'Прошлый раз: ${_formatWeight(last.weight)} × ${last.sets} × ${last.reps} $status';
      _hintIsProgress = false;
    }
    setState(() {});
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

    // Watch the last exercise for the selected code to auto-fill when loaded
    if (_selectedCode != null) {
      ref.listen(lastExerciseProvider(_selectedCode!), (prev, next) {
        final ex = next.valueOrNull;
        if (ex != null && prev?.valueOrNull == null) {
          _applyLast(ex);
        }
      });
    }

    final isLoading = _selectedCode != null &&
        ref.watch(lastExerciseProvider(_selectedCode!)).isLoading;

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
                initialValue: _selectedCode,
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
                onChanged: _onCodeSelected,
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
            // Hint / loading indicator
            if (isLoading) ...[
              const Gap(10),
              const Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CupertinoActivityIndicator(radius: 6),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Загружаем историю...',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ] else if (_hintText != null) ...[
              const Gap(10),
              Text(
                _hintText!,
                style: TextStyle(
                  color: _hintIsProgress
                      ? AppColors.accent
                      : AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
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
