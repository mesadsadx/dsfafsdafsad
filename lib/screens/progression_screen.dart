import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/theme.dart';
import '../models/progression_config.dart';
import '../providers/auth_provider.dart';
import '../providers/progression_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/gradient_scaffold.dart';

// ── encode / decode ───────────────────────────────────────────────────────────

String _encodeConfigs(Map<String, ProgressionConfig> configs) {
  final list = configs.values.map((c) {
    final m = <String, dynamic>{'c': c.exerciseCode};
    if (c.isRepeating) m['r'] = true;
    if (c.isStrength) m['s'] = true;
    if (c.group != null) m['g'] = c.group;
    if (c.weights.isNotEmpty) m['w'] = c.weights;
    if (c.ladder.isNotEmpty) {
      m['l'] = c.ladder.map((s) => [s.$1, s.$2]).toList();
    }
    return m;
  }).toList();
  return base64Url.encode(utf8.encode(jsonEncode(list)));
}

List<ProgressionConfig>? _decodeConfigs(String raw) {
  try {
    final normalized = base64Url.normalize(raw.trim());
    final decoded = utf8.decode(base64Url.decode(normalized));
    final list = jsonDecode(decoded) as List;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return ProgressionConfig(
        exerciseCode: m['c'] as String,
        isRepeating: (m['r'] as bool?) ?? false,
        isStrength: (m['s'] as bool?) ?? false,
        group: m['g'] as String?,
        weights: ((m['w'] as List?) ?? [])
            .map((v) => (v as num).toDouble())
            .toList(),
        ladder: ((m['l'] as List?) ?? []).map((v) {
          final pair = v as List;
          return ((pair[0] as num).toInt(), (pair[1] as num).toInt());
        }).toList(),
      );
    }).toList();
  } catch (_) {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class ProgressionScreen extends ConsumerStatefulWidget {
  const ProgressionScreen({super.key});

  @override
  ConsumerState<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends ConsumerState<ProgressionScreen> {
  String? _expandedCode;

  List<MapEntry<String, String>> _applyOrder(
    List<MapEntry<String, String>> all,
    List<String> order,
  ) {
    if (order.isEmpty) return all;
    final ordered = <MapEntry<String, String>>[];
    final rest = List<MapEntry<String, String>>.from(all);
    for (final code in order) {
      final idx = rest.indexWhere((e) => e.key == code);
      if (idx != -1) ordered.add(rest.removeAt(idx));
    }
    return [...ordered, ...rest];
  }

  void _onReorder(
    int oldIndex,
    int newIndex,
    List<MapEntry<String, String>> entries,
  ) {
    if (newIndex > oldIndex) newIndex--;
    final reordered = List<MapEntry<String, String>>.from(entries);
    reordered.insert(newIndex, reordered.removeAt(oldIndex));
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    if (uid.isEmpty) return;
    ref.read(firestoreServiceProvider).saveProgressionOrder(
          uid,
          reordered.map((e) => e.key).toList(),
        );
  }

  Future<void> _showExportDialog(Map<String, ProgressionConfig> configs) async {
    if (configs.isEmpty) return;
    final key = _encodeConfigs(configs);
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Экспорт прогрессии'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Скопируйте ключ. ИИ-модель может его изменить и вернуть обратно.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                key,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: key));
              messenger
                  .showSnackBar(const SnackBar(content: Text('Скопировано')));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Копировать'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportDialog() async {
    final ctrl = TextEditingController();
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final service = ref.read(firestoreServiceProvider);
    if (uid.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          String? error;
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Импорт прогрессии'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Вставьте ключ, полученный от ИИ-модели или из экспорта.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  maxLines: 4,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'Вставьте ключ...',
                    hintStyle:
                        const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    errorText: error,
                  ),
                  onChanged: (_) => setDlg(() => error = null),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Отмена',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final configs = _decodeConfigs(ctrl.text);
                  if (configs == null) {
                    setDlg(() => error = 'Неверный формат ключа');
                    return;
                  }
                  try {
                    for (final c in configs) {
                      await service.saveProgression(uid, c);
                    }
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      messenger.showSnackBar(SnackBar(
                          content: Text(
                              'Импортировано ${configs.length} упражнений')));
                    }
                  } catch (_) {
                    setDlg(() => error = 'Ошибка при сохранении');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Применить'),
              ),
            ],
          );
        },
      ),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dict = ref.watch(dictionaryProvider).valueOrNull;
    final configs = ref.watch(progressionsProvider).valueOrNull ?? {};
    final order = ref.watch(progressionOrderProvider).valueOrNull ?? [];
    final groups = ref.watch(groupsProvider).valueOrNull ?? [];
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final service = ref.read(firestoreServiceProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Прогрессия'),
        actions: [
          if (configs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.upload_outlined),
              tooltip: 'Экспорт',
              onPressed: () => _showExportDialog(configs),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Импорт',
              onPressed: _showImportDialog,
            ),
          ),
        ],
      ),
      body: (dict == null || dict.isEmpty)
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Сначала настройте Key 1 в настройках',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.textSecondary, height: 1.6),
                ),
              ),
            )
          : Builder(builder: (context) {
              final entries = _applyOrder(dict.sortedEntries, order);
              return ReorderableListView.builder(
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad + 80),
                buildDefaultDragHandles: false,
                proxyDecorator: (child, _, animation) => Material(
                  elevation: 8,
                  color: Colors.transparent,
                  shadowColor: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                ),
                onReorder: (o, n) => _onReorder(o, n, entries),
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final entry = entries[i];
                  final code = entry.key;
                  return Padding(
                    key: ValueKey(code),
                    padding: EdgeInsets.only(
                        bottom: i < entries.length - 1 ? 10 : 0),
                    child: _ExerciseProgressionCard(
                      code: code,
                      name: entry.value,
                      config: configs[code],
                      groups: groups,
                      isExpanded: _expandedCode == code,
                      onTap: () => setState(() {
                        _expandedCode =
                            _expandedCode == code ? null : code;
                      }),
                      onSave: (config) async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await service.saveProgression(uid, config);
                          if (mounted) setState(() => _expandedCode = null);
                        } catch (_) {
                          messenger.showSnackBar(const SnackBar(
                              content: Text('Не удалось сохранить')));
                        }
                      },
                      onReset: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await service.deleteProgression(uid, code);
                          if (mounted) setState(() => _expandedCode = null);
                        } catch (_) {
                          messenger.showSnackBar(const SnackBar(
                              content: Text('Не удалось сбросить')));
                        }
                      },
                      onAddGroup: (name) {
                        if (uid.isEmpty) return;
                        service.saveGroups(uid, [...groups, name]);
                      },
                      dragHandle: ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 4, vertical: 14),
                          child: Icon(Icons.drag_indicator_outlined,
                              color: AppColors.textMuted, size: 18),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ExerciseProgressionCard extends StatefulWidget {
  final String code;
  final String name;
  final ProgressionConfig? config;
  final List<String> groups;
  final bool isExpanded;
  final VoidCallback onTap;
  final void Function(ProgressionConfig) onSave;
  final VoidCallback onReset;
  final void Function(String) onAddGroup;
  final Widget? dragHandle;

  const _ExerciseProgressionCard({
    required this.code,
    required this.name,
    required this.config,
    required this.groups,
    required this.isExpanded,
    required this.onTap,
    required this.onSave,
    required this.onReset,
    required this.onAddGroup,
    this.dragHandle,
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

  Future<void> _promptAddGroup() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Новая группа'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Например: Спина'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name != null && name.isNotEmpty && !widget.groups.contains(name)) {
      widget.onAddGroup(name);
      setState(() => _group = name);
    }
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
          // ── Header ──────────────────────────────────────────────────────
          GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 8, top: 14, bottom: 14),
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
                      !widget.config!.isRepeating &&
                      widget.config!.ladder.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _chip('custom', AppColors.accent),
                  ],
                  if (widget.config?.group != null) ...[
                    const SizedBox(width: 4),
                    _chip(widget.config!.group!, AppColors.heatmap50),
                  ],
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: widget.isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                  if (widget.dragHandle != null) widget.dragHandle!,
                ],
              ),
            ),
          ),
          // ── Expandable body ─────────────────────────────────────────────
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
                          'Силовое (есть веса)',
                          _isStrength,
                          (v) => setState(() => _isStrength = v ?? false),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Группа чередования',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
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
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        // None
        _groupChip(null, 'Нет'),
        // Existing groups
        for (final g in widget.groups) _groupChip(g, g),
        // Add button
        GestureDetector(
          onTap: _promptAddGroup,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.textMuted.withValues(alpha: 0.35),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 14, color: AppColors.textMuted),
                SizedBox(width: 3),
                Text(
                  'Новая',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _groupChip(String? value, String label) {
    final selected = _group == value;
    return GestureDetector(
      onTap: () => setState(() => _group = value),
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
