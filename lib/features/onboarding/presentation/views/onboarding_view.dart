import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/safe_bloom_date_utils.dart';
import '../../../tracking/data/repositories/tracking_repository.dart';
import '../../../tracking/domain/entities/user_profile.dart';
import '../../../tracking/presentation/views/home_shell_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  final TrackingRepository _repository = TrackingRepository();
  int _currentPage = 0;

  DateTime? _selectedLastPeriod;
  int _avgCycleLength = 28;
  int _avgPeriodLength = 5;
  String _selectedGoal = '🌸 Track Cycle & Symptoms';

  final List<String> _goals = const [
    '🌸 Track Cycle & Symptoms',
    '👶 Conceive / Track Ovulation',
    '🔒 Private & Anonymous Health Journal',
    '⚡ Manage PMS & Energy Levels',
  ];

  Future<void> _completeOnboarding() async {
    if (_selectedLastPeriod == null) return;

    try {
      final profile = UserProfile(
        lastPeriodStart: _selectedLastPeriod!,
        avgCycleLength: _avgCycleLength,
        avgPeriodLength: _avgPeriodLength,
        isCloudBackupEnabled: true,
        preferredGoal: _selectedGoal,
      );
      await _repository.saveUserProfile(profile);

      // Onboarding saves starting profile info used for predictions.
      // Do NOT manufacture fake confirmed PeriodEntry records.

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShellView()),
      );
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

  void _nextPage() {
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
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
            // Top Progress Bar & Skip Button
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: List.generate(4, (index) {
                        final isActive = index <= _currentPage;
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
                  if (_currentPage > 0) ...[
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
                ],
              ),
            ),

            // Page View Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomeStep(),
                  _buildPeriodStartStep(),
                  _buildCycleLengthStep(),
                  _buildGoalStep(),
                ],
              ),
            ),

            // Bottom Action Bar
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

  // --- Step 1: Welcome & Privacy ---
  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
                height: 90,
                width: 90,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Welcome to Safe Bloom', style: AppTypography.brandTitle(fontSize: 30), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your Cycle. Your Privacy. Your Power.',
            style: AppTypography.brandTagline(color: AppColors.petalRose, fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.lg),
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
                      firstDate: DateTime.now().subtract(const Duration(days: 548)),
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
              itemCount: _goals.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final goal = _goals[index];
                final isSelected = _selectedGoal == goal;
                return GestureDetector(
                  onTap: () => setState(() => _selectedGoal = goal),
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
                        Expanded(
                          child: Text(
                            goal,
                            style: AppTypography.body(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: AppColors.textMain,
                            ),
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
