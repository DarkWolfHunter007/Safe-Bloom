import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/utils/safe_bloom_date_utils.dart';
import '../../../insights/presentation/widgets/ad_gate_dialog.dart';
import '../../data/repositories/tracking_repository.dart';
import '../../domain/entities/period_entry.dart';
import '../../domain/entities/symptom_entry.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/services/cycle_calculator.dart';
import '../widgets/period_logger_sheet.dart';

class TodayView extends StatefulWidget {
  const TodayView({super.key});

  @override
  State<TodayView> createState() => TodayViewState();
}

class TodayViewState extends State<TodayView> {
  final TrackingRepository _repository = TrackingRepository();
  bool _isLoading = true;
  bool _isAdUnlocked = false;

  UserProfile? _profile;
  List<PeriodEntry> _periodEntries = [];
  int _waterGlasses = 0;
  final int _waterGoal = 8;
  List<SymptomEntry> _todaySymptoms = [];
  FlowLevel _currentFlow = FlowLevel.medium;

  int _shieldTapCount = 0;
  DateTime? _lastShieldTapTime;
  bool _showDeveloperCredit = false;
  Timer? _developerCreditTimer;

  Future<void> refresh() async {
    await _loadData();
  }

  Future<void> _handleShieldTap() async {
    final now = DateTime.now();
    if (_lastShieldTapTime != null && now.difference(_lastShieldTapTime!).inSeconds > 3) {
      _shieldTapCount = 0;
    }
    _lastShieldTapTime = now;
    _shieldTapCount++;

    final messenger = ScaffoldMessenger.of(context);

    if (_shieldTapCount >= 8) {
      _shieldTapCount = 0;
      setState(() {
        _showDeveloperCredit = true;
      });
      _developerCreditTimer?.cancel();
      _developerCreditTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) {
          setState(() {
            _showDeveloperCredit = false;
          });
        }
      });

      final url = Uri.parse('https://github.com/DarkWolfHunter007');
      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Error launching URL: $e');
      }
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Zero Data Selling Guarantee • Encrypted locally'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  void dispose() {
    _developerCreditTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final profile = await _repository.getUserProfile();
      final periods = await _repository.getPeriodEntries();
      final waterMl = await _repository.getWaterIntake(DateTime.now());
      final symptoms = await _repository.getSymptomsForDate(DateTime.now());

      // Check if today has a logged flow
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      FlowLevel flow = FlowLevel.medium;
      for (final p in periods) {
        if (p.timestamp.toIso8601String().substring(0, 10) == todayStr) {
          flow = p.flow;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _periodEntries = periods;
          _waterGlasses = (waterMl / 250).round();
          _todaySymptoms = symptoms;
          _currentFlow = flow;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load health data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Toggle period start/end directly from the home dial
  Future<void> _togglePeriodToday(bool isCurrentlyInPeriod) async {
    final now = DateTime.now();
    final todayKey = SafeBloomDateUtils.dateKey(now);

    try {
      if (isCurrentlyInPeriod) {
        // Unmark / remove today's period entry if logged accidentally
        final todayEntries = _periodEntries.where(
          (p) => SafeBloomDateUtils.dateKey(p.timestamp) == todayKey,
        ).toList();

        if (todayEntries.isNotEmpty) {
          for (final entry in todayEntries) {
            await _repository.deletePeriodEntry(entry.id);
          }
        } else {
          await _repository.endCurrentPeriod(now);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Period log for today removed. Cycle predictions updated!'),
              backgroundColor: AppColors.dropCoral,
            ),
          );
        }
      } else {
        // Mark period started today
        final newEntry = PeriodEntry(
          id: IdGenerator.newId('period'),
          timestamp: now,
          flow: _currentFlow,
          notes: 'Quick logged from Home Dial',
        );
        await _repository.addPeriodEntry(newEntry);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🩸 Period logged starting today! Cycle updated.'),
              backgroundColor: AppColors.dropCoral,
            ),
          );
        }
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update period status: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Change flow level directly from home dial selector
  Future<void> _selectFlowLevel(FlowLevel flow) async {
    setState(() => _currentFlow = flow);
    final now = DateTime.now();

    try {
      final entry = PeriodEntry(
        id: IdGenerator.newId('period'),
        timestamp: now,
        flow: flow,
      );
      await _repository.addPeriodEntry(entry);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text('Flow intensity set to ${flow.name.toUpperCase()}'),
            backgroundColor: AppColors.dropCoral,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update flow level: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _addWaterGlass() async {
    if (_waterGlasses < 12) {
      final newGlasses = _waterGlasses + 1;
      setState(() => _waterGlasses = newGlasses);
      try {
        await _repository.setWaterIntake(DateTime.now(), newGlasses * 250);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 1),
              content: Text('Hydration logged: ${(newGlasses * 250)} ml / ${(_waterGoal * 250)} ml'),
              backgroundColor: AppColors.waterBlue,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save hydration: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeWaterGlass() async {
    if (_waterGlasses > 0) {
      final newGlasses = _waterGlasses - 1;
      setState(() => _waterGlasses = newGlasses);
      try {
        await _repository.setWaterIntake(DateTime.now(), newGlasses * 250);
      } catch (e) {
        debugPrint('Error saving water intake: $e');
      }
    }
  }

  Future<void> _toggleQuickSymptom(String symptomName) async {
    final now = DateTime.now();
    final existingIndex = _todaySymptoms.indexWhere((s) => s.type == symptomName);

    try {
      if (existingIndex >= 0) {
        final symptomToRemove = _todaySymptoms[existingIndex];
        setState(() {
          _todaySymptoms.removeAt(existingIndex);
        });
        await _repository.deleteSymptomEntry(symptomToRemove.id);
      } else {
        final newEntry = SymptomEntry(
          id: IdGenerator.newId('symptom'),
          timestamp: now,
          category: SymptomCategory.custom,
          type: symptomName,
        );
        setState(() {
          _todaySymptoms.add(newEntry);
        });
        await _repository.addSymptomEntry(newEntry);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update symptom: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _openLoggerSheet() {
    final todayKey = SafeBloomDateUtils.dateKey(DateTime.now());
    final todayEntries = _periodEntries.where(
      (p) => SafeBloomDateUtils.dateKey(p.timestamp) == todayKey,
    ).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PeriodLoggerSheet(
        onDelete: todayEntries.isNotEmpty
            ? () async {
                for (final e in todayEntries) {
                  await _repository.deletePeriodEntry(e.id);
                }
                await _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Period log for today removed.'),
                      backgroundColor: AppColors.dropCoral,
                    ),
                  );
                }
              }
            : null,
        onSave: (flow, symptoms, notes) async {
          final now = DateTime.now();

          try {
            final periodEntry = PeriodEntry(
              id: IdGenerator.newId('period'),
              timestamp: now,
              flow: flow,
              notes: notes,
            );
            await _repository.addPeriodEntry(periodEntry);

            for (final symptom in symptoms) {
              final sEntry = SymptomEntry(
                id: IdGenerator.newId('symptom'),
                timestamp: now,
                category: SymptomCategory.custom,
                type: symptom,
              );
              await _repository.addSymptomEntry(sEntry);
            }

            // Save free-text notes as a custom symptom entry so it appears in history
            if (notes != null && notes.isNotEmpty) {
              final notesEntry = SymptomEntry(
                id: IdGenerator.newId('notes'),
                timestamp: now,
                category: SymptomCategory.custom,
                type: '📝 $notes',
              );
              await _repository.addSymptomEntry(notesEntry);
            }

            await _loadData();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Log saved securely (256-bit AES Encrypted)'),
                  backgroundColor: AppColors.dropCoral,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to save log: $e'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _profile == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.dropCoral));
    }

    final cycleDay = CycleCalculator.getCurrentCycleDay(_profile!.lastPeriodStart);
    final phase = CycleCalculator.getCyclePhase(cycleDay, avgCycleLength: _profile!.avgCycleLength, avgPeriodLength: _profile!.avgPeriodLength);
    final daysUntilNext = CycleCalculator.getDaysUntilNextPeriod(_profile!.lastPeriodStart, avgCycleLength: _profile!.avgCycleLength);
    final phaseName = CycleCalculator.getPhaseName(phase);
    final phaseDesc = CycleCalculator.getPhaseDescription(phase);
    final double waterProgress = (_waterGlasses / _waterGoal).clamp(0.0, 1.0);
    final todayKey = SafeBloomDateUtils.dateKey(DateTime.now());
    final hasPeriodLoggedToday = _periodEntries.any(
      (p) => SafeBloomDateUtils.dateKey(p.timestamp) == todayKey,
    );
    final isCurrentlyInPeriod = hasPeriodLoggedToday;

    final cleanToday = SafeBloomDateUtils.dateOnly(DateTime.now());
    final isPredictedPeriodToday = !hasPeriodLoggedToday &&
        CycleCalculator.getPredictedPeriodDates(
          lastPeriodStart: SafeBloomDateUtils.dateOnly(_profile!.lastPeriodStart),
          avgCycleLength: _profile!.avgCycleLength,
          avgPeriodLength: _profile!.avgPeriodLength,
        ).contains(cleanToday);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          // Branding Top Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/safe-bloom-logo.png',
                        height: 36,
                        width: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Safe Bloom', style: AppTypography.brandTitle(fontSize: 26)),
                      Text(
                        'ANONYMOUS MODE ACTIVE',
                        style: AppTypography.brandTagline(color: AppColors.petalRose, fontSize: 9),
                      ),
                      if (_showDeveloperCredit) ...[
                        const SizedBox(height: 2),
                        Text(
                          'DEVELOPED BY ALLEN MT MALIYIL',
                          style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 9),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.shield_outlined, color: AppColors.petalRose),
                onPressed: _handleShieldTap,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Interactive Cycle Wheel Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  isCurrentlyInPeriod
                      ? AppColors.dropCoral.withValues(alpha: 0.15)
                      : isPredictedPeriodToday
                          ? AppColors.dropCoral.withValues(alpha: 0.08)
                          : AppColors.phaseOvulation.withValues(alpha: 0.12),
                  AppColors.lightCardBackground,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: isCurrentlyInPeriod
                    ? AppColors.dropCoral.withValues(alpha: 0.4)
                    : isPredictedPeriodToday
                        ? AppColors.dropCoral.withValues(alpha: 0.3)
                        : AppColors.phaseOvulation.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
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
                    color: isCurrentlyInPeriod
                        ? AppColors.dropCoral
                        : isPredictedPeriodToday
                            ? AppColors.dropCoral.withValues(alpha: 0.8)
                            : AppColors.phaseOvulation,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (isCurrentlyInPeriod || isPredictedPeriodToday) ? Icons.water_drop_rounded : Icons.wb_sunny_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCurrentlyInPeriod
                            ? 'PERIOD LOGGED • DAY $cycleDay'
                            : isPredictedPeriodToday
                                ? 'PERIOD PREDICTED • DAY $cycleDay'
                                : '${phaseName.toUpperCase()} • DAY $cycleDay',
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
                          value: (cycleDay / _profile!.avgCycleLength).clamp(0.0, 1.0),
                          strokeWidth: 12,
                          backgroundColor: AppColors.lightBackground,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCurrentlyInPeriod ? AppColors.dropCoral : AppColors.phaseOvulation,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Day $cycleDay', style: AppTypography.brandTitle(fontSize: 34)),
                          const SizedBox(height: 2),
                          Text(
                            hasPeriodLoggedToday
                                ? 'Period logged today'
                                : isPredictedPeriodToday
                                    ? 'Period predicted today'
                                    : 'Period in $daysUntilNext days',
                            style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.petalRose.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              phase == CyclePhase.ovulation ? 'Fertility: High' : 'Fertility: Low',
                              style: AppTypography.body(fontSize: 10, color: AppColors.petalRose, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Interactive Period Quick Toggle Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.dropCoral,
                      side: const BorderSide(
                        color: AppColors.dropCoral,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    onPressed: () => _togglePeriodToday(isCurrentlyInPeriod),
                    icon: Icon(
                      isCurrentlyInPeriod ? Icons.remove_circle_outline : Icons.water_drop,
                      size: 16,
                      color: AppColors.dropCoral,
                    ),
                    label: Text(
                      isCurrentlyInPeriod ? 'UNMARK / REMOVE TODAY\'S PERIOD LOG' : 'MARK PERIOD STARTED TODAY',
                      style: AppTypography.brandTagline(
                        color: AppColors.dropCoral,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                // Live Flow Intensity Selector (Only displayed when in active period)
                if (isCurrentlyInPeriod) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'TODAY\'S FLOW INTENSITY',
                    style: AppTypography.brandTagline(fontSize: 9, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: FlowLevel.values.map((flow) {
                      final isSelected = _currentFlow == flow;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: ChoiceChip(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                flow.name.toUpperCase(),
                                style: AppTypography.body(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : AppColors.textMain,
                                ),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.dropCoral,
                            backgroundColor: AppColors.lightBackground,
                            onSelected: (_) => _selectFlowLevel(flow),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),

                // Full Log Button
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
                      'LOG ALL SYMPTOMS & NOTES',
                      style: AppTypography.brandTagline(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Daily Hydration & Water Tracker Card
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
                  color: Colors.black.withValues(alpha: 0.02),
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
                    final isSelected = _todaySymptoms.any((s) => s.type == symptom);
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
                      onSelected: (_) => _toggleQuickSymptom(symptom),
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
                  color: Colors.black.withValues(alpha: 0.02),
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
                            '✨ $phaseName Advice:',
                            style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phaseDesc,
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
                            color: AppColors.petalRose.withValues(alpha: 0.12),
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
