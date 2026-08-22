import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class NotificationSettingsView extends StatefulWidget {
  const NotificationSettingsView({super.key});

  @override
  State<NotificationSettingsView> createState() => _NotificationSettingsViewState();
}

class _NotificationSettingsViewState extends State<NotificationSettingsView>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _hasPermission = true;
  NotificationSettings _settings = const NotificationSettings();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    try {
      final isEnabled = await LocalNotificationService.instance.areNotificationsEnabled();
      if (mounted) {
        setState(() => _hasPermission = isEnabled);
      }
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    try {
      final results = await Future.wait([
        LocalNotificationService.instance.getSettings(),
        LocalNotificationService.instance.areNotificationsEnabled(),
      ]);
      if (mounted) {
        setState(() {
          _settings = results[0] as NotificationSettings;
          _hasPermission = results[1] as bool;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateSettings(
    NotificationSettings newSettings, {
    bool requestingPermission = false,
  }) async {
    final old = _settings;

    try {
      // 1. Immediately apply and save user's configured preference so switch shows ON
      setState(() => _settings = newSettings);
      await LocalNotificationService.instance.saveSettings(newSettings);
      final persisted = await LocalNotificationService.instance.getSettings();
      if (mounted) {
        setState(() => _settings = persisted);
      }

      // 2. If user turned an alert ON, prompt for permission if currently missing
      if (requestingPermission) {
        final granted = await LocalNotificationService.instance.requestPermission();
        final isEnabled = (granted == true) || await LocalNotificationService.instance.areNotificationsEnabled();
        if (mounted) {
          setState(() => _hasPermission = isEnabled);
        }
        if (!isEnabled && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Alert preference enabled. Enable notification permission in system settings to receive reminders on your device.',
              ),
              backgroundColor: AppColors.dropCoral,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _settings = old);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update notification settings: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.dropCoral),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: AppTypography.brandTagline(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightCardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.lightCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.deepPlum, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifications & Alerts',
          style: AppTypography.brandTitle(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.dropCoral))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Privacy Assurance Banner
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.sageGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.sageGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: AppColors.sageGreen, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '100% Local • Zero Cloud Push',
                                style: AppTypography.brandTitle(fontSize: 14, color: AppColors.deepPlum),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'All alarms are computed locally by your device OS. No external servers or push notification trackers ever receive your cycle data.',
                                style: AppTypography.body(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // OS Permission Disabled Warning Banner
                  if (!_hasPermission) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.dropCoral.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.dropCoral.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.notifications_off_rounded, color: AppColors.dropCoral, size: 22),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'System Notifications Are Blocked',
                                  style: AppTypography.brandTitle(fontSize: 14, color: AppColors.dropCoral),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'You denied notification permission. Alerts cannot trigger on this device until permission is granted.',
                                  style: AppTypography.body(fontSize: 11, color: AppColors.textMuted),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xs,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.dropCoral,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                        ),
                                      ),
                                      onPressed: () async {
                                        final granted = await LocalNotificationService.instance.requestPermission();
                                        final isEnabled = (granted == true) || await LocalNotificationService.instance.areNotificationsEnabled();
                                        if (mounted) {
                                          setState(() => _hasPermission = isEnabled);
                                        }
                                        if (!isEnabled) {
                                          await LocalNotificationService.instance.openNotificationSettings();
                                        }
                                      },
                                      child: Text(
                                        'ALLOW NOTIFICATIONS',
                                        style: AppTypography.brandTagline(color: Colors.white, fontSize: 11),
                                      ),
                                    ),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.dropCoral,
                                        side: const BorderSide(color: AppColors.dropCoral),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                        ),
                                      ),
                                      onPressed: () => LocalNotificationService.instance.openNotificationSettings(),
                                      child: Text(
                                        'APP SETTINGS',
                                        style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── 1. Cycle & Fertility Predictions ────────────────────
                  _buildSectionHeader('Cycle & Fertility Predictions', Icons.favorite_border_rounded),
                  _buildCard(
                    children: [
                      SwitchListTile(
                        activeThumbColor: AppColors.dropCoral,
                        title: Text('Period Prediction Alert', style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Remind 2 days before predicted period start', style: AppTypography.body(fontSize: 11, color: AppColors.textMuted)),
                        value: _settings.periodAlertEnabled,
                        onChanged: (val) => _updateSettings(
                          _settings.copyWith(periodAlertEnabled: val),
                          requestingPermission: val,
                        ),
                      ),
                      const Divider(color: AppColors.lightCardBorder, height: 1),
                      SwitchListTile(
                        activeThumbColor: AppColors.dropCoral,
                        title: Text('Peak Fertility / Ovulation Alert', style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Alert 1 day before peak ovulation window', style: AppTypography.body(fontSize: 11, color: AppColors.textMuted)),
                        value: _settings.ovulationAlertEnabled,
                        onChanged: (val) => _updateSettings(
                          _settings.copyWith(ovulationAlertEnabled: val),
                          requestingPermission: val,
                        ),
                      ),
                    ],
                  ),

                  // ── 2. Daily Health & Habits ─────────────────────────────
                  _buildSectionHeader('Daily Wellness & Habits', Icons.alarm_rounded),
                  _buildCard(
                    children: [
                      SwitchListTile(
                        activeThumbColor: AppColors.dropCoral,
                        title: Text('Daily Logging Reminder', style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Remind daily at ${_formatTime(_settings.dailyLoggingReminderHour, _settings.dailyLoggingReminderMinute)} to log health data',
                          style: AppTypography.body(fontSize: 11, color: AppColors.textMuted),
                        ),
                        value: _settings.dailyLoggingReminderEnabled,
                        onChanged: (val) => _updateSettings(
                          _settings.copyWith(dailyLoggingReminderEnabled: val),
                          requestingPermission: val,
                        ),
                      ),
                      if (_settings.dailyLoggingReminderEnabled)
                        Container(
                          color: AppColors.lightBackground.withValues(alpha: 0.5),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.access_time_rounded, color: AppColors.dropCoral, size: 18),
                            title: Text(
                              'Reminder Time: ${_formatTime(_settings.dailyLoggingReminderHour, _settings.dailyLoggingReminderMinute)}',
                              style: AppTypography.body(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            trailing: TextButton(
                              onPressed: () async {
                                final selected = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(
                                    hour: _settings.dailyLoggingReminderHour,
                                    minute: _settings.dailyLoggingReminderMinute,
                                  ),
                                );
                                if (selected != null) {
                                  await _updateSettings(
                                    _settings.copyWith(
                                      dailyLoggingReminderHour: selected.hour,
                                      dailyLoggingReminderMinute: selected.minute,
                                    ),
                                  );
                                }
                              },
                              child: Text('CHANGE TIME', style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 10)),
                            ),
                          ),
                        ),
                      const Divider(color: AppColors.lightCardBorder, height: 1),
                      SwitchListTile(
                        activeThumbColor: AppColors.dropCoral,
                        title: Text('Hydration Reminders 💧', style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Periodic reminders at 11am, 3pm & 7pm to support hormonal balance', style: AppTypography.body(fontSize: 11, color: AppColors.textMuted)),
                        value: _settings.hydrationReminderEnabled,
                        onChanged: (val) => _updateSettings(
                          _settings.copyWith(hydrationReminderEnabled: val),
                          requestingPermission: val,
                        ),
                      ),
                      const Divider(color: AppColors.lightCardBorder, height: 1),
                      SwitchListTile(
                        activeThumbColor: AppColors.dropCoral,
                        title: Text('New Articles & Insights 📚', style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Get notified when new wellness guides and cycle health articles are published', style: AppTypography.body(fontSize: 11, color: AppColors.textMuted)),
                        value: _settings.newArticlesAlertEnabled,
                        onChanged: (val) => _updateSettings(
                          _settings.copyWith(newArticlesAlertEnabled: val),
                          requestingPermission: val,
                        ),
                      ),
                    ],
                  ),

                  // ── 3. Lock Screen Privacy ───────────────────────────────
                  _buildSectionHeader('Lock Screen Privacy', Icons.visibility_off_outlined),
                  _buildCard(
                    children: [
                      SwitchListTile(
                        activeThumbColor: AppColors.dropCoral,
                        title: Text('Discreet Lock Screen Mode', style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Mask sensitive period and fertility titles with private self-care prompts on lock screen', style: AppTypography.body(fontSize: 11, color: AppColors.textMuted)),
                        value: _settings.discreetModeEnabled,
                        onChanged: (val) => _updateSettings(
                          _settings.copyWith(discreetModeEnabled: val),
                        ),
                      ),
                    ],
                  ),

                  // ── 4. Diagnostics & Testing (Debug Mode Only) ───────────
                  if (kDebugMode) ...[
                    _buildSectionHeader('System Testing (Developer Only)', Icons.build_outlined),
                    _buildCard(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.dropCoral,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final success = await LocalNotificationService.instance.showTestNotification();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            success
                                                ? 'Triggered test alerts for your enabled settings! Check notification tray.'
                                                : 'Failed to trigger notifications. Please check system permissions.',
                                          ),
                                          backgroundColor: success ? AppColors.dropCoral : AppColors.petalRose,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.notifications_active_rounded, size: 16, color: Colors.white),
                                  label: Text(
                                    'TRIGGER ENABLED ALERTS',
                                    style: AppTypography.brandTagline(color: Colors.white, fontSize: 11),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Quick Individual Alert Previews:',
                                style: AppTypography.body(fontSize: 11, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ActionChip(
                                    avatar: const Icon(Icons.water_drop_outlined, size: 14, color: AppColors.dropCoral),
                                    label: Text('Hydration', style: AppTypography.body(fontSize: 11)),
                                    onPressed: () => LocalNotificationService.instance.showTestNotification(
                                      specificId: LocalNotificationId.hydration11am,
                                    ),
                                  ),
                                  ActionChip(
                                    avatar: const Icon(Icons.edit_calendar_outlined, size: 14, color: AppColors.dropCoral),
                                    label: Text('Daily Log', style: AppTypography.body(fontSize: 11)),
                                    onPressed: () => LocalNotificationService.instance.showTestNotification(
                                      specificId: LocalNotificationId.dailyLogging,
                                    ),
                                  ),
                                  ActionChip(
                                    avatar: const Icon(Icons.favorite_border_rounded, size: 14, color: AppColors.dropCoral),
                                    label: Text('Period', style: AppTypography.body(fontSize: 11)),
                                    onPressed: () => LocalNotificationService.instance.showTestNotification(
                                      specificId: LocalNotificationId.periodAlert,
                                    ),
                                  ),
                                  ActionChip(
                                    avatar: const Icon(Icons.auto_awesome_outlined, size: 14, color: AppColors.dropCoral),
                                    label: Text('Ovulation', style: AppTypography.body(fontSize: 11)),
                                    onPressed: () => LocalNotificationService.instance.showTestNotification(
                                      specificId: LocalNotificationId.ovulationAlert,
                                    ),
                                  ),
                                  ActionChip(
                                    avatar: const Icon(Icons.menu_book_outlined, size: 14, color: AppColors.dropCoral),
                                    label: Text('Article', style: AppTypography.body(fontSize: 11)),
                                    onPressed: () => LocalNotificationService.instance.showTestNotification(
                                      specificId: LocalNotificationId.newArticle,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
    );
  }
}
