import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/utils/safe_bloom_date_utils.dart';
import '../../data/repositories/tracking_repository.dart';
import '../../domain/entities/period_entry.dart';
import '../../domain/entities/symptom_entry.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/services/cycle_calculator.dart';
import '../../domain/services/pregnancy_calculator.dart';
import '../widgets/period_logger_sheet.dart';

class TodayView extends StatefulWidget {
  const TodayView({super.key});

  @override
  State<TodayView> createState() => TodayViewState();
}

class TodayViewState extends State<TodayView> {
  final TrackingRepository _repository = TrackingRepository.instance;
  bool _isLoading = true;

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
      final todayKey = SafeBloomDateUtils.dateKey(DateTime.now());
      FlowLevel flow = FlowLevel.medium;
      for (final p in periods) {
        if (SafeBloomDateUtils.dateKey(p.timestamp) == todayKey) {
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
    final todayKey = SafeBloomDateUtils.dateKey(now);

    try {
      final existingEntry = _periodEntries.cast<PeriodEntry?>().firstWhere(
        (p) => p != null && SafeBloomDateUtils.dateKey(p.timestamp) == todayKey,
        orElse: () => null,
      );

      if (existingEntry != null) {
        final updatedEntry = PeriodEntry(
          id: existingEntry.id,
          timestamp: existingEntry.timestamp,
          flow: flow,
          notes: existingEntry.notes,
        );
        await _repository.updatePeriodEntry(updatedEntry);
      } else {
        final entry = PeriodEntry(
          id: IdGenerator.newId('period'),
          timestamp: now,
          flow: flow,
        );
        await _repository.addPeriodEntry(entry);
      }
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text('Flow intensity set to ${flow.name.toUpperCase()}'),
            backgroundColor: flow == FlowLevel.spotting ? AppColors.petalRose : AppColors.dropCoral,
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

  Future<void> _showAdjustPregnancyDatesDialog() async {
    if (_profile == null) return;
    final now = DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppColors.lightBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.lightCardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Adjust Pregnancy Timeline', style: AppTypography.brandTitle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                'Update your pregnancy timeline using your Last Period Start (LMP) or Doctor\'s Estimated Due Date (EDD).',
                style: AppTypography.body(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.waterBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: AppColors.waterBlue),
                ),
                title: Text('Last Period Start Date (LMP)', style: AppTypography.body(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${_profile!.lastPeriodStart.day} ${SafeBloomDateUtils.monthAbbr(_profile!.lastPeriodStart.month)} ${_profile!.lastPeriodStart.year}',
                  style: AppTypography.brandTagline(color: AppColors.waterBlue, fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _profile!.lastPeriodStart,
                    firstDate: now.subtract(const Duration(days: 300)),
                    lastDate: now,
                  );
                  if (picked != null) {
                    final updated = _profile!.copyWith(lastPeriodStart: picked);
                    await _repository.saveUserProfile(updated);
                    await _loadData();
                  }
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.dropCoral.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.child_care_rounded, color: AppColors.dropCoral),
                ),
                title: Text('Estimated Due Date (EDD)', style: AppTypography.body(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${PregnancyCalculator.getEstimatedDueDate(_profile!.lastPeriodStart).day} ${SafeBloomDateUtils.monthAbbr(PregnancyCalculator.getEstimatedDueDate(_profile!.lastPeriodStart).month)} ${PregnancyCalculator.getEstimatedDueDate(_profile!.lastPeriodStart).year}',
                  style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(ctx);
                  final currentDue = PregnancyCalculator.getEstimatedDueDate(_profile!.lastPeriodStart);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: currentDue.isAfter(now) ? currentDue : now.add(const Duration(days: 180)),
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 290)),
                  );
                  if (picked != null) {
                    final calculatedLmp = PregnancyCalculator.calculateLmpFromDueDate(picked);
                    final updated = _profile!.copyWith(lastPeriodStart: calculatedLmp);
                    await _repository.saveUserProfile(updated);
                    await _loadData();
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
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
    final existingEntry = _periodEntries.cast<PeriodEntry?>().firstWhere(
      (p) => p != null && SafeBloomDateUtils.dateKey(p.timestamp) == todayKey,
      orElse: () => null,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PeriodLoggerSheet(
        selectedDate: DateTime.now(),
        initialFlow: existingEntry?.flow,
        onDelete: existingEntry != null
            ? () async {
                await _repository.deletePeriodEntry(existingEntry.id);
                await refresh();
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
          try {
            final now = DateTime.now();

            if (flow != null) {
              final periodEntry = PeriodEntry(
                id: IdGenerator.newId('period'),
                timestamp: now,
                flow: flow,
                notes: notes,
              );
              await _repository.addPeriodEntry(periodEntry);
            }

            for (final symptom in symptoms) {
              final sEntry = SymptomEntry(
                id: IdGenerator.newId('symptom'),
                timestamp: now,
                category: SymptomCategory.custom,
                type: symptom,
              );
              await _repository.addSymptomEntry(sEntry);
            }
            // Notes are persisted in PeriodEntry.notes — no duplicate
            // SymptomEntry needed (that was polluting the symptom timeline).

            await _loadData();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Log saved securely.'),
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

  Widget _buildModeSelectorBar() {
    if (_profile == null) return const SizedBox.shrink();
    final currentMode = _profile!.appMode;
    final isPregEnabled = _profile!.isPregnancyModeEnabled;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.lightCardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightCardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildModeTab('Track Cycle', AppMode.trackCycle, currentMode == AppMode.trackCycle),
          _buildModeTab('TTC (Conception)', AppMode.ttc, currentMode == AppMode.ttc),
          if (isPregEnabled)
            _buildModeTab('Pregnancy', AppMode.pregnancy, currentMode == AppMode.pregnancy),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, AppMode mode, bool isSelected) {
    return GestureDetector(
      onTap: () async {
        if (isSelected || _profile == null) return;
        final updatedProfile = _profile!.copyWith(
          preferredGoal: mode.name,
          isPregnancyModeEnabled: mode == AppMode.pregnancy ? true : _profile!.isPregnancyModeEnabled,
        );
        await _repository.saveUserProfile(updatedProfile);
        await _loadData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (mode == AppMode.pregnancy ? AppColors.waterBlue : AppColors.dropCoral)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: AppTypography.body(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _profile == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.dropCoral));
    }

    final mode = _profile!.appMode;
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

    final isPeakOvulationToday = CycleCalculator.isPeakOvulationDay(
      cleanToday,
      _profile!.lastPeriodStart,
      avgCycleLength: _profile!.avgCycleLength,
    );

    // Pregnancy calculations
    final pregAge = PregnancyCalculator.getGestationalAge(_profile!.lastPeriodStart);
    final dueDate = PregnancyCalculator.getEstimatedDueDate(_profile!.lastPeriodStart);
    final daysLeftToDueDate = PregnancyCalculator.getDaysUntilDueDate(dueDate);
    final trimester = PregnancyCalculator.getTrimester(pregAge.weeks);
    final babySize = PregnancyCalculator.getBabySizeComparison(pregAge.weeks);
    final totalPregDays = (cleanToday.difference(SafeBloomDateUtils.dateOnly(_profile!.lastPeriodStart)).inDays).clamp(0, 280);
    final pregProgress = (totalPregDays / 280.0).clamp(0.0, 1.0);

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

          // Interactive Mode Selector Bar
          _buildModeSelectorBar(),

          // Interactive Cycle Wheel Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  mode == AppMode.pregnancy
                      ? AppColors.waterBlue.withValues(alpha: 0.15)
                      : isCurrentlyInPeriod
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
                color: mode == AppMode.pregnancy
                    ? AppColors.waterBlue.withValues(alpha: 0.4)
                    : isCurrentlyInPeriod
                        ? AppColors.dropCoral.withValues(alpha: 0.4)
                        : (isPredictedPeriodToday && daysUntilNext >= 0)
                            ? AppColors.dropCoral.withValues(alpha: 0.3)
                            : phase == CyclePhase.overdue
                                ? AppColors.petalRose.withValues(alpha: 0.4)
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
                    color: mode == AppMode.pregnancy
                        ? AppColors.waterBlue
                        : isCurrentlyInPeriod
                            ? AppColors.dropCoral
                            : (isPredictedPeriodToday && daysUntilNext >= 0)
                                ? AppColors.dropCoral.withValues(alpha: 0.8)
                                : phase == CyclePhase.overdue
                                    ? AppColors.petalRose
                                    : AppColors.phaseOvulation,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mode == AppMode.pregnancy
                            ? Icons.child_care
                            : mode == AppMode.ttc
                                ? Icons.favorite_rounded
                                : (isCurrentlyInPeriod || (isPredictedPeriodToday && daysUntilNext >= 0))
                                    ? Icons.water_drop_rounded
                                    : phase == CyclePhase.overdue
                                        ? Icons.schedule_rounded
                                        : Icons.wb_sunny_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        mode == AppMode.pregnancy
                            ? 'PREGNANCY • $trimester'
                            : mode == AppMode.ttc
                                ? (phase == CyclePhase.overdue
                                    ? 'TTC • CYCLE OVERDUE • DAY $cycleDay'
                                    : 'TTC FERTILITY FOCUS • DAY $cycleDay')
                                : isCurrentlyInPeriod
                                    ? (_currentFlow == FlowLevel.spotting
                                        ? 'SPOTTING LOGGED • DAY $cycleDay'
                                        : 'PERIOD LOGGED • DAY $cycleDay')
                                    : (isPredictedPeriodToday && daysUntilNext >= 0)
                                        ? 'PERIOD PREDICTED • DAY $cycleDay'
                                        : '${phaseName.toUpperCase()} • DAY $cycleDay',
                        style: AppTypography.brandTagline(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Circular Cycle / Gestational Dial Widget
                SizedBox(
                  width: 215,
                  height: 215,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0.0,
                            end: mode == AppMode.pregnancy
                                ? pregProgress
                                : (cycleDay / _profile!.avgCycleLength).clamp(0.0, 1.0),
                          ),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return CircularProgressIndicator(
                              value: value,
                              strokeWidth: 10,
                              backgroundColor: AppColors.lightBackground,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                mode == AppMode.pregnancy
                                    ? AppColors.waterBlue
                                    : isCurrentlyInPeriod
                                        ? AppColors.dropCoral
                                        : phase == CyclePhase.overdue
                                            ? AppColors.petalRose
                                            : AppColors.phaseOvulation,
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              mode == AppMode.pregnancy
                                  ? 'Week ${pregAge.weeks}'
                                  : 'Day $cycleDay',
                              style: AppTypography.brandTitle(fontSize: 32),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              mode == AppMode.pregnancy
                                  ? 'Day ${pregAge.days} • $babySize'
                                  : hasPeriodLoggedToday
                                      ? (_currentFlow == FlowLevel.spotting
                                          ? 'Spotting logged today'
                                          : 'Period logged today')
                                      : isPredictedPeriodToday || daysUntilNext == 0
                                          ? 'Period predicted today'
                                          : daysUntilNext < 0
                                              ? 'Period is ${daysUntilNext.abs()} ${daysUntilNext.abs() == 1 ? "day" : "days"} late'
                                              : 'Period in $daysUntilNext days',
                              style: AppTypography.body(fontSize: 11, color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: mode == AppMode.pregnancy ? _showAdjustPregnancyDatesDialog : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: mode == AppMode.pregnancy
                                      ? AppColors.waterBlue.withValues(alpha: 0.15)
                                      : (isPeakOvulationToday && phase != CyclePhase.overdue)
                                          ? const Color(0xFFFFD700).withValues(alpha: 0.25)
                                          : AppColors.petalRose.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: mode == AppMode.pregnancy
                                      ? Border.all(color: AppColors.waterBlue.withValues(alpha: 0.4), width: 1)
                                      : (isPeakOvulationToday && phase != CyclePhase.overdue)
                                          ? Border.all(color: const Color(0xFFD4AF37), width: 1)
                                          : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPeakOvulationToday && mode != AppMode.pregnancy && phase != CyclePhase.overdue) ...[
                                      const Icon(Icons.star_rounded, size: 12, color: Color(0xFFD4AF37)),
                                      const SizedBox(width: 2),
                                    ],
                                    Text(
                                      mode == AppMode.pregnancy
                                          ? '$daysLeftToDueDate days left'
                                          : phase == CyclePhase.overdue
                                              ? 'Fertility: Uncertain'
                                              : isPeakOvulationToday
                                                  ? 'PEAK OVULATION DAY'
                                                  : phase == CyclePhase.ovulation
                                                      ? 'Fertility: High'
                                                      : 'Fertility: Low',
                                      style: AppTypography.body(
                                        fontSize: 10,
                                        color: mode == AppMode.pregnancy
                                            ? AppColors.waterBlue
                                            : (isPeakOvulationToday && mode != AppMode.pregnancy && phase != CyclePhase.overdue)
                                                ? const Color(0xFF8B6508)
                                                : AppColors.petalRose,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (mode == AppMode.pregnancy) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.edit_calendar, size: 11, color: AppColors.waterBlue),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                if (mode == AppMode.pregnancy) ...[
                  // Pregnancy Quick Timeline & Due Date Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.waterBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.waterBlue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_note_rounded, color: AppColors.waterBlue, size: 20),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Due Date: ${dueDate.day} ${SafeBloomDateUtils.monthAbbr(dueDate.month)} ${dueDate.year}',
                                style: AppTypography.body(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Gestational Progress: Week ${pregAge.weeks} of 40 (${(pregProgress * 100).toInt()}%)',
                                style: AppTypography.body(fontSize: 10, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _showAdjustPregnancyDatesDialog,
                          child: Text(
                            'ADJUST',
                            style: AppTypography.brandTagline(color: AppColors.waterBlue, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
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
                        isCurrentlyInPeriod
                            ? (_currentFlow == FlowLevel.spotting
                                ? 'UNMARK / REMOVE TODAY\'S SPOTTING LOG'
                                : 'UNMARK / REMOVE TODAY\'S PERIOD LOG')
                            : 'MARK PERIOD STARTED TODAY',
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
                            child: GestureDetector(
                              onTap: () => _selectFlowLevel(flow),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.dropCoral : AppColors.lightBackground,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                  border: Border.all(
                                    color: isSelected ? AppColors.dropCoral : AppColors.lightCardBorder,
                                    width: 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    flow.name.toUpperCase(),
                                    style: AppTypography.body(
                                      fontSize: 9,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? Colors.white : AppColors.textMain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.md),

                // Full Log Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mode == AppMode.pregnancy ? AppColors.waterBlue : AppColors.dropCoral,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    onPressed: _openLoggerSheet,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: Text(
                      mode == AppMode.pregnancy ? 'LOG PREGNANCY SYMPTOMS & NOTES' : 'LOG ALL SYMPTOMS & NOTES',
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
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: waterProgress),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: AppColors.lightBackground,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.waterBlue),
                      );
                    },
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
                  children: (mode == AppMode.pregnancy
                      ? [
                          '😊 Happy',
                          '🤢 Morning Sickness',
                          '😴 Fatigued',
                          '🪷 Breast Tenderness',
                          '🎈 Bloating',
                          '💖 Baby Kicks',
                        ]
                      : [
                          '😊 Happy',
                          '⚡ Energetic',
                          '😴 Fatigued',
                          '💆 Cramps',
                          '🌸 Calm',
                          '🍫 Cravings',
                        ]).map((symptom) {
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
                      selectedColor: mode == AppMode.pregnancy ? AppColors.waterBlue : AppColors.dropCoral,
                      backgroundColor: AppColors.lightBackground,
                      onSelected: (_) => _toggleQuickSymptom(symptom),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Daily Action Plan / Pregnancy Guidance
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
                        mode == AppMode.pregnancy ? 'Pregnancy Guidance' : 'Daily Action Plan',
                        style: AppTypography.brandTitle(fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      mode == AppMode.pregnancy ? 'WEEK-SYNCED' : 'CYCLE-SYNCED',
                      style: AppTypography.brandTagline(
                        color: mode == AppMode.pregnancy ? AppColors.waterBlue : AppColors.petalRose,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode == AppMode.pregnancy ? '✨ $trimester Focus (Week ${pregAge.weeks}):' : '✨ $phaseName Advice:',
                      style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode == AppMode.pregnancy ? PregnancyCalculator.getPregnancyAdvice(pregAge.weeks) : phaseDesc,
                      style: AppTypography.body(fontSize: 13),
                    ),
                  ],
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
