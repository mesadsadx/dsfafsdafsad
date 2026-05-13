import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/theme.dart';
import '../models/key_dictionary.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../services/haptic_service.dart';
import '../services/key_codec.dart';

Future<void> showClipboardImportSheet(BuildContext context, WidgetRef ref) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (_) => _ImportDialog(ref: ref),
  );
}

class _ImportDialog extends StatefulWidget {
  final WidgetRef ref;
  const _ImportDialog({required this.ref});

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  bool _busy = false;
  String? _status;
  bool _isError = false;

  Future<void> _importKey1() async {
    setState(() { _busy = true; _status = null; });
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) throw Exception('Буфер обмена пуст');

      final dict = KeyCodec.decodeKey1(text);
      final uid = widget.ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) throw Exception('Не авторизован');

      await widget.ref.read(firestoreServiceProvider).saveKey1(uid, text, dict);
      widget.ref.invalidate(dictionaryProvider);

      await HapticService.importSuccess();
      setState(() {
        _busy = false;
        _status = '${dict.entries.length} упражнений загружено';
        _isError = false;
      });
    } catch (e) {
      await HapticService.error();
      setState(() {
        _busy = false;
        _status = e.toString().replaceFirst('Exception: ', '');
        _isError = true;
      });
    }
  }

  Future<void> _importKey2() async {
    setState(() { _busy = true; _status = null; });
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) throw Exception('Буфер обмена пуст');

      final dict = widget.ref.read(dictionaryProvider).valueOrNull;
      if (dict == null || dict.isEmpty) throw Exception('Сначала настройте Key 1');

      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime(monday.year, monday.month, monday.day);
      final workouts = KeyCodec.decodeKey2(text, dict, weekStart);
      if (workouts.isEmpty) throw Exception('Ключ не содержит тренировок');

      final uid = widget.ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) throw Exception('Не авторизован');

      final service = widget.ref.read(firestoreServiceProvider);
      for (final w in workouts) await service.saveWorkout(uid, w);
      widget.ref.invalidate(monthWorkoutsProvider);

      await HapticService.importSuccess();
      setState(() {
        _busy = false;
        _status = '${workouts.length} тренировок загружено';
        _isError = false;
      });
    } catch (e) {
      await HapticService.error();
      setState(() {
        _busy = false;
        _status = e.toString().replaceFirst('Exception: ', '');
        _isError = true;
      });
    }
  }

  void _signOut() {
    Navigator.of(context).pop();
    widget.ref.read(authServiceProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-screen blur backdrop
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(color: Colors.black.withOpacity(0.3)),
        ),
        // Menu card — top-right aligned under the buttons
        Positioned(
          top: MediaQuery.of(context).padding.top + kToolbarHeight - 4,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 240,
                  decoration: BoxDecoration(
                    color: const Color(0xCC1C1C1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_status != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            _status!,
                            style: TextStyle(
                              fontSize: 12,
                              color: _isError ? Colors.redAccent : AppColors.accent,
                            ),
                          ),
                        ),
                      _MenuItem(
                        icon: Icons.vpn_key_rounded,
                        label: 'Импорт Key 1',
                        sublabel: 'Словарь упражнений',
                        loading: _busy,
                        onTap: _busy ? null : _importKey1,
                      ),
                      _Divider(),
                      _MenuItem(
                        icon: Icons.calendar_month_rounded,
                        label: 'Импорт Key 2',
                        sublabel: 'План на неделю',
                        loading: _busy,
                        onTap: _busy ? null : _importKey2,
                      ),
                      _Divider(),
                      _MenuItem(
                        icon: Icons.logout_rounded,
                        label: 'Выйти',
                        destructive: true,
                        onTap: _signOut,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final bool destructive;
  final bool loading;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.sublabel,
    this.destructive = false,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.redAccent : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  if (sublabel != null)
                    Text(sublabel!,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppColors.accent),
              )
            else
              Icon(icon, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1, thickness: 0.5, color: Color(0x33FFFFFF), indent: 16);
  }
}
