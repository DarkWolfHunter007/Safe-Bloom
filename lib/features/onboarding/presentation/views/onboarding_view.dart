import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../../../core/services/backup_crypto_service.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/services/vault_file_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/safe_bloom_date_utils.dart';
import '../../../tracking/data/repositories/tracking_repository.dart';
import '../../../tracking/domain/entities/user_profile.dart';
import '../../../tracking/presentation/views/home_shell_view.dart';

class OnboardingGoalOption {
  final AppMode mode;
  final String title;
  final String description;
  final String emoji;

  const OnboardingGoalOption({
    required this.mode,
    required this.title,
    required this.description,
    required this.emoji,
  });
}

class OnboardingView extends StatefulWidget {
  final VoidCallback? onComplete;
  const OnboardingView({super.key, this.onComplete});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final TrackingRepository _repository = TrackingRepository.instance;
  int _currentPage = 0;

  DateTime? _selectedLastPeriod;
  int _avgCycleLength = 28;
  int _avgPeriodLength = 5;
  int _selectedGoalIndex = 0; // index into _goalOptions; avoids dual-selection when two options share the same AppMode

  // Restore vault state (page 0)
  bool _showRestoreForm = false;
  bool _isRestoring = false;
  File? _pickedVaultFile;
  String? _pickedVaultFileName;
  int? _pickedVaultFileSize;
  bool _showTextPasteFallback = false;
  final TextEditingController _restoreVaultTextController = TextEditingController();
  final TextEditingController _restorePasswordController = TextEditingController();
  bool _restoreObscure = true;

  @override
  void dispose() {
    _restoreVaultTextController.dispose();
    _restorePasswordController.dispose();
    super.dispose();
  }

  final List<OnboardingGoalOption> _goalOptions = const [
    OnboardingGoalOption(
      mode: AppMode.trackCycle,
      title: 'Track Cycle & Symptoms',
      description: 'Menstrual health, PMS tracking & hormonal phase guidance',
      emoji: '🌸',
    ),
    OnboardingGoalOption(
      mode: AppMode.ttc,
      title: 'Try to Conceive (TTC)',
      description: 'Peak fertility window, ovulation countdown & conception guidance',
      emoji: '👶',
    ),
    OnboardingGoalOption(
      mode: AppMode.pregnancy,
      title: 'Track Pregnancy',
      description: 'Gestational age milestones, trimester progression & baby size',
      emoji: '🤰',
    ),
    OnboardingGoalOption(
      mode: AppMode.trackCycle,
      title: 'Private & Anonymous Health Journal',
      description: 'Zero cloud servers, zero trackers, encrypted locally on device',
      emoji: '🔒',
    ),
  ];

  Future<void> _completeOnboarding() async {
    if (_selectedLastPeriod == null) return;

    try {
      final selectedOption = _goalOptions[_selectedGoalIndex];
      final isPregnancy = selectedOption.mode == AppMode.pregnancy;
      final profile = UserProfile(
        lastPeriodStart: _selectedLastPeriod!,
        avgCycleLength: _avgCycleLength,
        avgPeriodLength: _avgPeriodLength,
        isCloudBackupEnabled: true,
        isPregnancyModeEnabled: isPregnancy,
        preferredGoal: selectedOption.mode.name,
      );
      await _repository.saveUserProfile(profile);
      await LocalNotificationService.instance.requestPermission();

      // Onboarding saves starting profile info used for predictions.
      // Do NOT manufacture fake confirmed PeriodEntry records.

      if (!mounted) return;
      if (widget.onComplete != null) {
        widget.onComplete!();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShellView()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete onboarding: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _skipOnboarding() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _selectedLastPeriod ??= DateTime.now().subtract(const Duration(days: 14));
    await _completeOnboarding();
  }

  Future<void> _pickVaultFileForRestore() async {
    try {
      final file = await VaultFileService.pickVaultFile();
      if (file == null || !mounted) return;

      // Pre-validate file envelope
      await VaultFileService.readVaultFile(file);

      final size = await file.length();
      setState(() {
        _pickedVaultFile = file;
        _pickedVaultFileName = p.basename(file.path);
        _pickedVaultFileSize = size;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid vault file: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleRestoreVault() async {
    final password = _restorePasswordController.text.trim();

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your vault password.'),
          backgroundColor: AppColors.petalRose,
        ),
      );
      return;
    }

    if (_pickedVaultFile == null && !_showTextPasteFallback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an encrypted vault file (.safebloom).'),
          backgroundColor: AppColors.petalRose,
        ),
      );
      return;
    }

    setState(() => _isRestoring = true);

    try {
      final Map<String, int> stats;
      if (_pickedVaultFile != null) {
        stats = await _repository.recoverAndRestoreFromEncryptedVaultFile(
          file: _pickedVaultFile!,
          passphrase: password,
        );
      } else {
        final text = _restoreVaultTextController.text.trim();
        if (text.isEmpty) {
          throw const MalformedBackupPayloadException('Please paste your encrypted backup vault payload.');
        }
        stats = await _repository.recoverAndRestoreFromEncryptedVault(
          vaultJsonString: text,
          passphrase: password,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vault restored! ${stats['periods']} periods & ${stats['symptoms']} symptoms recovered.'),
          backgroundColor: AppColors.dropCoral,
        ),
      );

      if (widget.onComplete != null) {
        widget.onComplete!();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShellView()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRestoring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e. Your vault was not modified.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _nextPage() {
    // Page 1 (period date) — must have a date selected
    if (_currentPage == 1 && _selectedLastPeriod == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select when your last period started to continue.'),
          backgroundColor: AppColors.dropCoral,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (_currentPage < 3) {
      setState(() => _currentPage++);
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress Bar & Skip Button (shown on pages 1-3)
            if (_currentPage > 0)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: List.generate(3, (index) {
                          final isActive = index <= (_currentPage - 1);
                          return Expanded(
                            child: Container(
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: isActive ? AppColors.dropCoral : AppColors.lightCardBorder,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: _skipOnboarding,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'SKIP',
                        style: AppTypography.brandTagline(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Page View Content
            Expanded(
              child: IndexedStack(
                index: _currentPage,
                children: [
                  _buildRestoreOrFreshStep(),
                  _buildPeriodStartStep(),
                  _buildCycleLengthStep(),
                  _buildGoalStep(),
                ],
              ),
            ),

            // Bottom Action Bar (hidden on page 0 — it has Start Fresh / Restore cards)
            if (_currentPage > 0)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dropCoral,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    onPressed: _nextPage,
                    child: Text(
                      _currentPage == 3 ? 'GET STARTED' : 'CONTINUE',
                      style: AppTypography.brandTagline(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Page 0: Start Fresh or Restore Vault ---
  Widget _buildRestoreOrFreshStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.dropCoral.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/safe-bloom-logo.png',
                height: 80,
                width: 80,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Welcome to Safe Bloom',
            style: AppTypography.brandTitle(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your Cycle. Your Privacy. Your Power.',
            style: AppTypography.brandTagline(color: AppColors.petalRose, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),

          if (!_showRestoreForm) ...[
            // --- Choice cards ---
            GestureDetector(
              key: const ValueKey('onboarding_start_fresh'),
              behavior: HitTestBehavior.opaque,
              onTap: _nextPage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.dropCoral,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Fresh',
                            style: AppTypography.body(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Set up a new Safe Bloom profile',
                            style: AppTypography.body(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              key: const ValueKey('onboarding_restore_vault'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showRestoreForm = true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.lightCardBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.lightCardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.dropCoral, size: 28),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Restore from Vault',
                            style: AppTypography.body(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Recover your data from an encrypted backup',
                            style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.lightCardBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.lightCardBorder),
              ),
              child: Column(
                children: [
                  _buildPrivacyPill(Icons.lock, '256-Bit AES Hardware Encrypted', 'Stored safely in your device Keystore'),
                  const Divider(height: AppSpacing.md),
                  _buildPrivacyPill(Icons.no_accounts, '100% Anonymous', 'No email, real name, or account required'),
                  const Divider(height: AppSpacing.md),
                  _buildPrivacyPill(Icons.money_off, 'Zero Data Selling Guarantee', 'Your intimate data never leaves your device'),
                ],
              ),
            ),
          ] else ...[
            // --- Restore vault form ---
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isRestoring
                    ? null
                    : () => setState(() {
                          _showRestoreForm = false;
                          _pickedVaultFile = null;
                          _pickedVaultFileName = null;
                          _pickedVaultFileSize = null;
                          _showTextPasteFallback = false;
                          _restoreVaultTextController.clear();
                          _restorePasswordController.clear();
                        }),
                icon: const Icon(Icons.arrow_back, size: 16, color: AppColors.textMuted),
                label: Text('Back', style: AppTypography.body(fontSize: 13, color: AppColors.textMuted)),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Restore Encrypted Vault', style: AppTypography.brandTitle(fontSize: 22)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _showTextPasteFallback
                    ? 'Paste your encrypted backup payload and enter your password.'
                    : 'Select your .safebloom vault backup file and enter your password to recover all your data.',
                style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            if (!_showTextPasteFallback) ...[
              if (_pickedVaultFile == null)
                GestureDetector(
                  key: const ValueKey('onboarding_pick_vault_file'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _isRestoring ? null : _pickVaultFileForRestore,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.lightCardBackground,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.dropCoral, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.file_open_rounded, size: 36, color: AppColors.dropCoral),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'SELECT .SAFEBLOOM FILE',
                          style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to browse device storage',
                          style: AppTypography.body(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.lightCardBackground,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.dropCoral),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_rounded, color: AppColors.dropCoral, size: 28),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pickedVaultFileName ?? 'Vault File Selected',
                              style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_pickedVaultFileSize != null)
                              Text(
                                '${(_pickedVaultFileSize! / 1024).toStringAsFixed(1)} KB • Encrypted Vault',
                                style: AppTypography.body(fontSize: 11, color: AppColors.textMuted),
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _isRestoring ? null : _pickVaultFileForRestore,
                        child: Text('CHANGE', style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
            ] else ...[
              TextField(
                controller: _restoreVaultTextController,
                maxLines: 5,
                enabled: !_isRestoring,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                decoration: InputDecoration(
                  hintText: 'Paste {"safe_bloom_backup_version": 1, ...}',
                  filled: true,
                  fillColor: AppColors.lightCardBackground,
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
                  onPressed: _isRestoring
                      ? null
                      : () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) _restoreVaultTextController.text = data!.text!;
                        },
                  icon: const Icon(Icons.paste, size: 14, color: AppColors.dropCoral),
                  label: Text('PASTE', style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 10)),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _restorePasswordController,
              obscureText: _restoreObscure,
              enabled: !_isRestoring,
              decoration: InputDecoration(
                labelText: 'Vault Password',
                filled: true,
                fillColor: AppColors.lightCardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: const BorderSide(color: AppColors.lightCardBorder),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _restoreObscure ? Icons.visibility : Icons.visibility_off,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _restoreObscure = !_restoreObscure),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dropCoral,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                onPressed: _isRestoring ? null : _handleRestoreVault,
                child: _isRestoring
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'RESTORE VAULT',
                        style: AppTypography.brandTagline(color: Colors.white, fontSize: 13),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _isRestoring
                  ? null
                  : () => setState(() {
                        _showTextPasteFallback = !_showTextPasteFallback;
                      }),
              child: Text(
                _showTextPasteFallback
                    ? '← Select .safebloom file instead'
                    : 'Paste encrypted text backup instead',
                style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Step 2: Last Period Start Date ---
  Widget _buildPeriodStartStep() {
    final hasSelectedDate = _selectedLastPeriod != null;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('When did your last period start?', style: AppTypography.brandTitle(fontSize: 24), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text('We use this to calculate your cycle day and fertility predictions', style: AppTypography.body(fontSize: 12, color: AppColors.textMuted), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.lightCardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: hasSelectedDate ? AppColors.dropCoral : AppColors.lightCardBorder,
                width: hasSelectedDate ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  hasSelectedDate
                      ? '${_selectedLastPeriod!.day} ${SafeBloomDateUtils.monthAbbr(_selectedLastPeriod!.month)} ${_selectedLastPeriod!.year}'
                      : 'No Date Selected',
                  style: AppTypography.brandTitle(
                    fontSize: hasSelectedDate ? 28 : 22,
                    color: hasSelectedDate ? AppColors.textMain : AppColors.textMuted,
                  ),
                ),
                if (!hasSelectedDate) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Please pick a date to continue setup',
                    style: AppTypography.body(fontSize: 12, color: AppColors.dropCoral),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.dropCoral),
                  onPressed: () async {
                    final initial = _selectedLastPeriod ?? DateTime.now().subtract(const Duration(days: 14));
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial.isAfter(DateTime.now()) ? DateTime.now() : initial,
                      firstDate: DateTime.now().subtract(const Duration(days: 180)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      setState(() => _selectedLastPeriod = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16, color: Colors.white),
                  label: Text(
                    hasSelectedDate ? 'CHANGE DATE' : 'SELECT DATE',
                    style: AppTypography.brandTagline(color: Colors.white, fontSize: 11),
                  ),
                ),
                if (!hasSelectedDate) ...[
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    onPressed: () {
                      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      setState(() => _selectedLastPeriod = DateTime.now().subtract(const Duration(days: 14)));
                      _nextPage();
                    },
                    child: Text(
                      'Not sure? Skip with default (14 days ago)',
                      style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 3: Cycle Length & Period Duration ---
  Widget _buildCycleLengthStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CYCLE DURATION',
            style: AppTypography.brandTagline(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'How long is your typical cycle?',
            style: AppTypography.brandTitle(fontSize: 24),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Measured from the first day of one period to the first day of the next. Most cycles range from 21 to 35 days.',
            style: AppTypography.body(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Column(
              children: [
                Text(
                  '$_avgCycleLength Days',
                  style: AppTypography.brandTitle(fontSize: 32, color: AppColors.dropCoral),
                ),
                Slider(
                  key: const ValueKey('onboarding_cycle_slider'),
                  value: _avgCycleLength.toDouble(),
                  min: 20,
                  max: 45,
                  divisions: 25,
                  activeColor: AppColors.dropCoral,
                  inactiveColor: AppColors.lightCardBorder,
                  onChanged: (val) => setState(() => _avgCycleLength = val.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'PERIOD DURATION',
            style: AppTypography.brandTagline(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'How many days does bleeding last?',
            style: AppTypography.brandTitle(fontSize: 20),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Column(
              children: [
                Text(
                  '$_avgPeriodLength Days',
                  style: AppTypography.brandTitle(fontSize: 28, color: AppColors.petalRose),
                ),
                Slider(
                  key: const ValueKey('onboarding_period_slider'),
                  value: _avgPeriodLength.toDouble(),
                  min: 2,
                  max: 10,
                  divisions: 8,
                  activeColor: AppColors.petalRose,
                  inactiveColor: AppColors.lightCardBorder,
                  onChanged: (val) => setState(() => _avgPeriodLength = val.round()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 4: Primary Tracking Goal ---
  Widget _buildGoalStep() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR GOAL',
            style: AppTypography.brandTagline(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'What brings you to Safe Bloom?',
            style: AppTypography.brandTitle(fontSize: 24),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This helps us prioritize the right insights and metrics for your journey.',
            style: AppTypography.body(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView.separated(
              itemCount: _goalOptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final option = _goalOptions[index];
                final isSelected = _selectedGoalIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedGoalIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.dropCoral.withValues(alpha: 0.1) : AppColors.lightCardBackground,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: isSelected ? AppColors.dropCoral : AppColors.lightCardBorder,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(option.emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.title,
                                style: AppTypography.body(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: AppColors.textMain,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                option.description,
                                style: AppTypography.body(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: AppColors.dropCoral, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPill(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: AppColors.dropCoral, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(subtitle, style: AppTypography.body(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}
