import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/key_dictionary.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../services/haptic_service.dart';
import '../services/key_codec.dart';

/// Shows a native iOS action sheet (CupertinoActionSheet) with Key 1 / Key 2
/// clipboard import options. On other platforms falls back to a Material bottom sheet.
Future<void> showClipboardImportSheet(BuildContext context, WidgetRef ref) {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup(
      context: context,
      builder: (_) => _ClipboardSheet(ref: ref),
    );
  }
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _ClipboardSheet(ref: ref),
  );
}

class _ClipboardSheet extends StatefulWidget {
  final WidgetRef ref;
  const _ClipboardSheet({required this.ref});

  @override
  State<_ClipboardSheet> createState() => _ClipboardSheetState();
}

class _ClipboardSheetState extends State<_ClipboardSheet> {
  bool _busy = false;
  String? _status;
  bool _isError = false;

  Future<void> _importKey1() async {
    setState(() {
      _busy = true;
      _status = null;
      _isError = false;
    });
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
        _status = 'Key 1 сохранён — ${dict.entries.length} упражнений';
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
    setState(() {
      _busy = true;
      _status = null;
      _isError = false;
    });
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) throw Exception('Буфер обмена пуст');

      final dict = widget.ref.read(dictionaryProvider).valueOrNull;
      if (dict == null || dict.isEmpty) {
        throw Exception('Сначала настройте Key 1');
      }

      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime(monday.year, monday.month, monday.day);
      final workouts = KeyCodec.decodeKey2(text, dict, weekStart);
      if (workouts.isEmpty) throw Exception('Ключ не содержит тренировок');

      final uid = widget.ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) throw Exception('Не авторизован');

      final service = widget.ref.read(firestoreServiceProvider);
      for (final w in workouts) {
        await service.saveWorkout(uid, w);
      }
      widget.ref.invalidate(monthWorkoutsProvider);

      await HapticService.importSuccess();
      setState(() {
        _busy = false;
        _status = 'План загружен — ${workouts.length} тренировок';
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

  @override
  Widget build(BuildContext context) {
    final statusColor = _isError ? Colors.redAccent : CupertinoColors.activeGreen;

    return CupertinoActionSheet(
      title: const Text('Импорт из буфера'),
      message: _status != null
          ? Text(_status!, style: TextStyle(color: statusColor))
          : _busy
              ? const CupertinoActivityIndicator()
              : const Text('Скопируйте ключ и выберите тип'),
      actions: [
        CupertinoActionSheetAction(
          onPressed: _busy ? () {} : _importKey1,
          child: const Text('Импорт Key 1 (словарь)'),
        ),
        CupertinoActionSheetAction(
          onPressed: _busy ? () {} : _importKey2,
          child: const Text('Импорт Key 2 (план на неделю)'),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.of(context).pop();
            widget.ref.read(authServiceProvider).signOut();
          },
          child: const Text('Выйти'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDestructiveAction: false,
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Отмена'),
      ),
    );
  }
}
