import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/core/services/local_notification_service.dart';

void main() {
  group('LocalNotificationService Unit Tests', () {
    test('NotificationSettings defaults to privacy-first settings', () {
      const settings = NotificationSettings();
      expect(settings.periodAlertEnabled, isTrue);
      expect(settings.ovulationAlertEnabled, isTrue);
      expect(settings.hydrationReminderEnabled, isTrue);
      expect(settings.newArticlesAlertEnabled, isTrue);
      expect(settings.discreetModeEnabled, isTrue);
      expect(settings.dailyLoggingReminderEnabled, isTrue);
      expect(settings.dailyLoggingReminderHour, equals(20));
      expect(settings.dailyLoggingReminderMinute, equals(0));
    });

    test('formatNotificationBody returns discreet text when discreetMode is true', () {
      final text = LocalNotificationService.formatNotificationBody(
        sensitiveBody: 'Expected Period in 2 days.',
        discreetBody: 'Safe Bloom Check-in: Self-care reminder.',
        isDiscreet: true,
      );

      expect(text, equals('Safe Bloom Check-in: Self-care reminder.'));
    });

    test('formatNotificationBody returns detailed text when discreetMode is false', () {
      final text = LocalNotificationService.formatNotificationBody(
        sensitiveBody: 'Expected Period in 2 days.',
        discreetBody: 'Safe Bloom Check-in: Self-care reminder.',
        isDiscreet: false,
      );

      expect(text, equals('Expected Period in 2 days.'));
    });
  });
}
