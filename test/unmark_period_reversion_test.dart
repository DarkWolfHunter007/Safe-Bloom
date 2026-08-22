import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/features/tracking/data/datasources/database_helper.dart';
import 'package:safe_bloom/features/tracking/data/repositories/tracking_repository.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/user_profile.dart';
import 'package:safe_bloom/features/tracking/domain/services/cycle_calculator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        if (call.method == 'read') return 'test_encryption_key_32_bytes_long!!';
        if (call.method == 'readAll') return {};
        return null;
      },
    );
  });

  test('UserProfile retains initialLastPeriodStart when created', () {
    final onboardingDate = DateTime(2026, 8, 1);
    final profile = UserProfile(lastPeriodStart: onboardingDate);

    expect(profile.lastPeriodStart, equals(onboardingDate));
    expect(profile.initialLastPeriodStart, equals(onboardingDate));
  });

  test('TrackingRepository unmarking period reverts lastPeriodStart to initialLastPeriodStart in database', () async {
    final Map<String, String> mockSecureStorage = {
      'safebloom_db_key': 'test_encryption_key_32_bytes_long!!',
      'notif_period_enabled': 'false',
      'notif_ovulation_enabled': 'false',
      'notif_hydration_enabled': 'false',
      'notif_daily_logging_enabled': 'false',
    };

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        if (call.method == 'read') return mockSecureStorage[call.arguments['key']];
        if (call.method == 'readAll') return mockSecureStorage;
        if (call.method == 'write') {
          mockSecureStorage[call.arguments['key'] as String] = call.arguments['value'] as String;
          return null;
        }
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall call) async => null,
    );

    await DatabaseHelper.instance.resetForTesting(databaseFactoryFfi, 'reversion_test_${DateTime.now().microsecondsSinceEpoch}.db');
    await DatabaseHelper.instance.wipeAllData();

    final onboardingDate = DateTime(2026, 8, 1);
    final initialProfile = UserProfile(
      lastPeriodStart: onboardingDate,
      initialLastPeriodStart: onboardingDate,
      avgCycleLength: 28,
      avgPeriodLength: 5,
    );
    await DatabaseHelper.instance.saveUserProfile(initialProfile);

    // Initial state
    final profile0 = await TrackingRepository.instance.getUserProfile();
    expect(profile0.lastPeriodStart, equals(onboardingDate));
    expect(profile0.initialLastPeriodStart, equals(onboardingDate));

    // Log a new period today (August 14)
    final today = DateTime(2026, 8, 14);
    final entry = PeriodEntry(
      id: 'entry_today',
      timestamp: today,
      flow: FlowLevel.heavy,
    );
    await TrackingRepository.instance.addPeriodEntry(entry);

    // Profile updates to today
    final profileDuring = await TrackingRepository.instance.getUserProfile();
    expect(profileDuring.lastPeriodStart.day, equals(14));

    // Unmark / delete the period entry
    await TrackingRepository.instance.deletePeriodEntry(entry.id);

    // Profile must revert in database to initialLastPeriodStart (August 1)
    final profileAfter = await TrackingRepository.instance.getUserProfile();
    expect(profileAfter.lastPeriodStart, equals(onboardingDate));
    expect(profileAfter.initialLastPeriodStart, equals(onboardingDate));
  });
}
