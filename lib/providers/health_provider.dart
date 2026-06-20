import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

final _health = Health();

/// Calories consumed today from Apple Health (HealthKit / FatSecret sync).
/// Returns null while loading or if permission denied.
final caloriesConsumedProvider = FutureProvider.autoDispose<double?>((ref) async {
  final requested = await _health.requestAuthorization(
    [HealthDataType.DIETARY_ENERGY_CONSUMED],
    permissions: [HealthDataAccess.READ],
  );
  if (!requested) return null;

  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);

  final points = await _health.getHealthDataFromTypes(
    types: [HealthDataType.DIETARY_ENERGY_CONSUMED],
    startTime: start,
    endTime: now,
  );

  if (points.isEmpty) return null;

  final total = points.fold<double>(
    0,
    (sum, p) => sum + (p.value as NumericHealthValue).numericValue.toDouble(),
  );
  return total;
});
