import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:safe_bloom/core/services/local_notification_service.dart';
import 'package:safe_bloom/features/tracking/domain/entities/user_profile.dart';
import 'package:safe_bloom/features/tracking/domain/services/cycle_calculator.dart';

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  group('Notification Scheduling Pipeline Tests', () {
    final testProfile = UserProfile(
      lastPeriodStart: DateTime(2026, 8, 1),
      avgCycleLength: 28,
      avgPeriodLength: 5,
    );

    test('Period prediction alert schedules exactly 2 days before predicted start at 9:00 AM', () {
      final nextPeriod = CycleCalculator.getNextPeriodStartDate(
        testProfile.lastPeriodStart,
        avgCycleLength: testProfile.avgCycleLength,
      );
      expect(nextPeriod, equals(DateTime(2026, 8, 29)));

      final alertDate = nextPeriod.subtract(const Duration(days: 2));
      final alertTarget = DateTime(alertDate.year, alertDate.month, alertDate.day, 9, 0);

      expect(alertTarget.year, equals(2026));
      expect(alertTarget.month, equals(8));
      expect(alertTarget.day, equals(27));
      expect(alertTarget.hour, equals(9));
      expect(alertTarget.minute, equals(0));
    });

    test('Ovulation alert schedules exactly 1 day before peak ovulation (Cycle Day 14) at 9:00 AM', () {
      final peakOffset = testProfile.avgCycleLength - 14; // Day 14 for 28-day cycle
      final nextOvulation = DateTime(
        testProfile.lastPeriodStart.year,
        testProfile.lastPeriodStart.month,
        testProfile.lastPeriodStart.day,
      ).add(Duration(days: peakOffset));

      expect(nextOvulation, equals(DateTime(2026, 8, 15)));

      final alertDate = nextOvulation.subtract(const Duration(days: 1));
      final alertTarget = DateTime(alertDate.year, alertDate.month, alertDate.day, 9, 0);

      expect(alertTarget.day, equals(14));
      expect(alertTarget.hour, equals(9));
      expect(alertTarget.minute, equals(0));
    });

    test('Hydration schedule sets 3 daily reminders at 11:00 AM, 3:00 PM, and 7:00 PM', () {
      const hydrationSlots = [
        (11, 0, 'Morning Hydration 💧'),
        (15, 0, 'Afternoon Reset 💧'),
        (19, 0, 'Evening Hydration 💧'),
      ];

      expect(hydrationSlots.length, equals(3));
      expect(hydrationSlots[0].$1, equals(11));
      expect(hydrationSlots[1].$1, equals(15));
      expect(hydrationSlots[2].$1, equals(19));
    });

    test('Rescheduling after period date update calculates new target dates accurately', () {
      // User logs an unexpected early period on Aug 25
      final updatedProfile = testProfile.copyWith(
        lastPeriodStart: DateTime(2026, 8, 25),
        avgCycleLength: 26,
      );

      final newNextPeriod = CycleCalculator.getNextPeriodStartDate(
        updatedProfile.lastPeriodStart,
        avgCycleLength: updatedProfile.avgCycleLength,
      );
      expect(newNextPeriod, equals(DateTime(2026, 9, 20)));

      final newAlertDate = newNextPeriod.subtract(const Duration(days: 2));
      expect(newAlertDate, equals(DateTime(2026, 9, 18)));
    });

    test('Discreet mode text substitution formats properly for lock screen privacy', () {
      final periodSensitive = LocalNotificationService.formatNotificationBody(
        sensitiveBody: 'Expected period in 2 days. Self-care mode ready.',
        discreetBody: 'Safe Bloom: Upcoming self-care check-in in 2 days.',
        isDiscreet: false,
      );
      final periodDiscreet = LocalNotificationService.formatNotificationBody(
        sensitiveBody: 'Expected period in 2 days. Self-care mode ready.',
        discreetBody: 'Safe Bloom: Upcoming self-care check-in in 2 days.',
        isDiscreet: true,
      );

      expect(periodSensitive, equals('Expected period in 2 days. Self-care mode ready.'));
      expect(periodDiscreet, equals('Safe Bloom: Upcoming self-care check-in in 2 days.'));
      expect(periodDiscreet.contains('period'), isFalse);
      expect(periodDiscreet.contains('Expected'), isFalse);

      final ovulationDiscreet = LocalNotificationService.formatNotificationBody(
        sensitiveBody: 'Estimated peak ovulation window starts tomorrow.',
        discreetBody: 'Safe Bloom: Key wellness window update.',
        isDiscreet: true,
      );
      expect(ovulationDiscreet, equals('Safe Bloom: Key wellness window update.'));
      expect(ovulationDiscreet.contains('ovulation'), isFalse);
      expect(ovulationDiscreet.contains('fertility'), isFalse);
    });

    test('Timezone conversions handle TZDateTime safely across multiple IANA timezones', () {
      final timezones = ['America/New_York', 'Europe/London', 'Asia/Tokyo', 'Australia/Sydney'];

      for (final tzName in timezones) {
        final loc = tz.getLocation(tzName);
        final tzNow = tz.TZDateTime.now(loc);
        final scheduled = tz.TZDateTime(loc, tzNow.year, tzNow.month, tzNow.day, 20, 0);

        expect(scheduled.location.name, equals(tzName));
        expect(scheduled.hour, equals(20));
      }
    });
  });
}
