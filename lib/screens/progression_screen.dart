import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../app/theme.dart';
import '../models/progression_config.dart';
import '../providers/auth_provider.dart';
import '../providers/progression_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/gradient_scaffold.dart';

class ProgressionScreen extends ConsumerStatefulWidget {
  const ProgressionScreen({super.key});

  @override
  ConsumerState<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends ConsumerState<ProgressionScreen> {
  String? _expandedCode;

  @override
  Widget build(BuildContext context) {
    final dict = ref.watch(dictionaryProvider).valueOrNull;
    final configs = ref.watch(progressionsProvider).valueOrNull ?? {};
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final service = ref.read(firestoreServiceProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return GradientScaffold(
      appBar: AppBar(title: const Text('Прогрессия')),
      body: (dict == null || dict.isEmpty)
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Сначала настройте Key 1 в настройках',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.6),
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad + 80),
              itemCount: dict.sortedEntries.length,
              separatorBuilder: (_, __) => const Gap(10),
              itemBuilder: (_, i) {
                final entry = dict.sortedEntries[i];
                final code = entry.key;
                return _ExerciseProgressionCard(
                  key: ValueKey(code),
                  code: code,
                  name: entry.value,
                  config: configs[code],
                  isExpanded: _expandedCode == code,
                  onTap: () => setState(() {
                    _expandedCode = _expandedCode == code ? null : code;
                  }),
                  onSave: (config) async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await service.saveProgression(uid, config);
                      if (mounted) setState(() => _expandedCode = null);
                    } catch (_) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Не удалось сохранить')),
                      );
                    }
                  },
                  onReset: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await service.deleteProgression(uid, code);
                      if (mounted) setState(() => _expandedCode = null);
                    } catch (_) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Не удалось сбросить')),
                      );
                    }
                  },
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ExerciseProgressionCard extends StatefulWidget {
  final String code;
  final String name;
  final ProgressionConfig? config;
  final bool isExpanded;
  final VoidCallback onTap;
  final void Function(ProgressionConfig) onSave;
  final VoidCallback onReset;

  const _ExerciseProgressionCard({
    super.key,
    required this.code,
    required this.name,
    required this.config,
    required this.isExpanded,
    required this.onTap,
    required this.onSave,
    required this.onReset,
  });

  @override
  State<_ExerciseProgressionCard> createState() =>
      _ExerciseProgressionCardState();
}

class _ExerciseProgressionCardState extends State<_ExerciseProgressionCard> {
  late bool _isRepeating;
  late bool _isStrength;
  late String? _group;
  late TextEditingController _weightsCtrl;
  late TextEditingController _ladderCtrl;

  @override
  void initState() {
    super.initState();
    _initControllers(widget.config);
  }

  @override
  void didUpdateWidget(_ExerciseProgressionCard old) {
    super.didUpdateWidget(old);
    if (!widget.isExpanded && old.config != widget.config) {
      _disposeControllers();
      _initControllers(widget.config);
    }
  }

  void _initControllers(ProgressionConfig? config) {
    _isRepeating = config?.isRepeating ?? false;
    _isStrength = config?.isStrength ?? false;
    _group = config?.group;
    _weightsCtrl = TextEditingController(
      text: config?.weights
              .map((w) =>
                  w == w.truncateToDouble() ? w.toInt().toString() : '$w')
              .join(', ') ??
          '',
    );
    _ladderCtrl = TextEditingController(
      text: config?.ladder.map((s) => '${s.$1}x${s.$2}').join(', ') ?? '',
    );
    _weightsCtrl.addListener(() => setState(() {}));
    _ladderCtrl.addListener(() => setState(() {}));
  }

  void _disposeControllers() {
    _weightsCtrl.dispose();
    _ladderCtrl.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  List<double>? _parseWeights() {
    final text = _weightsCtrl.text.trim();
    if (text.isEmpty) return [];
    final result = <double>[];
    for (final part in text.split(',')) {
      final v = double.tryParse(part.trim());
      if (v == null) return null;
      result.add(v);
    }
    return result;
  }

  List<(int, int)>? _parseLadder() {
    final text = _ladderCtrl.text.trim();
    if (text.isEmpty) return [];
    final result = <(int, int)>[];
    final re = RegExp(r'^(\d+)[xX](\d+)$');
    for (final part in text.split(',')) {
      final m = re.firstMatch(part.trim());
      if (m == null) return null;
      final s = int.tryParse(m.group(1)!);
      final r = int.tryParse(m.group(2)!);
      if (s == null || r == null) return null;
      result.add((s, r));
    }
    return result;
  }

  bool get _canSave {
    if (_isRepeating) return true;
    if (_isStrength && _parseWeights() == null) return false;
    return _parseLadder() != null;
  }

  void _save() {
    widget.onSave(ProgressionConfig(
      exerciseCode: widget.code,
      isRepeating: _isRepeating,
      isStrength: _isStrength,
      group: _group,
      weights: (_isRepeating || !_isStrength) ? [] : (_parseWeights() ?? []),
      ladder: _isRepeating ? [] : (_parseLadder() ?? []),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasCustom = widget.config != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceVariant, AppColors.surface],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (widget.config?.isRepeating == true)
                    _chip('🔁', AppColors.textSecondary),
                  if (widget.config?.isStrength == true) ...[
                    const SizedBox(width: 4),
                    _chip('⚡', AppColors.heatmap75),
                  ],
                  if (hasCustom &&
                      !(widget.config!.isRepeating) &&
                      widget.config!.ladder.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _chip('custom', AppColors.accent),
                  ],
                  if (widget.config?.group != null) ...[
                    const SizedBox(width: 4),
                    _chip(widget.config!.group!, AppColors.heatmap50),
                  ],
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: widget.isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Expandable body ───────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: widget.isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: AppColors.divider, height: 1),
                        const SizedBox(height: 12),
                        _checkRow(
                          'Повторяющееся',
                          _isRepeating,
                          (v) => setState(() => _isRepeating = v ?? false),
                        ),
                        const SizedBox(height: 4),
                        _checkRow(
                          'Силовое',
                          _isStrength,
                          (v) => setState(() => _isStrength = v ?? false),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Группа',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _groupSelector(),
                        if (!_isRepeating) ...[
                          if (_isStrength) ...[
                            const SizedBox(height: 12),
                            _field(
                              controller: _weightsCtrl,
                              label: 'Веса (кг через запятую)',
                              hint: '40, 42.5, 45, 47.5',
                              error: _weightsCtrl.text.trim().isNotEmpty &&
                                      _parseWeights() == null
                                  ? 'Неверный формат'
                                  : null,
                            ),
                          ],
                          const SizedBox(height: 8),
                          _field(
                            controller: _ladderCtrl,
                            label: 'Прогрессия (3x10, 4x12, ...)',
                            hint: '3x10, 3x12, 3x15, 4x10, 4x12, 4x15',
                            error: _ladderCtrl.text.trim().isNotEmpty &&
                                    _parseLadder() == null
                                ? 'Неверный формат (нужно NxM)'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (hasCustom)
                              TextButton(
                                onPressed: widget.onReset,
                                child: const Text(
                                  'Сбросить',
                                  style: TextStyle(
                                      color: AppColors.textSecondary),
                                ),
                              ),
                            if (hasCustom) const SizedBox(width: 4),
                            ElevatedButton(
                              onPressed: _canSave ? _save : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('Сохранить'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _groupSelector() {
    const options = [null, 'A', 'B', 'C', 'D'];
    return Wrap(
      spacing: 6,
      children: options.map((g) {
        final label = g ?? 'None';
        final selected = _group == g;
        return GestureDetector(
          onTap: () => setState(() => _group = g),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? AppColors.accent
                    : AppColors.textMuted.withValues(alpha: 0.35),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _checkRow(String label, bool value, ValueChanged<bool?> onChange) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChange,
            activeColor: AppColors.accent,
            side: const BorderSide(color: AppColors.textMuted, width: 1.5),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14)),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? error,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        hintStyle:
            const TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
    );
  }
}
