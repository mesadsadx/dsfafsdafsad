import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/progression_config.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';

final progressionsProvider =
    StreamProvider<Map<String, ProgressionConfig>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchProgressions(uid);
});

final progressionConfigProvider =
    Provider.autoDispose.family<ProgressionConfig?, String>((ref, code) {
  return ref.watch(progressionsProvider).valueOrNull?[code];
});
