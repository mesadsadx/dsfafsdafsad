import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../models/workout.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../services/key_codec.dart';
import '../widgets/native_liquid_glass.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _key1Ctrl = TextEditingController();
  final _key2Ctrl = TextEditingController();
  String? _key1Error;
  String? _key2Error;
  bool _key1Saving = false;
  bool _key2Saving = false;
  List<Workout>? _key2Preview;

  @override
  void initState() {
    super.initState();
    _key1Ctrl.addListener(() => setState(() {}));
    _key2Ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _key1Ctrl.dispose();
    _key2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _decodeAndSaveKey1() async {
    setState(() {
      _key1Error = null;
      _key1Saving = true;
    });
    try {
      final dict = KeyCodec.decodeKey1(_key1Ctrl.text.trim());
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) throw Exception('Не авторизован');
      await ref
          .read(firestoreServiceProvider)
          .saveKey1(uid, _key1Ctrl.text.trim(), dict);
      ref.invalidate(dictionaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Key 1 сохранён — ${dict.entries.length} упражнений'),
        ));
        _key1Ctrl.clear();
      }
    } catch (e) {
      if (mounted) setState(() => _key1Error = e.toString());
    } finally {
      if (mounted) setState(() => _key1Saving = false);
    }
  }

  Future<void> _previewKey2() async {
    setState(() {
      _key2Error = null;
      _key2Preview = null;
    });
    try {
      final dict = ref.read(dictionaryProvider).valueOrNull;
      if (dict == null || dict.isEmpty) {
        throw Exception('Сначала настройте Key 1');
      }
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime(monday.year, monday.month, monday.day);
      final workouts =
          KeyCodec.decodeKey2(_key2Ctrl.text.trim(), dict, weekStart);
      if (workouts.isEmpty) throw Exception('Ключ не содержит тренировок');
      setState(() => _key2Preview = workouts);
    } catch (e) {
      setState(() => _key2Error = e.toString());
    }
  }

  Future<void> _saveKey2() async {
    setState(() => _key2Saving = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) throw Exception('Не авторизован');
      final service = ref.read(firestoreServiceProvider);
      for (final workout in _key2Preview!) {
        await service.saveWorkout(uid, workout);
      }
      ref.invalidate(monthWorkoutsProvider);
      if (mounted) {
        setState(() {
          _key2Preview = null;
          _key2Saving = false;
        });
        _key2Ctrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('План на неделю загружен')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _key2Error = e.toString();
          _key2Saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final dictAsync = ref.watch(dictionaryProvider);
    final dict = dictAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          const _SectionLabel('Аккаунт'),
          _IOSGroup(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    backgroundColor: AppColors.surfaceVariant,
                    child: user?.photoURL == null
                        ? const Icon(Icons.person, color: AppColors.textSecondary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.displayName ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 15)),
                        Text(user?.email ?? '',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.read(authServiceProvider).signOut(),
                    child: const Text('Выйти',
                        style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ]),
          const Gap(28),
          const _SectionLabel('Key 1 — Словарь упражнений'),
          _IOSGroup(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: dict != null && !dict.isEmpty
                  ? Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 14, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Text('Загружено ${dict.entries.length} упражнений',
                          style: const TextStyle(
                              color: AppColors.accent, fontSize: 13)),
                    ])
                  : const Text('Key 1 не настроен',
                      style: TextStyle(color: Colors.orange, fontSize: 13)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: TextField(
                controller: _key1Ctrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Вставьте Base64 Key 1...',
                  errorText: _key1Error,
                  errorMaxLines: 3,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _GradientButton(
                onPressed: _key1Ctrl.text.trim().isEmpty || _key1Saving
                    ? null
                    : _decodeAndSaveKey1,
                loading: _key1Saving,
                label: 'Декодировать и сохранить',
              ),
            ),
          ]),
          const Gap(28),
          const _SectionLabel('Key 2 — План на неделю'),
          _IOSGroup(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: TextField(
                controller: _key2Ctrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Вставьте Base64 Key 2...',
                  errorText: _key2Error,
                  errorMaxLines: 3,
                ),
              ),
            ),
            if (_key2Preview != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _Key2Preview(workouts: _key2Preview!),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _key2Preview = null),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.divider)),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      child: _GradientButton(
                        onPressed: _key2Saving ? null : _saveKey2,
                        loading: _key2Saving,
                        label: 'Загрузить план',
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _GradientButton(
                  onPressed:
                      _key2Ctrl.text.trim().isEmpty ? null : _previewKey2,
                  loading: false,
                  label: 'Предпросмотр',
                ),
              ),
          ]),
        ],
      ),
    );
  }
}

// ── iOS-style grouped container ───────────────────────────────

class _IOSGroup extends StatelessWidget {
  final List<Widget> children;
  const _IOSGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return NativeLiquidGlass(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                const Divider(height: 1, thickness: 0.5,
                    indent: 16, color: AppColors.divider),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Gradient accent button ────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final String label;
  const _GradientButton(
      {required this.onPressed, required this.loading, required this.label});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF95D5B2), Color(0xFF52B788)],
                  )
                : null,
            color: enabled ? null : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : Text(label,
                    style: TextStyle(
                      color: enabled ? Colors.black : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    )),
          ),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Key2Preview extends StatelessWidget {
  final List<Workout> workouts;
  const _Key2Preview({required this.workouts});

  @override
  Widget build(BuildContext context) {
    const dayNames = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Предпросмотр плана',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const Gap(10),
            ...workouts.map((w) {
              final d = DateTime.parse(w.date);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dayNames[d.weekday]}, ${DateFormat('d MMM', 'ru').format(d)}',
                      style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w500,
                          fontSize: 13),
                    ),
                    const Gap(4),
                    ...w.exercises.map((e) => Padding(
                          padding: const EdgeInsets.only(left: 10, bottom: 2),
                          child: Text(
                            '• ${e.name}  ${e.weight == 0 ? 'вес тела' : '${e.weight.toInt()} кг'}  ×  ${e.sets}  ×  ${e.reps}',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                        )),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
