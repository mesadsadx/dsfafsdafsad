import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/key_dictionary.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

final dictionaryProvider = FutureProvider<KeyDictionary?>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return null;
  return ref.watch(firestoreServiceProvider).loadDictionary(uid);
});
