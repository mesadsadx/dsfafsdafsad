import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HapticService {
  static const _channel = MethodChannel('haptic_engine');

  static bool get _isNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> _invoke(String method) async {
    if (_isNative) {
      try {
        await _channel.invokeMethod(method);
      } catch (_) {}
    }
  }

  static Future<void> light() => _invoke('light');
  static Future<void> medium() => _invoke('medium');
  static Future<void> heavy() => _invoke('heavy');
  static Future<void> success() => _invoke('success');
  static Future<void> error() => _invoke('error');
  static Future<void> warning() => _invoke('warning');

  static Future<void> setComplete() => _invoke('set_complete');
  static Future<void> setUndo() => _invoke('set_undo');
  static Future<void> workoutDone() => _invoke('workout_done');
  static Future<void> importSuccess() => _invoke('import_success');
}
