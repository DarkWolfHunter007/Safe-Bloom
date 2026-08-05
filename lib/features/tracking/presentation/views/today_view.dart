import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../insights/presentation/widgets/ad_gate_dialog.dart';
import '../widgets/period_logger_sheet.dart';

class TodayView extends StatefulWidget {
  const TodayView({super.key});

  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> {
  bool _isAdUnlocked = false;
  int _waterGlasses = 4; // 1,000 ml
  final int _waterGoal = 8; // 2,000 ml
  final Set<String> _quickLoggedSymptoms = {'😊 Happy', '⚡ Energetic'};

  void _openLoggerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PeriodLoggerSheet(
        onSave: (flow, symptoms) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Log saved securely (256-bit AES Encrypted)'),
              backgroundColor: AppColors.dropCoral,
            ),
          );
        },
      ),
    );
  }

  void _triggerAdGate() {
    showDialog(
      context: context,
      builder: (_) => AdGateDialog(
        onUnlocked: () => setState(() => _isAdUnlocked = true),
      ),
    );
  }

  void _addWaterGlass() {
    if (_waterGlasses < 12) {
      setState(() => _waterGlasses++);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text('Hydration logged: ${(_waterGlasses * 250)} ml / ${(_waterGoal * 250)} ml'),
          backgroundColor: AppColors.waterBlue,
        ),
      );
    }
  }

  void _removeWaterGlass() {
    if (_waterGlasses > 0) {
      setState(() => _waterGlasses--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double waterProgress = (_waterGlasses / _waterGoal).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          // Flo Branding Top Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Safe Bloom', style: AppTypography.brandTitle(fontSize: 28)),
                  Text(
                    'ANONYMOUS MODE ACTIVE',
                    style: AppTypography.brandTagline(color: AppColors.petalRose, fontSize: 9),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.shield_outlined, color: AppColors.petalRose),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Zero Data Selling Guarantee • Encrypted locally')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Flo-Style Interactive Cycle Wheel Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.phaseOvulation.withOpacity(0.12),
                  AppColors.lightCardBackground,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.phaseOvulation.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                // Phase Badge Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.phaseOvulation,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wb_sunny_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'OVULATION PHASE • HIGH FERTILITY',
                        style: AppTypography.brandTagline(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Circular Cycle Dial Widget
                SizedBox(
                  width: 190,
                  height: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: CircularProgressIndicator(
                          value: 14 / 28, // Day 14 of 28
                          strokeWidth: 12,
                          backgroundColor: AppColors.lightBackground,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.phaseOvulation),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Day 14', style: AppTypography.brandTitle(fontSize: 36)),
                          const SizedBox(height: 2),
                          Text(
                            'Period in 14 days',
                            style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.petalRose.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Chance: High',
                              style: AppTypography.body(fontSize: 10, color: AppColors.petalRose, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Main Log Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dropCoral,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    onPressed: _openLoggerSheet,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: Text(
                      'LOG FLOW & SYMPTOMS',
                      style: AppTypography.brandTagline(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Daily Hydration & Water Tracker Card (Flo Feature)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.lightCardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.lightCardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_drink_rounded, color: AppColors.waterBlue, size: 20),
                        const SizedBox(width: AppSpacing.xs),
                        Text('Water Intake', style: AppTypography.brandTitle(fontSize: 18)),
                      ],
                    ),
                    Text(
                      '${(_waterGlasses * 250)} / ${(_waterGoal * 250)} ml',
                      style: AppTypography.brandTagline(color: AppColors.waterBlue, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: waterProgress,
                    minHeight: 8,
                    backgroundColor: AppColors.lightBackground,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.waterBlue),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _removeWaterGlass,
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.textMuted),
                    ),
                    Text(
                      '$_waterGlasses of $_waterGoal glasses',
                      style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.waterBlue,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _addWaterGlass,
                      icon: const Icon(Icons.add, size: 14, color: Colors.white),
                      label: Text('+ 250 ml', style: AppTypography.body(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Daily Mood & Quick Symptoms Tracker
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.lightCardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.lightCardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Today\'s Mood & Body', style: AppTypography.brandTitle(fontSize: 18)),
                    Text('QUICK LOG', style: AppTypography.brandTagline(fontSize: 9)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    '😊 Happy',
                    '⚡ Energetic',
                    '😴 Fatigued',
                    '💆 Cramps',
                    '🌸 Calm',
                    '🍫 Cravings',
                  ].map((symptom) {
                    final isSelected = _quickLoggedSymptoms.contains(symptom);
                    return FilterChip(
                      label: Text(
                        symptom,
                        style: AppTypography.body(
                          fontSize: 11,
                          color: isSelected ? Colors.white : AppColors.textMain,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.dropCoral,
                      backgroundColor: AppColors.lightBackground,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _quickLoggedSymptoms.add(symptom);
                          } else {
                            _quickLoggedSymptoms.remove(symptom);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Cycle-Synced Action Plan
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.lightCardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.lightCardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Daily Action Plan',
                        style: AppTypography.brandTitle(fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('CYCLE-SYNCED', style: AppTypography.brandTagline(fontSize: 9)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _isAdUnlocked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '💪 Fitness: Estrogen peaks during Ovulation. Ideal time for high energy workouts & strength training!',
                            style: AppTypography.body(fontSize: 13),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '🥑 Nutrition: Support follicle health with rich healthy fats & antioxidant berries.',
                            style: AppTypography.body(fontSize: 13),
                          ),
                        ],
                      )
                    : GestureDetector(
                        onTap: _triggerAdGate,
                        child: Container(
                          height: 90,
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.petalRose.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(color: AppColors.petalRose),
                          ),
                          child: Center(
                            child: Text(
                              '🔒 UNLOCK DAILY INSIGHT (5s SPONSOR AD)',
                              style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '— NO DATA SELLING • 100% PRIVATE —',
            style: AppTypography.brandTagline(color: AppColors.textMuted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}
