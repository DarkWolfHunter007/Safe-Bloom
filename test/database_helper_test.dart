import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/features/tracking/domain/entities/user_profile.dart';

void main() {
  test('UserProfile toMap contains all SQL columns including initial_last_period_start', () {
    final now = DateTime.now();
    final profile = UserProfile(
      lastPeriodStart: now,
      initialLastPeriodStart: now.subtract(const Duration(days: 14)),
      avgCycleLength: 28,
      avgPeriodLength: 5,
      preferredGoal: 'Track Cycle',
    );

    final map = profile.toMap();

    expect(map['last_period_start'], equals(now.toIso8601String()));
    expect(map['initial_last_period_start'], equals(now.subtract(const Duration(days: 14)).toIso8601String()));
    expect(map['avg_cycle_length'], equals(28));
    expect(map['avg_period_length'], equals(5));
    expect(map['preferred_goal'], equals('Track Cycle'));
  });

  test('UserProfile.fromMap handles both map with initial_last_period_start and legacy map without it', () {
    final nowStr = DateTime.now().toIso8601String();
    final initialStr = DateTime.now().subtract(const Duration(days: 10)).toIso8601String();

    // Map WITH initial_last_period_start
    final newMap = {
      'last_period_start': nowStr,
      'initial_last_period_start': initialStr,
      'avg_cycle_length': 30,
      'avg_period_length': 6,
      'is_cloud_backup_enabled': 1,
      'preferred_goal': 'Conceive',
      'created_at': nowStr,
    };

    final newProfile = UserProfile.fromMap(newMap);
    expect(newProfile.lastPeriodStart.toIso8601String(), equals(nowStr));
    expect(newProfile.initialLastPeriodStart.toIso8601String(), equals(initialStr));

    // Legacy Map WITHOUT initial_last_period_start (falls back gracefully to last_period_start)
    final legacyMap = {
      'last_period_start': nowStr,
      'avg_cycle_length': 28,
      'avg_period_length': 5,
      'is_cloud_backup_enabled': 1,
      'created_at': nowStr,
    };

    final legacyProfile = UserProfile.fromMap(legacyMap);
    expect(legacyProfile.lastPeriodStart.toIso8601String(), equals(nowStr));
    expect(legacyProfile.initialLastPeriodStart.toIso8601String(), equals(nowStr));
  });
}
