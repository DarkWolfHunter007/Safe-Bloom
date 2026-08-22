import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'secure_storage_service.dart';
import '../../features/tracking/data/datasources/database_helper.dart';
import '../../features/tracking/domain/entities/user_profile.dart';
import '../../features/tracking/domain/services/cycle_calculator.dart';

// ── Notification channel & ID constants ─────────────────────────────────────
class LocalNotificationId {
  static const int test = 0;
  static const int dailyLogging = 101;
  static const int periodAlert = 102;
  static const int ovulationAlert = 103;
  static const int hydration11am = 104;
  static const int hydration3pm = 105;
  static const int hydration7pm = 106;
  static const int newArticle = 107;
}

typedef _NotifId = LocalNotificationId;

class _Channel {
  static const AndroidNotificationDetails alerts = AndroidNotificationDetails(
    'safe_bloom_alerts',
    'Encrypted Health & Cycle Alerts',
    channelDescription: 'Local encrypted cycle predictions and fertility reminders',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const AndroidNotificationDetails dailyLogging = AndroidNotificationDetails(
    'safe_bloom_daily_logging',
    'Daily Health Log Reminders',
    channelDescription: 'Local encrypted daily symptom and logging reminders',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const AndroidNotificationDetails hydration = AndroidNotificationDetails(
    'safe_bloom_hydration',
    'Hydration Reminders',
    channelDescription: 'Gentle hydration check-ins to support hormonal balance',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const AndroidNotificationDetails articles = AndroidNotificationDetails(
    'safe_bloom_articles',
    'Health & Wellness Guides',
    channelDescription: 'Notifications for newly published health articles and cycle guides',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );
}

// ── NotificationSettings model ───────────────────────────────────────────────

class NotificationSettings {
  final bool periodAlertEnabled;
  final bool ovulationAlertEnabled;
  final bool hydrationReminderEnabled;
  final bool newArticlesAlertEnabled;
  final bool discreetModeEnabled;
  final bool dailyLoggingReminderEnabled;
  final int dailyLoggingReminderHour;
  final int dailyLoggingReminderMinute;

  const NotificationSettings({
    this.periodAlertEnabled = true,
    this.ovulationAlertEnabled = true,
    this.hydrationReminderEnabled = true,
    this.newArticlesAlertEnabled = true,
    this.discreetModeEnabled = true,
    this.dailyLoggingReminderEnabled = true,
    this.dailyLoggingReminderHour = 20,
    this.dailyLoggingReminderMinute = 0,
  });

  NotificationSettings copyWith({
    bool? periodAlertEnabled,
    bool? ovulationAlertEnabled,
    bool? hydrationReminderEnabled,
    bool? newArticlesAlertEnabled,
    bool? discreetModeEnabled,
    bool? dailyLoggingReminderEnabled,
    int? dailyLoggingReminderHour,
    int? dailyLoggingReminderMinute,
  }) {
    return NotificationSettings(
      periodAlertEnabled: periodAlertEnabled ?? this.periodAlertEnabled,
      ovulationAlertEnabled: ovulationAlertEnabled ?? this.ovulationAlertEnabled,
      hydrationReminderEnabled: hydrationReminderEnabled ?? this.hydrationReminderEnabled,
      newArticlesAlertEnabled: newArticlesAlertEnabled ?? this.newArticlesAlertEnabled,
      discreetModeEnabled: discreetModeEnabled ?? this.discreetModeEnabled,
      dailyLoggingReminderEnabled: dailyLoggingReminderEnabled ?? this.dailyLoggingReminderEnabled,
      dailyLoggingReminderHour: dailyLoggingReminderHour ?? this.dailyLoggingReminderHour,
      dailyLoggingReminderMinute: dailyLoggingReminderMinute ?? this.dailyLoggingReminderMinute,
    );
  }
}

// ── Storage keys ─────────────────────────────────────────────────────────────

class _Key {
  static const String period = 'notif_period_enabled';
  static const String ovulation = 'notif_ovulation_enabled';
  static const String hydration = 'notif_hydration_enabled';
  static const String newArticles = 'notif_new_articles_enabled';
  static const String discreet = 'notif_discreet_enabled';
  static const String dailyLogging = 'notif_daily_logging_enabled';
  static const String dailyLoggingHour = 'notif_daily_logging_hour';
  static const String dailyLoggingMinute = 'notif_daily_logging_minute';
}

// ── Service ──────────────────────────────────────────────────────────────────

class LocalNotificationService {
  static final LocalNotificationService instance = LocalNotificationService._internal();
  final FlutterSecureStorage _storage = SafeBloomSecureStorage.instance;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  LocalNotificationService._internal();

  /// Must be called once from main() before runApp().
  /// Initialises the plugin, timezone data, and requests OS permission.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Timezone setup via native platform channel with safe UTC fallback
      tz.initializeTimeZones();
      String timeZoneName = 'UTC';
      try {
        const channel = MethodChannel('com.example.safe_bloom/screen_security');
        final String? nativeTz = await channel.invokeMethod<String>('getLocalTimezone');
        if (nativeTz != null && nativeTz.isNotEmpty) {
          timeZoneName = nativeTz;
        }
      } catch (e) {
        timeZoneName = DateTime.now().timeZoneName;
      }
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      try {
        FlutterLocalNotificationsPlatform.instance;
      } catch (_) {
        FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _plugin.initialize(
        const InitializationSettings(android: androidSettings, iOS: iosSettings),
      );

      _isInitialized = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Explicitly prompts the OS for notification permission on Android 13+ & iOS.
  Future<bool?> requestPermission() async {
    await initialize();
    try {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        return await androidImpl.requestNotificationsPermission();
      }

      final iosImpl = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosImpl != null) {
        return await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Checks whether the OS currently allows notifications for this app.
  Future<bool> areNotificationsEnabled() async {
    try {
      const channel = MethodChannel('com.example.safe_bloom/screen_security');
      final bool? nativeEnabled = await channel.invokeMethod<bool>('areNotificationsEnabled');
      if (nativeEnabled != null) return nativeEnabled;
    } catch (_) {}

    await initialize();
    try {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final enabled = await androidImpl.areNotificationsEnabled();
        return enabled ?? true;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the system app notification settings screen.
  Future<void> openNotificationSettings() async {
    try {
      const channel = MethodChannel('com.example.safe_bloom/screen_security');
      await channel.invokeMethod('openNotificationSettings');
    } catch (e) {
      debugPrint('Error opening notification settings: $e');
    }
  }

  // ── Settings persistence ────────────────────────────────────────────────

  /// Reads all notification settings in a single IPC round-trip via readAll().
  Future<NotificationSettings> getSettings() async {
    final all = await _storage.readAll();

    final period = all[_Key.period] != 'false';
    final ovulation = all[_Key.ovulation] != 'false';
    final hydration = all[_Key.hydration] != 'false';
    final newArticles = all[_Key.newArticles] != 'false';
    final discreet = all[_Key.discreet] != 'false';
    final dailyLogging = all[_Key.dailyLogging] != 'false';
    final hour = int.tryParse(all[_Key.dailyLoggingHour] ?? '') ?? 20;
    final minute = int.tryParse(all[_Key.dailyLoggingMinute] ?? '') ?? 0;

    return NotificationSettings(
      periodAlertEnabled: period,
      ovulationAlertEnabled: ovulation,
      hydrationReminderEnabled: hydration,
      newArticlesAlertEnabled: newArticles,
      discreetModeEnabled: discreet,
      dailyLoggingReminderEnabled: dailyLogging,
      dailyLoggingReminderHour: hour,
      dailyLoggingReminderMinute: minute,
    );
  }

  /// Persists the full settings object and reschedules all active notifications.
  Future<void> saveSettings(NotificationSettings settings) async {
    await _storage.write(key: _Key.period, value: settings.periodAlertEnabled.toString());
    await _storage.write(key: _Key.ovulation, value: settings.ovulationAlertEnabled.toString());
    await _storage.write(key: _Key.hydration, value: settings.hydrationReminderEnabled.toString());
    await _storage.write(key: _Key.newArticles, value: settings.newArticlesAlertEnabled.toString());
    await _storage.write(key: _Key.discreet, value: settings.discreetModeEnabled.toString());
    await _storage.write(key: _Key.dailyLogging, value: settings.dailyLoggingReminderEnabled.toString());
    await _storage.write(key: _Key.dailyLoggingHour, value: settings.dailyLoggingReminderHour.toString());
    await _storage.write(key: _Key.dailyLoggingMinute, value: settings.dailyLoggingReminderMinute.toString());

    await _rescheduleAll(settings);
  }

  /// Triggers a background reschedule using current settings and latest database profile.
  Future<void> rescheduleWithLatestData([UserProfile? profile]) async {
    final settings = await getSettings();
    await _rescheduleAll(settings, profile);
  }

  // ── Scheduling Engine ───────────────────────────────────────────────────

  /// Cancels and reschedules all notifications based on settings and user cycle predictions.
  Future<void> _rescheduleAll(NotificationSettings settings, [UserProfile? profile]) async {
    final ok = await initialize();
    if (!ok) return;

    try {
      // 1. Daily Logging Reminder
      await _plugin.cancel(_NotifId.dailyLogging);
      if (settings.dailyLoggingReminderEnabled) {
        await _scheduleDaily(
          id: _NotifId.dailyLogging,
          title: settings.discreetModeEnabled ? 'Safe Bloom Check-in' : 'Daily Health Log Reminder',
          body: formatNotificationBody(
            sensitiveBody: "Time to log today's symptoms, period flow, and hydration!",
            discreetBody: 'Safe Bloom: Daily self-care check-in ready.',
            isDiscreet: settings.discreetModeEnabled,
          ),
          hour: settings.dailyLoggingReminderHour,
          minute: settings.dailyLoggingReminderMinute,
          channel: _Channel.dailyLogging,
        );
      }

      // 2. Hydration Reminders (11:00 AM, 3:00 PM, 7:00 PM)
      await _plugin.cancel(_NotifId.hydration11am);
      await _plugin.cancel(_NotifId.hydration3pm);
      await _plugin.cancel(_NotifId.hydration7pm);
      if (settings.hydrationReminderEnabled) {
        const hydrationTimes = [
          (_NotifId.hydration11am, 11, 0, 'Morning Hydration 💧', 'Time for a fresh glass of water to keep your body energized.'),
          (_NotifId.hydration3pm, 15, 0, 'Afternoon Reset 💧', 'Stay refreshed — sip some water to support focus and digestion.'),
          (_NotifId.hydration7pm, 19, 0, 'Evening Hydration 💧', 'Hydrate before dinner to maintain healthy cycle hydration.'),
        ];

        for (final item in hydrationTimes) {
          await _scheduleDaily(
            id: item.$1,
            title: item.$4,
            body: item.$5,
            hour: item.$2,
            minute: item.$3,
            channel: _Channel.hydration,
          );
        }
      }

      // 3. Cycle & Fertility Predictions (Track Cycle & TTC modes ONLY)
      await _plugin.cancel(_NotifId.periodAlert);
      await _plugin.cancel(_NotifId.ovulationAlert);

      final userProfile = profile ?? await DatabaseHelper.instance.getUserProfile();
      if (userProfile == null) return;

      // Pregnancy mode must NEVER schedule period prediction, ovulation, or fertile-window notifications.
      // The explicit cancellations above ensure that switching into Pregnancy mode removes any previously scheduled alarms immediately.
      if (userProfile.appMode == AppMode.pregnancy) {
        return;
      }

      final now = DateTime.now();

      // Period Prediction Alert (2 days before predicted start at 9:00 AM)
      if (settings.periodAlertEnabled) {
        DateTime nextPeriod = CycleCalculator.getNextPeriodStartDate(
          userProfile.lastPeriodStart,
          avgCycleLength: userProfile.avgCycleLength,
        );
        while (nextPeriod.isBefore(now)) {
          nextPeriod = nextPeriod.add(Duration(days: userProfile.avgCycleLength));
        }

        final alertDate = nextPeriod.subtract(const Duration(days: 2));
        final alertTarget = DateTime(alertDate.year, alertDate.month, alertDate.day, 9, 0);

        if (alertTarget.isAfter(now)) {
          await _scheduleExactOneShot(
            id: _NotifId.periodAlert,
            title: settings.discreetModeEnabled ? 'Safe Bloom Reminder' : 'Period Prediction Alert',
            body: formatNotificationBody(
              sensitiveBody: 'Expected period in 2 days. Self-care mode ready.',
              discreetBody: 'Safe Bloom: Upcoming self-care check-in in 2 days.',
              isDiscreet: settings.discreetModeEnabled,
            ),
            targetDateTime: alertTarget,
            channel: _Channel.alerts,
          );
        }
      }

      // Ovulation Window Alert (1 day before peak ovulation at 9:00 AM)
      // peakOffset matches getPredictedPeakOvulationDates: (avgCycleLength - 14) - 1
      // This places nextOvulation on the same calendar day as the peak marker (Day = ovulationDay),
      // so the alert fires exactly 1 day before the calendar's peak ovulation marker.
      if (settings.ovulationAlertEnabled) {
        final peakOffset = (userProfile.avgCycleLength - 14) - 1;
        DateTime nextOvulation = DateTime(
          userProfile.lastPeriodStart.year,
          userProfile.lastPeriodStart.month,
          userProfile.lastPeriodStart.day,
        ).add(Duration(days: peakOffset));

        while (nextOvulation.isBefore(now)) {
          nextOvulation = nextOvulation.add(Duration(days: userProfile.avgCycleLength));
        }

        final alertDate = nextOvulation.subtract(const Duration(days: 1));
        final alertTarget = DateTime(alertDate.year, alertDate.month, alertDate.day, 9, 0);

        if (alertTarget.isAfter(now)) {
          await _scheduleExactOneShot(
            id: _NotifId.ovulationAlert,
            title: settings.discreetModeEnabled ? 'Safe Bloom Check-in' : 'Peak Fertility Alert',
            body: formatNotificationBody(
              sensitiveBody: 'Estimated peak ovulation window starts tomorrow.',
              discreetBody: 'Safe Bloom: Key wellness window update.',
              isDiscreet: settings.discreetModeEnabled,
            ),
            targetDateTime: alertTarget,
            channel: _Channel.alerts,
          );
        }
      }
    } catch (_) {}
  }

  /// Schedules a repeating daily notification at the given local time.
  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required AndroidNotificationDetails channel,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfTime(hour, minute),
        NotificationDetails(
          android: channel,
          iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          _nextInstanceOfTime(hour, minute),
          NotificationDetails(
            android: channel,
            iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.inexact,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (_) {}
    }
  }

  /// Schedules a one-shot notification at a precise future date and time.
  Future<void> _scheduleExactOneShot({
    required int id,
    required String title,
    required String body,
    required DateTime targetDateTime,
    required AndroidNotificationDetails channel,
  }) async {
    final tzDate = tz.TZDateTime.from(targetDateTime, tz.local);
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        NotificationDetails(
          android: channel,
          iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tzDate,
          NotificationDetails(
            android: channel,
            iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.inexact,
        );
      } catch (_) {}
    }
  }

  /// Returns the next occurrence of the given local time as a TZDateTime.
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Cancels all pending notifications (used on zero-knowledge data wipe).
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// Triggers a local notification when new educational articles/guides are published.
  Future<bool> notifyNewArticles(List<String> articleTitles) async {
    if (articleTitles.isEmpty) return false;
    final ok = await initialize();
    if (!ok) return false;

    try {
      final settings = await getSettings();
      if (!settings.newArticlesAlertEnabled) return false;

      final title = settings.discreetModeEnabled
          ? 'Safe Bloom: New Guide Available'
          : 'New Health Guide Published 📚';

      final String body;
      if (settings.discreetModeEnabled) {
        body = articleTitles.length == 1
            ? 'New wellness guide added: ${articleTitles.first}'
            : '${articleTitles.length} new wellness insights are available in your feed.';
      } else {
        body = articleTitles.length == 1
            ? 'Explore: "${articleTitles.first}" in Safe Bloom Insights'
            : '${articleTitles.length} new cycle & wellness guides added to Insights!';
      }

      await _plugin.show(
        _NotifId.newArticle,
        title,
        body,
        const NotificationDetails(
          android: _Channel.articles,
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── One-shot test notifications ───────────────────────────────────────────

  /// Triggers test notifications matching the user's currently enabled alerts, or a specific alert ID.
  Future<bool> showTestNotification({int? specificId}) async {
    final ok = await initialize();
    if (!ok) return false;
    await requestPermission();

    try {
      final settings = await getSettings();

      if (specificId != null) {
        return await _triggerSpecificTestNotification(specificId, settings);
      }

      bool anyTriggered = false;

      if (settings.periodAlertEnabled) {
        await _plugin.show(
          _NotifId.periodAlert,
          settings.discreetModeEnabled ? 'Safe Bloom Reminder' : 'Period Prediction Alert',
          formatNotificationBody(
            sensitiveBody: 'Expected period in 2 days. Self-care mode ready.',
            discreetBody: 'Safe Bloom Check-in: Upcoming self-care check-in in 2 days.',
            isDiscreet: settings.discreetModeEnabled,
          ),
          const NotificationDetails(
            android: _Channel.alerts,
            iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
          ),
        );
        anyTriggered = true;
      }

      if (settings.ovulationAlertEnabled) {
        await _plugin.show(
          _NotifId.ovulationAlert,
          settings.discreetModeEnabled ? 'Safe Bloom Reminder' : 'Peak Fertility / Ovulation Alert 🌸',
          formatNotificationBody(
            sensitiveBody: 'Peak fertility window expected tomorrow. Ovulation countdown active.',
            discreetBody: 'Safe Bloom: Personal wellness reminder ready.',
            isDiscreet: settings.discreetModeEnabled,
          ),
          const NotificationDetails(
            android: _Channel.alerts,
            iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
          ),
        );
        anyTriggered = true;
      }

      if (settings.dailyLoggingReminderEnabled) {
        await _plugin.show(
          _NotifId.dailyLogging,
          settings.discreetModeEnabled ? 'Safe Bloom Check-in' : 'Daily Health Log Reminder 📝',
          formatNotificationBody(
            sensitiveBody: "Time to log today's symptoms, period flow, and hydration!",
            discreetBody: 'Safe Bloom: Daily self-care check-in ready.',
            isDiscreet: settings.discreetModeEnabled,
          ),
          const NotificationDetails(
            android: _Channel.dailyLogging,
            iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
          ),
        );
        anyTriggered = true;
      }

      if (settings.hydrationReminderEnabled) {
        await _plugin.show(
          _NotifId.hydration11am,
          'Morning Hydration 💧',
          'Time for a fresh glass of water to keep your body energized.',
          const NotificationDetails(
            android: _Channel.hydration,
            iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
          ),
        );
        anyTriggered = true;
      }

      if (settings.newArticlesAlertEnabled) {
        await _plugin.show(
          _NotifId.newArticle,
          settings.discreetModeEnabled ? 'Safe Bloom: New Guide Available' : 'New Health Guide Published 📚',
          settings.discreetModeEnabled
              ? 'New wellness guide added to your feed.'
              : 'Explore new cycle & wellness guides added to Insights!',
          const NotificationDetails(
            android: _Channel.articles,
            iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
          ),
        );
        anyTriggered = true;
      }

      if (!anyTriggered) {
        await _plugin.show(
          _NotifId.test,
          'Safe Bloom Notification Test',
          'Notifications are working! Turn on specific alerts above to receive reminders.',
          const NotificationDetails(
            android: _Channel.alerts,
            iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
          ),
        );
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _triggerSpecificTestNotification(int id, NotificationSettings settings) async {
    try {
      if (id == _NotifId.periodAlert) {
        await _plugin.show(
          _NotifId.periodAlert,
          settings.discreetModeEnabled ? 'Safe Bloom Reminder' : 'Period Prediction Alert',
          formatNotificationBody(
            sensitiveBody: 'Expected period in 2 days. Self-care mode ready.',
            discreetBody: 'Safe Bloom Check-in: Upcoming self-care check-in in 2 days.',
            isDiscreet: settings.discreetModeEnabled,
          ),
          const NotificationDetails(android: _Channel.alerts, iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true)),
        );
      } else if (id == _NotifId.ovulationAlert) {
        await _plugin.show(
          _NotifId.ovulationAlert,
          settings.discreetModeEnabled ? 'Safe Bloom Reminder' : 'Peak Fertility / Ovulation Alert 🌸',
          formatNotificationBody(
            sensitiveBody: 'Peak fertility window expected tomorrow. Ovulation countdown active.',
            discreetBody: 'Safe Bloom: Personal wellness reminder ready.',
            isDiscreet: settings.discreetModeEnabled,
          ),
          const NotificationDetails(android: _Channel.alerts, iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true)),
        );
      } else if (id == _NotifId.dailyLogging) {
        await _plugin.show(
          _NotifId.dailyLogging,
          settings.discreetModeEnabled ? 'Safe Bloom Check-in' : 'Daily Health Log Reminder 📝',
          formatNotificationBody(
            sensitiveBody: "Time to log today's symptoms, period flow, and hydration!",
            discreetBody: 'Safe Bloom: Daily self-care check-in ready.',
            isDiscreet: settings.discreetModeEnabled,
          ),
          const NotificationDetails(android: _Channel.dailyLogging, iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true)),
        );
      } else if (id == _NotifId.hydration11am) {
        await _plugin.show(
          _NotifId.hydration11am,
          'Morning Hydration 💧',
          'Time for a fresh glass of water to keep your body energized.',
          const NotificationDetails(android: _Channel.hydration, iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true)),
        );
      } else if (id == _NotifId.newArticle) {
        await _plugin.show(
          _NotifId.newArticle,
          settings.discreetModeEnabled ? 'Safe Bloom: New Guide Available' : 'New Health Guide Published 📚',
          settings.discreetModeEnabled ? 'New wellness guide added to your feed.' : 'Explore new cycle & wellness guides added to Insights!',
          const NotificationDetails(android: _Channel.articles, iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true)),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Formats notification message text based on discreet privacy setting.
  static String formatNotificationBody({
    required String sensitiveBody,
    required String discreetBody,
    required bool isDiscreet,
  }) {
    return isDiscreet ? discreetBody : sensitiveBody;
  }
}
