import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../models/key_dictionary.dart';
import '../models/workout.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../services/key_codec.dart';

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
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionLabel('Аккаунт'),
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(user?.displayName ?? ''),
              subtitle: Text(user?.email ?? '',
                  style: const TextStyle(color: AppColors.textSecondary)),
              trailing: TextButton(
                onPressed: () =>
                    ref.read(authServiceProvider).signOut(),
                child: const Text('Выйти',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ),
          ),
          const Gap(28),
          _SectionLabel('Key 1 — Словарь упражнений'),
          if (dict != null && !dict.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '✓ Загружено ${dict.entries.length} упражнений',
                style:
                    const TextStyle(color: AppColors.accent, fontSize: 13),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Key 1 не настроен — вставьте строку ниже',
                style: TextStyle(color: Colors.orange, fontSize: 13),
              ),
            ),
          TextField(
            controller: _key1Ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Вставьте Base64 Key 1...',
              errorText: _key1Error,
              errorMaxLines: 3,
            ),
          ),
          const Gap(8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _key1Ctrl.text.trim().isEmpty || _key1Saving
                      ? null
                      : _decodeAndSaveKey1,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
              ),
              child: _key1Saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('Декодировать и сохранить'),
            ),
          ),
          const Gap(28),
          _SectionLabel('Key 2 — План на неделю'),
          TextField(
            controller: _key2Ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Вставьте Base64 Key 2...',
              errorText: _key2Error,
              errorMaxLines: 3,
            ),
          ),
          const Gap(8),
          if (_key2Preview != null) ...[
            _Key2Preview(workouts: _key2Preview!),
            const Gap(10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _key2Preview = null),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary),
                    child: const Text('Отмена'),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _key2Saving ? null : _saveKey2,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                    ),
                    child: _key2Saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Text('Загрузить план'),
                  ),
                ),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _key2Ctrl.text.trim().isEmpty
                    ? null
                    : _previewKey2,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Предпросмотр'),
              ),
            ),
        ],
      ),
    );
  }
}

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
