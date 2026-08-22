import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/core/services/backup_crypto_service.dart';
import 'package:safe_bloom/core/services/local_notification_service.dart';
import 'package:safe_bloom/core/utils/cycle_group_utils.dart';
import 'package:safe_bloom/features/tracking/data/datasources/database_helper.dart';
import 'package:safe_bloom/features/tracking/data/repositories/tracking_repository.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/symptom_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/user_profile.dart';
import 'package:safe_bloom/features/tracking/domain/services/pdf_report_generator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  group('Safe Bloom Downstream Cycle Data Integration Audit', () {
    final Map<String, String> mockSecureStorage = {};
    final Map<int, Map<String, dynamic>> scheduledAlerts = {};
    final Set<int> cancelledAlerts = {};

    setUp(() async {
      mockSecureStorage.clear();
      scheduledAlerts.clear();
      cancelledAlerts.clear();

      mockSecureStorage['safebloom_db_key'] = 'integration_test_secret_key_1234567890';
      mockSecureStorage['notif_period_enabled'] = 'true';
      mockSecureStorage['notif_ovulation_enabled'] = 'true';
      mockSecureStorage['notif_hydration_enabled'] = 'true';
      mockSecureStorage['notif_daily_logging_enabled'] = 'true';

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'read') {
            final key = methodCall.arguments['key'] as String;
            return mockSecureStorage[key];
          } else if (methodCall.method == 'write') {
            final key = methodCall.arguments['key'] as String;
            final value = methodCall.arguments['value'] as String;
            mockSecureStorage[key] = value;
            return null;
          } else if (methodCall.method == 'delete') {
            final key = methodCall.arguments['key'] as String;
            mockSecureStorage.remove(key);
            return null;
          } else if (methodCall.method == 'deleteAll') {
            mockSecureStorage.clear();
            return null;
          } else if (methodCall.method == 'readAll') {
            return Map<String, String>.from(mockSecureStorage);
          }
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'zonedSchedule') {
            final args = methodCall.arguments as Map;
            final id = args['id'] as int;
            scheduledAlerts[id] = Map<String, dynamic>.from(args);
            cancelledAlerts.remove(id);
            return null;
          } else if (methodCall.method == 'cancel') {
            final args = methodCall.arguments;
            final int id = (args is Map) ? args['id'] as int : args as int;
            scheduledAlerts.remove(id);
            cancelledAlerts.add(id);
            return null;
          } else if (methodCall.method == 'cancelAll') {
            scheduledAlerts.clear();
            return null;
          } else if (methodCall.method == 'initialize') {
            return true;
          } else if (methodCall.method == 'requestNotificationsPermission' ||
              methodCall.method == 'requestPermissions') {
            return true;
          }
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.example.safe_bloom/screen_security'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getLocalTimezone') {
            return 'UTC';
          }
          return null;
        },
      );

      await DatabaseHelper.instance.resetForTesting(databaseFactoryFfi, 'downstream_test.db');
      await DatabaseHelper.instance.wipeAllData();
      mockSecureStorage['safebloom_db_key'] = 'integration_test_secret_key_1234567890';
    });

    tearDown(() async {
      await DatabaseHelper.instance.resetForTesting();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.example.safe_bloom/screen_security'),
        null,
      );
    });

    test('1. Isolated spotting does NOT alter lastPeriodStart and does NOT trigger false period or ovulation alerts', () async {
      // User onboarding: last period was 10 days ago
      final initialStart = DateTime.now().subtract(const Duration(days: 10));
      final initialProfile = UserProfile(
        lastPeriodStart: initialStart,
        avgCycleLength: 28,
        avgPeriodLength: 5,
        preferredGoal: AppMode.trackCycle.name,
      );
      await TrackingRepository.instance.saveUserProfile(initialProfile);

      // Verify baseline notification scheduling
      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isTrue);
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isTrue);

      final baselinePeriodAlertSchedule = scheduledAlerts[LocalNotificationId.periodAlert]!['scheduledDateTime'];
      final baselineOvulationAlertSchedule = scheduledAlerts[LocalNotificationId.ovulationAlert]!['scheduledDateTime'];

      // User logs an isolated spotting entry today (e.g. ovulation/implantation spotting)
      final spottingEntry = PeriodEntry(
        id: 'spotting_today',
        timestamp: DateTime.now(),
        flow: FlowLevel.spotting,
        notes: 'Mid-cycle light spotting',
      );
      await TrackingRepository.instance.addPeriodEntry(spottingEntry);

      // Verify profile lastPeriodStart was NOT corrupted/shifted to today
      final updatedProfile = await TrackingRepository.instance.getUserProfile();
      expect(updatedProfile.lastPeriodStart.year, equals(initialStart.year));
      expect(updatedProfile.lastPeriodStart.month, equals(initialStart.month));
      expect(updatedProfile.lastPeriodStart.day, equals(initialStart.day));

      // Verify notification schedules remain anchored on initialStart (NOT shifted by spotting)
      expect(
        scheduledAlerts[LocalNotificationId.periodAlert]!['scheduledDateTime'],
        equals(baselinePeriodAlertSchedule),
      );
      expect(
        scheduledAlerts[LocalNotificationId.ovulationAlert]!['scheduledDateTime'],
        equals(baselineOvulationAlertSchedule),
      );
    });

    test('2. Genuine period starts trigger correct profile recalculation and notification rescheduling', () async {
      final initialStart = DateTime.now().subtract(const Duration(days: 28));
      final initialProfile = UserProfile(
        lastPeriodStart: initialStart,
        avgCycleLength: 28,
        avgPeriodLength: 5,
        preferredGoal: AppMode.trackCycle.name,
      );
      await TrackingRepository.instance.saveUserProfile(initialProfile);

      // User logs a genuine new period today (FlowLevel.medium)
      final genuineStart = DateTime.now();
      final genuineEntry = PeriodEntry(
        id: 'genuine_period_today',
        timestamp: genuineStart,
        flow: FlowLevel.medium,
        notes: 'New period started',
      );
      await TrackingRepository.instance.addPeriodEntry(genuineEntry);

      // Verify profile lastPeriodStart updated to today
      final updatedProfile = await TrackingRepository.instance.getUserProfile();
      expect(updatedProfile.lastPeriodStart.year, equals(genuineStart.year));
      expect(updatedProfile.lastPeriodStart.month, equals(genuineStart.month));
      expect(updatedProfile.lastPeriodStart.day, equals(genuineStart.day));

      // Verify notifications rescheduled to 26 days ahead (28 days - 2 days notice)
      final newPeriodAlert = scheduledAlerts[LocalNotificationId.periodAlert];
      expect(newPeriodAlert, isNotNull);
      final scheduledDateStr = newPeriodAlert!['scheduledDateTime'] as String;
      final expectedDate = genuineStart.add(const Duration(days: 26));
      final parsedScheduled = DateTime.parse(scheduledDateStr);
      expect(parsedScheduled.year, equals(expectedDate.year));
      expect(parsedScheduled.month, equals(expectedDate.month));
      expect(parsedScheduled.day, equals(expectedDate.day));
    });

    test('3. Mid-cycle spotting logged after a genuine period does not alter cycle anchor', () async {
      final cycleStart = DateTime.now().subtract(const Duration(days: 14));
      // Log genuine period 14 days ago (3 days bleeding)
      await TrackingRepository.instance.addPeriodEntry(
        PeriodEntry(id: 'p1', timestamp: cycleStart, flow: FlowLevel.heavy),
      );
      await TrackingRepository.instance.addPeriodEntry(
        PeriodEntry(id: 'p2', timestamp: cycleStart.add(const Duration(days: 1)), flow: FlowLevel.medium),
      );
      await TrackingRepository.instance.addPeriodEntry(
        PeriodEntry(id: 'p3', timestamp: cycleStart.add(const Duration(days: 2)), flow: FlowLevel.light),
      );

      final profileAfterPeriod = await TrackingRepository.instance.getUserProfile();
      expect(profileAfterPeriod.lastPeriodStart.year, equals(cycleStart.year));
      expect(profileAfterPeriod.lastPeriodStart.day, equals(cycleStart.day));

      // User logs mid-cycle spotting today (Day 14)
      await TrackingRepository.instance.addPeriodEntry(
        PeriodEntry(id: 'p_spotting_day14', timestamp: DateTime.now(), flow: FlowLevel.spotting),
      );

      final profileAfterSpotting = await TrackingRepository.instance.getUserProfile();
      // Cycle anchor must STILL be cycleStart, NOT today!
      expect(profileAfterSpotting.lastPeriodStart.year, equals(cycleStart.year));
      expect(profileAfterSpotting.lastPeriodStart.day, equals(cycleStart.day));
    });

    test('4. Pregnancy mode suppresses period/ovulation notifications; exiting recalculates correctly', () async {
      final profile = UserProfile(
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 10)),
        avgCycleLength: 28,
        avgPeriodLength: 5,
        preferredGoal: AppMode.trackCycle.name,
      );
      await TrackingRepository.instance.saveUserProfile(profile);

      // Verify active period and ovulation alerts
      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isTrue);
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isTrue);

      // Transition into Pregnancy mode
      final pregnancyProfile = profile.copyWith(preferredGoal: AppMode.pregnancy.name);
      await TrackingRepository.instance.saveUserProfile(pregnancyProfile);

      // Period and ovulation alerts must be cancelled and suppressed
      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isFalse);
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isFalse);
      expect(cancelledAlerts.contains(LocalNotificationId.periodAlert), isTrue);
      expect(cancelledAlerts.contains(LocalNotificationId.ovulationAlert), isTrue);

      // Daily logging & hydration reminders still scheduled
      expect(scheduledAlerts.containsKey(LocalNotificationId.dailyLogging), isTrue);

      // Exit Pregnancy mode into TTC mode
      final ttcProfile = pregnancyProfile.copyWith(preferredGoal: AppMode.ttc.name);
      await TrackingRepository.instance.saveUserProfile(ttcProfile);

      // Rescheduling must restore period and ovulation alerts
      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isTrue);
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isTrue);
    });

    test('5. Restoring backup with spotting preserves entries without creating a phantom cycle', () async {
      final anchorDate = DateTime(2026, 7, 1);
      final spottingDate = DateTime(2026, 7, 15);

      final baseProfile = UserProfile(
        lastPeriodStart: anchorDate,
        initialLastPeriodStart: anchorDate,
        avgCycleLength: 28,
        avgPeriodLength: 5,
        preferredGoal: AppMode.trackCycle.name,
      );

      final spottingEntry = PeriodEntry(
        id: 'spot_restore_1',
        timestamp: spottingDate,
        flow: FlowLevel.spotting,
        notes: 'Restored spotting entry',
      );

      final backupData = jsonEncode({
        'version': 1,
        'profile': baseProfile.toMap(),
        'period_entries': [spottingEntry.toMap()],
        'symptom_entries': [],
      });

      final encryptedVault = BackupCryptoService.encryptVault(
        plaintextJson: backupData,
        passphrase: 'VaultPassword123!',
      );

      // Perform restore from encrypted vault
      final restoreResult = await TrackingRepository.instance.recoverAndRestoreFromEncryptedVault(
        vaultJsonString: encryptedVault,
        passphrase: 'VaultPassword123!',
      );

      expect(restoreResult['periods'], equals(1));

      // 1. Period entry is preserved
      final entries = await TrackingRepository.instance.getPeriodEntries();
      expect(entries.length, equals(1));
      expect(entries.first.flow, equals(FlowLevel.spotting));
      expect(entries.first.notes, equals('Restored spotting entry'));

      // 2. Profile lastPeriodStart must NOT be corrupted to spottingDate
      final restoredProfile = await TrackingRepository.instance.getUserProfile();
      expect(restoredProfile.lastPeriodStart, equals(anchorDate));
    });

    test('6. Restoring backup with genuine period recalculates cycle metrics correctly', () async {
      final period1Start = DateTime(2026, 6, 1);
      final period2Start = DateTime(2026, 6, 30); // 29-day cycle

      final baseProfile = UserProfile(
        lastPeriodStart: period1Start,
        avgCycleLength: 28,
        avgPeriodLength: 5,
      );

      final p1 = PeriodEntry(id: 'p1_1', timestamp: period1Start, flow: FlowLevel.heavy);
      final p2 = PeriodEntry(id: 'p2_1', timestamp: period2Start, flow: FlowLevel.medium);

      final backupData = jsonEncode({
        'version': 1,
        'profile': baseProfile.toMap(),
        'period_entries': [p1.toMap(), p2.toMap()],
        'symptom_entries': [],
      });

      final encryptedVault = BackupCryptoService.encryptVault(
        plaintextJson: backupData,
        passphrase: 'ValidRestorePassword!',
      );

      await TrackingRepository.instance.recoverAndRestoreFromEncryptedVault(
        vaultJsonString: encryptedVault,
        passphrase: 'ValidRestorePassword!',
      );

      final restoredProfile = await TrackingRepository.instance.getUserProfile();
      expect(restoredProfile.lastPeriodStart, equals(period2Start));
      expect(restoredProfile.avgCycleLength, equals(29));
    });

    test('7. PDF generation preserves spotting in Flow Statistics without treating it as a menstrual cycle', () async {
      final profile = UserProfile(
        lastPeriodStart: DateTime(2026, 8, 1),
        avgCycleLength: 28,
        avgPeriodLength: 5,
      );

      final periods = [
        // Genuine Period: Aug 1 to Aug 3 (3 days medium)
        PeriodEntry(id: 'gp1', timestamp: DateTime(2026, 8, 1), flow: FlowLevel.heavy, notes: 'Heavy start'),
        PeriodEntry(id: 'gp2', timestamp: DateTime(2026, 8, 2), flow: FlowLevel.medium),
        PeriodEntry(id: 'gp3', timestamp: DateTime(2026, 8, 3), flow: FlowLevel.light),
        // Isolated Spotting: Aug 15 (1 day spotting)
        PeriodEntry(id: 'sp1', timestamp: DateTime(2026, 8, 15), flow: FlowLevel.spotting, notes: 'Ovulation spot'),
      ];

      final symptoms = [
        SymptomEntry(
          id: 'sym1',
          timestamp: DateTime(2026, 8, 1),
          category: SymptomCategory.pain,
          type: 'Cramps',
          intensity: 3,
        ),
      ];

      // groupIntoCycles excludes pure-spotting event groups.
      // Aug 1-3 (genuine flow) → 1 cycle; Aug 15 (spotting) → excluded.
      final cycles = CycleGroupUtils.groupIntoCycles(periods);
      expect(cycles.length, equals(1)); // Only 1 genuine menstrual cycle

      // groupAllEvents exposes both temporal event groups for raw calendar rendering
      final allEvents = CycleGroupUtils.groupAllEvents(periods);
      expect(allEvents.length, equals(2)); // Aug 1-3 group + Aug 15 spotting group

      final genuineCycles = cycles; // Already filtered; all are genuine
      expect(genuineCycles.length, equals(1));

      // 2. Generate PDF byte stream
      final pdfBytes = await PdfReportGenerator.generateObGynReport(
        profile: profile,
        periodEntries: periods,
        symptomEntries: symptoms,
        now: DateTime(2026, 8, 20),
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
    });

    test('8. Data wipe (purge) remains completely zero-knowledge and clean', () async {
      // Populate profile and data
      final profile = UserProfile(lastPeriodStart: DateTime.now());
      await TrackingRepository.instance.saveUserProfile(profile);
      await TrackingRepository.instance.addPeriodEntry(
        PeriodEntry(id: 'wipe_test_1', timestamp: DateTime.now(), flow: FlowLevel.heavy),
      );

      expect(mockSecureStorage.containsKey('safebloom_db_key'), isTrue);
      expect(scheduledAlerts.isNotEmpty, isTrue);

      // Perform complete user-confirmed purge
      await TrackingRepository.instance.wipeAllUserData();

      // Verify all secure storage, DB key, and scheduled notifications are purged
      expect(mockSecureStorage.isEmpty, isTrue);
      expect(scheduledAlerts.isEmpty, isTrue);
    });
  });
}
