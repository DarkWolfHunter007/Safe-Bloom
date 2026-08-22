import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/core/services/local_notification_service.dart';
import 'package:safe_bloom/features/tracking/domain/entities/user_profile.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  group('LocalNotificationService AppMode Transition & Cancellation Audit', () {
    final List<MethodCall> notificationCalls = [];
    final Map<int, Map<String, dynamic>> scheduledAlerts = {};
    final Set<int> cancelledAlerts = {};

    setUp(() {
      notificationCalls.clear();
      scheduledAlerts.clear();
      cancelledAlerts.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (MethodCall methodCall) async {
          notificationCalls.add(methodCall);
          if (methodCall.method == 'zonedSchedule') {
            final args = methodCall.arguments as Map;
            final id = args['id'] as int;
            scheduledAlerts[id] = Map<String, dynamic>.from(args);
            cancelledAlerts.remove(id);
            return null;
          } else if (methodCall.method == 'cancel') {
            final args = methodCall.arguments;
            final int id;
            if (args is Map) {
              id = args['id'] as int;
            } else {
              id = args as int;
            }
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
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'readAll') {
            return <String, String>{
              'notif_period_enabled': 'true',
              'notif_ovulation_enabled': 'true',
              'notif_hydration_enabled': 'true',
              'notif_daily_logging_enabled': 'true',
            };
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      );
    });

    test('Track Cycle mode schedules both period and ovulation notifications', () async {
      final trackCycleProfile = UserProfile(
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 5)),
        avgCycleLength: 28,
        avgPeriodLength: 5,
        preferredGoal: AppMode.trackCycle.name,
      );

      await LocalNotificationService.instance.rescheduleWithLatestData(trackCycleProfile);

      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isTrue,
          reason: 'Track Cycle mode must schedule period alerts');
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isTrue,
          reason: 'Track Cycle mode must schedule ovulation alerts');
    });

    test('TTC mode schedules both period and peak ovulation notifications', () async {
      final ttcProfile = UserProfile(
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 3)),
        avgCycleLength: 30,
        avgPeriodLength: 5,
        preferredGoal: AppMode.ttc.name,
      );

      await LocalNotificationService.instance.rescheduleWithLatestData(ttcProfile);

      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isTrue,
          reason: 'TTC mode must schedule period alerts');
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isTrue,
          reason: 'TTC mode must schedule peak ovulation/fertile window alerts');
    });

    test('Transition: Track Cycle -> Pregnancy explicitly CANCELS and suppresses cycle alerts', () async {
      // 1. Initial Track Cycle Mode
      final trackProfile = UserProfile(
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 2)),
        avgCycleLength: 28,
        avgPeriodLength: 5,
        preferredGoal: AppMode.trackCycle.name,
      );
      await LocalNotificationService.instance.rescheduleWithLatestData(trackProfile);

      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isTrue);
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isTrue);

      // 2. Transition into Pregnancy Mode
      final pregnancyProfile = trackProfile.copyWith(
        preferredGoal: AppMode.pregnancy.name,
      );
      await LocalNotificationService.instance.rescheduleWithLatestData(pregnancyProfile);

      // Verify that period and ovulation notifications are completely removed from scheduled state
      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isFalse,
          reason: 'Pregnancy mode must NEVER retain scheduled period notifications');
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isFalse,
          reason: 'Pregnancy mode must NEVER retain scheduled ovulation notifications');
      expect(cancelledAlerts.contains(LocalNotificationId.periodAlert), isTrue,
          reason: 'Period notification must be explicitly cancelled on entering Pregnancy mode');
      expect(cancelledAlerts.contains(LocalNotificationId.ovulationAlert), isTrue,
          reason: 'Ovulation notification must be explicitly cancelled on entering Pregnancy mode');

      // Wellness notifications (hydration, daily logging) should still remain active
      expect(scheduledAlerts.containsKey(LocalNotificationId.dailyLogging), isTrue);
      expect(scheduledAlerts.containsKey(LocalNotificationId.hydration11am), isTrue);
    });

    test('Transition: TTC -> Pregnancy explicitly CANCELS and suppresses cycle alerts', () async {
      // 1. Initial TTC Mode
      final ttcProfile = UserProfile(
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 4)),
        avgCycleLength: 29,
        avgPeriodLength: 5,
        preferredGoal: AppMode.ttc.name,
      );
      await LocalNotificationService.instance.rescheduleWithLatestData(ttcProfile);

      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isTrue);
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isTrue);

      // 2. Transition into Pregnancy Mode
      final pregnancyProfile = ttcProfile.copyWith(
        preferredGoal: AppMode.pregnancy.name,
      );
      await LocalNotificationService.instance.rescheduleWithLatestData(pregnancyProfile);

      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isFalse);
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isFalse);
      expect(cancelledAlerts.contains(LocalNotificationId.periodAlert), isTrue);
      expect(cancelledAlerts.contains(LocalNotificationId.ovulationAlert), isTrue);
    });

    test('Transition: Pregnancy -> Track Cycle correctly recalculates and schedules cycle alerts', () async {
      // 1. Initial Pregnancy Mode
      final pregnancyProfile = UserProfile(
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 10)),
        avgCycleLength: 28,
        avgPeriodLength: 5,
        preferredGoal: AppMode.pregnancy.name,
      );
      await LocalNotificationService.instance.rescheduleWithLatestData(pregnancyProfile);

      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isFalse);
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isFalse);

      // 2. Transition into Track Cycle Mode
      final trackProfile = pregnancyProfile.copyWith(
        preferredGoal: AppMode.trackCycle.name,
      );
      await LocalNotificationService.instance.rescheduleWithLatestData(trackProfile);

      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isTrue,
          reason: 'Switching out of Pregnancy into Track Cycle must restore period alerts');
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isTrue,
          reason: 'Switching out of Pregnancy into Track Cycle must restore ovulation alerts');
    });

    test('Transition: Pregnancy -> TTC correctly recalculates and schedules cycle & fertility alerts', () async {
      // 1. Initial Pregnancy Mode
      final pregnancyProfile = UserProfile(
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 8)),
        avgCycleLength: 30,
        avgPeriodLength: 5,
        preferredGoal: AppMode.pregnancy.name,
      );
      await LocalNotificationService.instance.rescheduleWithLatestData(pregnancyProfile);

      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isFalse);
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isFalse);

      // 2. Transition into TTC Mode
      final ttcProfile = pregnancyProfile.copyWith(
        preferredGoal: AppMode.ttc.name,
      );
      await LocalNotificationService.instance.rescheduleWithLatestData(ttcProfile);

      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isTrue,
          reason: 'Switching out of Pregnancy into TTC must restore period alerts');
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isTrue,
          reason: 'Switching out of Pregnancy into TTC must restore ovulation alerts');
    });

    test('Regression: No stale notification remains after rapid sequential mode changes', () async {
      var profile = UserProfile(
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 6)),
        avgCycleLength: 28,
        avgPeriodLength: 5,
        preferredGoal: AppMode.trackCycle.name,
      );

      // Cycle -> TTC -> Pregnancy -> Track Cycle -> Pregnancy
      profile = profile.copyWith(preferredGoal: AppMode.ttc.name);
      await LocalNotificationService.instance.rescheduleWithLatestData(profile);
      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isTrue);

      profile = profile.copyWith(preferredGoal: AppMode.pregnancy.name);
      await LocalNotificationService.instance.rescheduleWithLatestData(profile);
      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isFalse);
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isFalse);

      profile = profile.copyWith(preferredGoal: AppMode.trackCycle.name);
      await LocalNotificationService.instance.rescheduleWithLatestData(profile);
      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isTrue);
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isTrue);

      profile = profile.copyWith(preferredGoal: AppMode.pregnancy.name);
      await LocalNotificationService.instance.rescheduleWithLatestData(profile);
      expect(scheduledAlerts.containsKey(LocalNotificationId.periodAlert), isFalse);
      expect(scheduledAlerts.containsKey(LocalNotificationId.ovulationAlert), isFalse);
    });
  });
}
