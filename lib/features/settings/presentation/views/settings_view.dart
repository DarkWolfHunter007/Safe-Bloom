import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/safe_bloom_date_utils.dart';
import '../../../onboarding/presentation/views/onboarding_view.dart';
import '../../../security/data/services/biometric_auth_service.dart';
import '../../../security/data/services/screen_security_service.dart';
import '../../../tracking/data/repositories/tracking_repository.dart';
import '../../../tracking/domain/entities/user_profile.dart';
import '../../../tracking/domain/services/pdf_report_generator.dart';
import '../../../tracking/presentation/views/cycle_history_view.dart';
import 'privacy_policy_view.dart';
import 'terms_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => SettingsViewState();
}

class SettingsViewState extends State<SettingsView>
    with SingleTickerProviderStateMixin {
  final TrackingRepository _repository = TrackingRepository();
  final BiometricAuthService _biometricAuthService = BiometricAuthService.instance;

  UserProfile? _profile;

  Future<void> refresh() async {
    await _loadData();
  }
  bool _biometricLock = false;
  bool _screenSecurityEnabled = false;
  bool _isLoading = true;
  bool _isLoadingBiometricSetting = true;

  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _shimmerAnim = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final profile = await _repository.getUserProfile();
      final enabled = await _biometricAuthService.isBiometricLockEnabled();
      final screenSecurityEnabled =
          await ScreenSecurityService.instance.isScreenSecurityEnabled();
      if (mounted) {
        setState(() {
          _profile = profile;
          _biometricLock = enabled;
          _screenSecurityEnabled = screenSecurityEnabled;
          _isLoadingBiometricSetting = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile settings: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ── Skeleton helpers ──────────────────────────────────────────────────────

  Widget _skeletonBox({
    double width = double.infinity,
    double height = 16,
    double radius = 8,
  }) {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (_, __) => Opacity(
        opacity: _shimmerAnim.value,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.lightCardBorder,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          _skeletonBox(width: 200, height: 28, radius: 6),
          const SizedBox(height: 8),
          _skeletonBox(width: 260, height: 10, radius: 4),
          const SizedBox(height: AppSpacing.md),

          // Profile card skeleton
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.lightCardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.lightCardBorder),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _shimmerAnim,
                  builder: (_, __) => Opacity(
                    opacity: _shimmerAnim.value,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: AppColors.lightCardBorder,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _skeletonBox(width: 160, height: 16, radius: 4),
                      const SizedBox(height: 8),
                      _skeletonBox(width: 220, height: 11, radius: 4),
                      const SizedBox(height: 6),
                      _skeletonBox(width: 140, height: 9, radius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Encryption card skeleton
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.lightCardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.lightCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBox(width: 220, height: 16, radius: 4),
                const SizedBox(height: 10),
                _skeletonBox(height: 11),
                const SizedBox(height: 5),
                _skeletonBox(width: 260, height: 11, radius: 4),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Toggle card skeleton
          Container(
            decoration: BoxDecoration(
              color: AppColors.lightCardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.lightCardBorder),
            ),
            child: Column(
              children: List.generate(3, (i) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _skeletonBox(width: 140, height: 14, radius: 4),
                              const SizedBox(height: 6),
                              _skeletonBox(width: 200, height: 10, radius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        AnimatedBuilder(
                          animation: _shimmerAnim,
                          builder: (_, __) => Opacity(
                            opacity: _shimmerAnim.value,
                            child: Container(
                              width: 44,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.lightCardBorder,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < 2) const Divider(color: AppColors.lightCardBorder, height: 1),
                ],
              )),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // PDF report card skeleton
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.lightCardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.lightCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBox(width: 200, height: 16, radius: 4),
                const SizedBox(height: 8),
                _skeletonBox(height: 11),
                const SizedBox(height: 5),
                _skeletonBox(width: 280, height: 11, radius: 4),
                const SizedBox(height: AppSpacing.md),
                _skeletonBox(height: 44, radius: AppSpacing.radiusMd),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Export button skeleton
          _skeletonBox(height: 50, radius: AppSpacing.radiusMd),
          const SizedBox(height: AppSpacing.sm),
          _skeletonBox(height: 50, radius: AppSpacing.radiusMd),
        ],
      ),
    );
  }

  Future<void> _onBiometricLockToggled(bool value) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (value) {
        final isSupported = await _biometricAuthService.isDeviceSupported();
        if (!isSupported) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Biometric or Device PIN lock is not available or set up on this device.'),
              backgroundColor: AppColors.petalRose,
            ),
          );
          return;
        }

        final success = await _biometricAuthService.authenticate(
          reason: 'Please authenticate to enable biometric lock',
        );

        if (success) {
          await _biometricAuthService.setBiometricLockEnabled(true);
          if (mounted) {
            setState(() {
              _biometricLock = true;
            });
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Biometric and PIN lock enabled for Safe Bloom!'),
                backgroundColor: AppColors.dropCoral,
              ),
            );
          }
        } else {
          if (mounted) {
            setState(() {
              _biometricLock = false;
            });
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Authentication failed. Lock was not enabled.'),
                backgroundColor: AppColors.petalRose,
              ),
            );
          }
        }
      } else {
        await _biometricAuthService.setBiometricLockEnabled(false);
        if (mounted) {
          setState(() {
            _biometricLock = false;
          });
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Biometric and PIN lock disabled.'),
              backgroundColor: AppColors.textMuted,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Biometric setting error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _openPdfReportPreview() async {
    try {
      final profile = await _repository.getUserProfile();
      final periodEntries = await _repository.getPeriodEntries();
      final symptomEntries = await _repository.getAllSymptoms();

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(
                'OB-GYN Medical Report',
                style: AppTypography.brandTitle(fontSize: 18, color: Colors.white),
              ),
              backgroundColor: AppColors.deepPlum,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: PdfPreview(
              build: (format) => PdfReportGenerator.generateObGynReport(
                profile: profile,
                periodEntries: periodEntries,
                symptomEntries: symptomEntries,
              ),
              pdfFileName: 'SafeBloom_OBGYN_Medical_Report.pdf',
              canChangeOrientation: false,
              canChangePageFormat: false,
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF report: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _exportDataJson() async {
    try {
      final jsonStr = await _repository.exportUserDataJson();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.lightCardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          title: Text(
            'Export Data Backup',
            style: AppTypography.brandTitle(fontSize: 20),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your raw JSON backup payload (keep this data safe):',
                  style: AppTypography.body(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: AppColors.lightCardBorder),
                  ),
                  child: Text(
                    jsonStr,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: AppColors.textMain,
                    ),
                    maxLines: 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'CLOSE',
                style: AppTypography.brandTagline(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dropCoral,
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Backup copied to clipboard — keep this data safe!'),
                    backgroundColor: AppColors.dropCoral,
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 14, color: Colors.white),
              label: Text(
                'COPY JSON',
                style: AppTypography.brandTagline(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export data backup: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _importDataJson() async {
    final TextEditingController importController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.lightCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        title: Text(
          'Import Data Backup',
          style: AppTypography.brandTitle(fontSize: 20),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Paste your raw JSON backup payload below to restore your health data:',
                style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: importController,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppColors.textMain),
                decoration: InputDecoration(
                  hintText: '{"profile": {...}, "period_entries": [...]}',
                  hintStyle: AppTypography.body(fontSize: 11, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.lightBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: const BorderSide(color: AppColors.lightCardBorder),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data != null && data.text != null) {
                      importController.text = data.text!;
                    }
                  },
                  icon: const Icon(Icons.paste, size: 14, color: AppColors.dropCoral),
                  label: Text('PASTE FROM CLIPBOARD', style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('CANCEL', style: AppTypography.brandTagline(color: AppColors.textMuted, fontSize: 11)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dropCoral),
            onPressed: () async {
              final jsonStr = importController.text.trim();
              if (jsonStr.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please paste a valid JSON backup string.'),
                    backgroundColor: AppColors.petalRose,
                  ),
                );
                return;
              }

              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              try {
                final result = await _repository.importUserDataJson(jsonStr);
                nav.pop();
                await _loadData();

                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Backup restored successfully! ${result['periods']} period days & ${result['symptoms']} symptoms imported.'),
                    backgroundColor: AppColors.dropCoral,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to import backup payload: $e'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            icon: const Icon(Icons.upload, size: 14, color: Colors.white),
            label: Text('RESTORE BACKUP', style: AppTypography.brandTagline(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmWipeData() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.lightCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        title: Text(
          'Wipe All Local Data?',
          style: AppTypography.brandTitle(fontSize: 20),
        ),
        content: Text(
          'This action is irreversible. All period logs, symptoms, and key pairs will be purged from SQLCipher storage.',
          style: AppTypography.body(fontSize: 13, color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'CANCEL',
              style: AppTypography.brandTagline(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dropCoral,
            ),
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _biometricAuthService.setBiometricLockEnabled(false);
                await _repository.wipeAllUserData();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Local SQLCipher database wiped cleanly. Returning to onboarding...',
                    ),
                    backgroundColor: AppColors.dropCoral,
                  ),
                );
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const OnboardingView()),
                  (route) => false,
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to wipe user data: $e'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: Text(
              'PURGE EVERYTHING',
              style: AppTypography.brandTagline(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();

    final profile = _profile;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile & Privacy',
            style: AppTypography.brandTitle(fontSize: 28),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'ANONYMOUS HEALTH VAULT & SECURITY',
            style: AppTypography.brandTagline(
              color: AppColors.petalRose,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // User Profile Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.lightCardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.lightCardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/safe-bloom-logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anonymous Health Vault',
                        style: AppTypography.brandTitle(fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile != null
                            ? 'Cycle: ${profile.avgCycleLength} days • Period: ${profile.avgPeriodLength} days'
                            : 'Cycle: 28 days • Period: 5 days',
                        style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
                      ),
                      if (profile != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Last Period: ${profile.lastPeriodStart.day} ${SafeBloomDateUtils.monthAbbr(profile.lastPeriodStart.month)} ${profile.lastPeriodStart.year}',
                          style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 9),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Encryption Security Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.lightCardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: AppColors.petalRose.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.lock,
                      color: AppColors.petalRose,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '256-Bit AES Hardware Encryption',
                      style: AppTypography.brandTitle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Your health entries are encrypted using SQLCipher. Master keys reside in iOS Keychain & Android Keystore.',
                  style: AppTypography.body(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Hardware & Privacy Preferences
          Material(
            color: AppColors.lightCardBackground,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.lightCardBorder),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined, color: AppColors.dropCoral, size: 22),
                    title: Text(
                      '100% Private Architecture',
                      style: AppTypography.body(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'No accounts, emails, servers, or cloud tracking exist in Safe Bloom',
                      style: AppTypography.body(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const Divider(color: AppColors.lightCardBorder, height: 1),
                  SwitchListTile(
                    activeThumbColor: AppColors.dropCoral,
                    title: Text(
                      'Biometric / PIN Lock',
                      style: AppTypography.body(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Require Face ID / Fingerprint / PIN upon app launch',
                      style: AppTypography.body(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    value: _biometricLock,
                    onChanged: _isLoadingBiometricSetting
                        ? null
                        : (val) => _onBiometricLockToggled(val),
                  ),
                  const Divider(color: AppColors.lightCardBorder, height: 1),
                  SwitchListTile(
                    activeThumbColor: AppColors.dropCoral,
                    title: Text(
                      'Prevent Screenshots & Screen Recording',
                      style: AppTypography.body(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _screenSecurityEnabled
                          ? 'Screen recording & screenshots are BLOCKED'
                          : 'Screen recording & screenshots are ALLOWED',
                      style: AppTypography.body(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    value: _screenSecurityEnabled,
                    onChanged: (val) async {
                      setState(() {
                        _screenSecurityEnabled = val;
                      });
                      await ScreenSecurityService.instance.setScreenSecurityEnabled(val);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              val
                                  ? 'Screen recording and screenshots BLOCKED'
                                  : 'Screen recording and screenshots ALLOWED',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // OB-GYN Medical Report for Doctor Visit
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.medical_services_outlined,
                      color: AppColors.deepPlum,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'OB-GYN Doctor Visit Report',
                      style: AppTypography.brandTitle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Generate a medical PDF summary including 6-month cycle history, symptom frequencies, and flow statistics for your doctor visit.',
                  style: AppTypography.body(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepPlum,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                    ),
                    onPressed: _openPdfReportPreview,
                    icon: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      'PREVIEW & PRINT OB-GYN REPORT',
                      style: AppTypography.brandTagline(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Legal & History section
          Material(
            color: AppColors.lightCardBackground,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.lightCardBorder),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.history, color: AppColors.dropCoral),
                    title: Text('Cycle History & Summary Stats', style: AppTypography.body(fontSize: 14, fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CycleHistoryView()),
                      );
                      refresh();
                    },
                  ),
                  const Divider(color: AppColors.lightCardBorder, height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.dropCoral),
                    title: Text('Privacy Policy', style: AppTypography.body(fontSize: 14, fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PrivacyPolicyView()),
                      );
                    },
                  ),
                  const Divider(color: AppColors.lightCardBorder, height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined, color: AppColors.dropCoral),
                    title: Text('Terms of Service', style: AppTypography.body(fontSize: 14, fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TermsView()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Export Backup Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dropCoral,
                padding: const EdgeInsets.all(AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              onPressed: _exportDataJson,
              icon: const Icon(Icons.download, color: Colors.white, size: 18),
              label: Text(
                'EXPORT DATA BACKUP (JSON)',
                style: AppTypography.brandTagline(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Import Backup Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepPlum,
                padding: const EdgeInsets.all(AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              onPressed: _importDataJson,
              icon: const Icon(Icons.upload, color: Colors.white, size: 18),
              label: Text(
                'IMPORT DATA BACKUP (JSON)',
                style: AppTypography.brandTagline(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Wipe Data Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dropCoral,
                side: const BorderSide(color: AppColors.dropCoral),
                padding: const EdgeInsets.all(AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              onPressed: _confirmWipeData,
              icon: const Icon(Icons.delete_forever, size: 18),
              label: Text(
                'PURGE ALL MY DATA NOW',
                style: AppTypography.brandTagline(
                  color: AppColors.dropCoral,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
