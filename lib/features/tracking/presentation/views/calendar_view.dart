import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/cycle_group_utils.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/utils/safe_bloom_date_utils.dart';
import '../../data/repositories/tracking_repository.dart';
import '../../domain/entities/period_entry.dart';
import '../../domain/entities/symptom_entry.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/services/cycle_calculator.dart';
import '../widgets/period_logger_sheet.dart';
import '../widgets/historical_period_sheet.dart';

enum CalendarDayStatus {
  loggedPeriod,
  predictedPeriod,
  follicular,
  ovulation,
  luteal,
  regular,
}

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => CalendarViewState();
}

class CalendarViewState extends State<CalendarView> {
  final TrackingRepository _repository = TrackingRepository.instance;
  bool _isLoading = true;

  UserProfile? _profile;
  List<PeriodEntry> _periodEntries = [];
  Map<DateTime, List<SymptomEntry>> _symptomsByDate = {};
  Set<DateTime> _loggedPeriodDates = {};
  Set<DateTime> _predictedPeriodDates = {};
  Set<DateTime> _predictedPeakOvulationDates = {};
  List<DateTime> _sortedCycleStarts = [];

  DateTime _displayMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedDate = DateTime.now();

  // Range Selection for logging past periods (Triggered by Long-Press)
  DateTime? _rangeStartDate;
  DateTime? _rangeEndDate;

  Future<void> refresh() async {
    await _loadData();
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
      final symptoms = await _repository.getAllSymptoms();

      final Map<DateTime, List<SymptomEntry>> symptomsMap = {};
      for (final s in symptoms) {
        final cleanDate = SafeBloomDateUtils.dateOnly(s.timestamp);
        symptomsMap.putIfAbsent(cleanDate, () => []).add(s);
      }

      final Set<DateTime> loggedDates = {};
      for (final p in periods) {
        loggedDates.add(SafeBloomDateUtils.dateOnly(p.timestamp));
      }

      final sortedStarts = CycleGroupUtils.groupIntoCycles(periods)
          .map((c) => SafeBloomDateUtils.dateOnly(CycleGroupUtils.getCycleStartDate(c)))
          .toList()
        ..sort((a, b) => a.compareTo(b));

      final predictedDates = CycleCalculator.getPredictedPeriodDates(
        lastPeriodStart: profile.lastPeriodStart,
        avgCycleLength: profile.avgCycleLength,
        avgPeriodLength: profile.avgPeriodLength,
        monthsAhead: 6,
      );

      final predictedPeakDates = CycleCalculator.getPredictedPeakOvulationDates(
        lastPeriodStart: profile.lastPeriodStart,
        avgCycleLength: profile.avgCycleLength,
        monthsAhead: 6,
      );

      if (mounted) {
        setState(() {
          _profile = profile;
          _periodEntries = periods;
          _symptomsByDate = symptomsMap;
          _loggedPeriodDates = loggedDates;
          _sortedCycleStarts = sortedStarts;
          _predictedPeriodDates = predictedDates;
          _predictedPeakOvulationDates = predictedPeakDates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load calendar data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _previousMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 1);
    });
  }

  DateTime _getCycleAnchorForDate(DateTime date) {
    final clean = SafeBloomDateUtils.dateOnly(date);

    if (_sortedCycleStarts.isNotEmpty) {
      for (int i = _sortedCycleStarts.length - 1; i >= 0; i--) {
        if (!clean.isBefore(_sortedCycleStarts[i])) {
          return _sortedCycleStarts[i];
        }
      }
    }

    return SafeBloomDateUtils.dateOnly(_profile!.lastPeriodStart);
  }

  CalendarDayStatus _getDayStatus(DateTime date) {
    final cleanDate = SafeBloomDateUtils.dateOnly(date);

    if (_loggedPeriodDates.contains(cleanDate)) {
      return CalendarDayStatus.loggedPeriod;
    }

    if (_predictedPeriodDates.contains(cleanDate)) {
      return CalendarDayStatus.predictedPeriod;
    }

    final anchor = _getCycleAnchorForDate(cleanDate);
    final cycleDay = CycleCalculator.getCurrentCycleDay(anchor, now: cleanDate);
    final phase = CycleCalculator.getCyclePhase(
      cycleDay,
      avgCycleLength: _profile!.avgCycleLength,
      avgPeriodLength: _profile!.avgPeriodLength,
    );

    switch (phase) {
      case CyclePhase.menstrual:
        return CalendarDayStatus.regular;
      case CyclePhase.follicular:
        return CalendarDayStatus.follicular;
      case CyclePhase.ovulation:
        return CalendarDayStatus.ovulation;
      case CyclePhase.luteal:
        return CalendarDayStatus.luteal;
      case CyclePhase.overdue:
        return CalendarDayStatus.regular;
    }
  }

  /// Single-tap on date cell: selects date cell, or selects end date if range mode is active
  void _onDateCellTapped(DateTime date) {
    final clean = SafeBloomDateUtils.dateOnly(date);
    setState(() {
      _selectedDate = clean;

      // If range selection is active (start date set, waiting for end date)
      if (_rangeStartDate != null && _rangeEndDate == null) {
        if (!clean.isBefore(_rangeStartDate!)) {
          _rangeEndDate = clean;
        } else {
          _rangeStartDate = clean;
        }
      }
    });
  }

  /// Long-press on date cell: activates range selection mode and sets range start date
  void _onDateCellLongPressed(DateTime date) {
    HapticFeedback.mediumImpact();
    final clean = SafeBloomDateUtils.dateOnly(date);
    setState(() {
      _selectedDate = clean;
      _rangeStartDate = clean;
      _rangeEndDate = null;
    });
  }

  /// Open logger sheet for the selected date
  void _openLoggerForSelectedDate(DateTime date) {
    final cleanDate = SafeBloomDateUtils.dateOnly(date);
    final existingEntry = _periodEntries.cast<PeriodEntry?>().firstWhere(
      (p) => p != null && SafeBloomDateUtils.dateOnly(p.timestamp) == cleanDate,
      orElse: () => null,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PeriodLoggerSheet(
        selectedDate: date,
        initialFlow: existingEntry?.flow,
        onDelete: existingEntry != null
            ? () async {
                await _repository.deletePeriodEntry(existingEntry.id);
                await refresh();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Period log for ${date.day} ${SafeBloomDateUtils.monthAbbr(date.month)} removed.'),
                      backgroundColor: AppColors.dropCoral,
                    ),
                  );
                }
              }
            : null,
        onSave: (flow, symptoms, notes) async {
          try {
            if (flow != null) {
              final periodEntry = PeriodEntry(
                id: IdGenerator.newId('cal_period'),
                timestamp: date,
                flow: flow,
                notes: notes,
              );
              await _repository.addPeriodEntry(periodEntry);
            }

            // Save Symptom Entries for the selected date
            for (final symptom in symptoms) {
              final sEntry = SymptomEntry(
                id: IdGenerator.newId('cal_symptom'),
                timestamp: date,
                category: SymptomCategory.custom,
                type: symptom,
              );
              await _repository.addSymptomEntry(sEntry);
            }
            // Notes are already persisted in PeriodEntry.notes above —
            // no duplicate SymptomEntry needed.

            // Refresh state and calendar UI
            await refresh();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Calendar log saved securely.'),
                  backgroundColor: AppColors.dropCoral,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to save calendar log: $e'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _openHistoricalPeriodSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => HistoricalPeriodSheet(
        onSaveEntries: (entries) async {
          for (final entry in entries) {
            await _repository.addPeriodEntry(entry);
          }
          await refresh();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${entries.length} historical period days logged!'),
                backgroundColor: AppColors.dropCoral,
              ),
            );
          }
        },
      ),
    );
  }

  void _openHistoricalPeriodSheetWithRange(DateTime start, DateTime end) {
    final duration = end.difference(start).inDays + 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => HistoricalPeriodSheet(
        initialStartDate: start,
        initialDurationDays: duration,
        onSaveEntries: (entries) async {
          for (final entry in entries) {
            await _repository.addPeriodEntry(entry);
          }
          setState(() {
            _rangeStartDate = null;
            _rangeEndDate = null;
          });
          await refresh();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${entries.length} period days logged! Predictions updated.'),
                backgroundColor: AppColors.dropCoral,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildRangeActionCard() {
    if (_rangeStartDate == null) return const SizedBox.shrink();

    if (_rangeEndDate == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.dropCoral.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.dropCoral, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Range selection active: Tap end date to select period end (${_rangeStartDate!.day} ${SafeBloomDateUtils.monthAbbr(_rangeStartDate!.month)})',
                style: AppTypography.body(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dropCoral),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18, color: AppColors.dropCoral),
              onPressed: () => setState(() {
                _rangeStartDate = null;
                _rangeEndDate = null;
              }),
            ),
          ],
        ),
      );
    }

    final duration = _rangeEndDate!.difference(_rangeStartDate!).inDays + 1;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dropCoral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.dropCoral, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SELECTED RANGE ($duration DAYS)',
                style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 10),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                onPressed: () => setState(() {
                  _rangeStartDate = null;
                  _rangeEndDate = null;
                }),
              ),
            ],
          ),
          Text(
            '${_rangeStartDate!.day} ${SafeBloomDateUtils.monthAbbr(_rangeStartDate!.month)} – ${_rangeEndDate!.day} ${SafeBloomDateUtils.monthAbbr(_rangeEndDate!.month)} ${_rangeEndDate!.year}',
            style: AppTypography.brandTitle(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.dropCoral),
              onPressed: () => _openHistoricalPeriodSheetWithRange(_rangeStartDate!, _rangeEndDate!),
              icon: const Icon(Icons.edit_calendar, size: 16, color: Colors.white),
              label: Text(
                'LOG PERIOD FOR THIS RANGE',
                style: AppTypography.brandTagline(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _profile == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.dropCoral));
    }

    final cleanSelected = SafeBloomDateUtils.dateOnly(_selectedDate);
    final selectedStatus = _getDayStatus(_selectedDate);
    final selectedAnchor = _getCycleAnchorForDate(cleanSelected);
    final cycleDay = CycleCalculator.getCurrentCycleDay(selectedAnchor, now: cleanSelected);
    final phase = CycleCalculator.getCyclePhase(cycleDay, avgCycleLength: _profile!.avgCycleLength, avgPeriodLength: _profile!.avgPeriodLength);
    final selectedSymptoms = _symptomsByDate[cleanSelected] ?? [];

    final PeriodEntry? loggedEntry = _periodEntries.cast<PeriodEntry?>().firstWhere(
          (p) => p != null && SafeBloomDateUtils.dateOnly(p.timestamp) == cleanSelected,
          orElse: () => null,
        );

    final daysInMonth = DateUtils.getDaysInMonth(_displayMonth.year, _displayMonth.month);
    final firstWeekday = DateTime(_displayMonth.year, _displayMonth.month, 1).weekday; // 1 = Monday
    final leadingOffset = firstWeekday - 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Month Navigation & Log Past Period Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Cycle Calendar',
                        style: AppTypography.brandTitle(fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.dropCoral, size: 20),
                      tooltip: 'Log Past Period Range',
                      onPressed: _openHistoricalPeriodSheet,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_left, color: AppColors.dropCoral, size: 22),
                    onPressed: _previousMonth,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lightCardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.lightCardBorder),
                    ),
                    child: Text(
                      '${SafeBloomDateUtils.monthAbbr(_displayMonth.month)} ${_displayMonth.year}',
                      style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 11),
                    ),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_right, color: AppColors.dropCoral, size: 22),
                    onPressed: _nextMonth,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Phase & Period Legend Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildLegendItem('Logged Period', AppColors.dropCoral, isLogged: true),
                const SizedBox(width: AppSpacing.sm),
                _buildLegendItem('Predicted Period', AppColors.dropCoral, isPredicted: true),
                const SizedBox(width: AppSpacing.sm),
                _buildLegendItem('Follicular', AppColors.phaseFollicular),
                const SizedBox(width: AppSpacing.sm),
                _buildLegendItem('Ovulation', AppColors.phaseOvulation),
                const SizedBox(width: AppSpacing.sm),
                _buildLegendItem('Luteal', AppColors.phaseLuteal),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Range Action Card (If Range Selected)
          _buildRangeActionCard(),

          // Calendar Card Grid
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
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                    return Text(day, style: AppTypography.brandTagline(color: AppColors.textMuted, fontSize: 10));
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.sm),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: daysInMonth + leadingOffset,
                  itemBuilder: (context, index) {
                    if (index < leadingOffset) {
                      return const SizedBox.shrink();
                    }

                    final day = index - leadingOffset + 1;
                    final date = DateTime(_displayMonth.year, _displayMonth.month, day);
                    final cleanDate = SafeBloomDateUtils.dateOnly(date);
                    final now = DateTime.now();
                    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                    final isSelected = date.year == _selectedDate.year &&
                        date.month == _selectedDate.month &&
                        date.day == _selectedDate.day;

                    final bool isInRange = _rangeStartDate != null &&
                        _rangeEndDate != null &&
                        !cleanDate.isBefore(_rangeStartDate!) &&
                        !cleanDate.isAfter(_rangeEndDate!);
                    final bool isRangeStart = _rangeStartDate != null && cleanDate == _rangeStartDate;
                    final bool isRangeEnd = _rangeEndDate != null && cleanDate == _rangeEndDate;

                    final dayStatus = _getDayStatus(date);
                    final hasSymptoms = _symptomsByDate.containsKey(cleanDate);

                    // Styling decisions per dayStatus
                    Color cellColor;
                    Border cellBorder;
                    Color textColor;

                    switch (dayStatus) {
                      case CalendarDayStatus.loggedPeriod:
                        cellColor = AppColors.dropCoral;
                        cellBorder = isSelected
                            ? Border.all(color: AppColors.deepPlum, width: 2.5)
                            : isToday
                                ? Border.all(color: AppColors.dropCoral, width: 2)
                                : Border.all(color: AppColors.dropCoral, width: 1);
                        textColor = Colors.white;
                        break;
                      case CalendarDayStatus.predictedPeriod:
                        cellColor = AppColors.dropCoral.withValues(alpha: 0.15);
                        cellBorder = isSelected
                            ? Border.all(color: AppColors.dropCoral, width: 2.5)
                            : isToday
                                ? Border.all(color: AppColors.dropCoral, width: 2)
                                : Border.all(color: AppColors.dropCoral, width: 1.5);
                        textColor = isSelected ? AppColors.dropCoral : AppColors.textMain;
                        break;
                      case CalendarDayStatus.follicular:
                        cellColor = isSelected ? AppColors.phaseFollicular : AppColors.phaseFollicular.withValues(alpha: 0.2);
                        cellBorder = isSelected
                            ? Border.all(color: AppColors.dropCoral, width: 2)
                            : isToday
                                ? Border.all(color: AppColors.dropCoral, width: 1.5)
                                : Border.all(color: AppColors.phaseFollicular.withValues(alpha: 0.4));
                        textColor = isSelected ? Colors.white : (isToday ? AppColors.dropCoral : AppColors.textMain);
                        break;
                      case CalendarDayStatus.ovulation:
                        cellColor = isSelected ? AppColors.phaseOvulation : AppColors.phaseOvulation.withValues(alpha: 0.2);
                        cellBorder = isSelected
                            ? Border.all(color: AppColors.dropCoral, width: 2)
                            : isToday
                                ? Border.all(color: AppColors.dropCoral, width: 1.5)
                                : Border.all(color: AppColors.phaseOvulation.withValues(alpha: 0.4));
                        textColor = isSelected ? Colors.white : (isToday ? AppColors.dropCoral : AppColors.textMain);
                        break;
                      case CalendarDayStatus.luteal:
                        cellColor = isSelected ? AppColors.phaseLuteal : AppColors.phaseLuteal.withValues(alpha: 0.2);
                        cellBorder = isSelected
                            ? Border.all(color: AppColors.dropCoral, width: 2)
                            : isToday
                                ? Border.all(color: AppColors.dropCoral, width: 1.5)
                                : Border.all(color: AppColors.phaseLuteal.withValues(alpha: 0.4));
                        textColor = isSelected ? Colors.white : (isToday ? AppColors.dropCoral : AppColors.textMain);
                        break;
                      case CalendarDayStatus.regular:
                        cellColor = isSelected ? AppColors.dropCoral.withValues(alpha: 0.2) : AppColors.lightBackground;
                        cellBorder = isSelected
                            ? Border.all(color: AppColors.dropCoral, width: 2)
                            : isToday
                                ? Border.all(color: AppColors.dropCoral, width: 1.5)
                                : Border.all(color: AppColors.lightCardBorder);
                        textColor = isToday ? AppColors.dropCoral : AppColors.textMain;
                        break;
                    }

                    if (isInRange) {
                      cellColor = AppColors.dropCoral.withValues(alpha: 0.25);
                      cellBorder = Border.all(
                        color: AppColors.dropCoral,
                        width: (isRangeStart || isRangeEnd) ? 2.5 : 1.5,
                      );
                    } else if (isRangeStart) {
                      cellBorder = Border.all(color: AppColors.dropCoral, width: 2.5);
                    }

                    return BouncingCalendarCell(
                      onTap: () => _onDateCellTapped(date),
                      onLongPress: () => _onDateCellLongPressed(date),
                      onDoubleTap: () => _openLoggerForSelectedDate(date),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: cellColor,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          border: cellBorder,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_predictedPeakOvulationDates.contains(date)) ...[
                              const Icon(Icons.star_rounded, size: 10, color: Color(0xFFD4AF37)),
                              const SizedBox(height: 1),
                            ],
                            Text(
                              '$day',
                              style: AppTypography.body(
                                fontSize: 13,
                                fontWeight: (isSelected || isToday || dayStatus == CalendarDayStatus.loggedPeriod || isRangeStart || isRangeEnd)
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: (isInRange && dayStatus != CalendarDayStatus.loggedPeriod) ? AppColors.dropCoral : textColor,
                              ),
                            ),
                            if (hasSymptoms) ...[
                              const SizedBox(height: 2),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: dayStatus == CalendarDayStatus.loggedPeriod ? Colors.white : AppColors.dropCoral,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Selected Day Details & Log Action Card
          _buildDetailCard(selectedStatus, cycleDay, phase, selectedSymptoms, loggedEntry),
        ],
      ),
    );
  }

  Widget _buildDetailCard(
    CalendarDayStatus status,
    int cycleDay,
    CyclePhase phase,
    List<SymptomEntry> selectedSymptoms,
    PeriodEntry? loggedEntry,
  ) {
    String badgeText;
    Color badgeBg;
    Color badgeFg;
    Border? badgeBorder;
    String statusDetail;

    if (status == CalendarDayStatus.loggedPeriod) {
      final isSpottingOnly = loggedEntry?.flow == FlowLevel.spotting;
      badgeText = isSpottingOnly ? 'SPOTTING LOGGED' : 'LOGGED PERIOD';
      badgeBg = isSpottingOnly ? AppColors.petalRose : AppColors.dropCoral;
      badgeFg = Colors.white;
      badgeBorder = null;
      statusDetail = isSpottingOnly
          ? 'Spotting logged • Not a confirmed period start'
          : loggedEntry?.flow != null
              ? 'Confirmed Period • Flow: ${loggedEntry!.flow.name.toUpperCase()}'
              : 'Confirmed Period Logged';
    } else if (status == CalendarDayStatus.predictedPeriod) {
      badgeText = 'PREDICTED PERIOD';
      badgeBg = AppColors.dropCoral.withValues(alpha: 0.15);
      badgeFg = AppColors.dropCoral;
      badgeBorder = Border.all(color: AppColors.dropCoral, width: 1);
      statusDetail = 'Predicted Period (Not logged yet)';
    } else {
      badgeText = CycleCalculator.getPhaseName(phase).toUpperCase();
      badgeBg = status == CalendarDayStatus.follicular
          ? AppColors.phaseFollicular
          : status == CalendarDayStatus.ovulation
              ? AppColors.phaseOvulation
              : status == CalendarDayStatus.luteal
                  ? AppColors.phaseLuteal
                  : phase == CyclePhase.overdue
                      ? AppColors.petalRose
                      : AppColors.textMuted;
      badgeFg = Colors.white;
      badgeBorder = null;
      statusDetail = phase == CyclePhase.overdue
          ? 'Cycle day $cycleDay exceeds typical cycle length (${_profile!.avgCycleLength} days). Awaiting period log.'
          : 'No period logged for this date';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.lightCardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: status == CalendarDayStatus.loggedPeriod
              ? AppColors.dropCoral
              : status == CalendarDayStatus.predictedPeriod
                  ? AppColors.dropCoral.withValues(alpha: 0.5)
                  : AppColors.lightCardBorder,
        ),
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
                  '${_selectedDate.day} ${SafeBloomDateUtils.monthAbbr(_selectedDate.month)} Overview',
                  style: AppTypography.brandTitle(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: badgeBorder,
                ),
                child: Text(
                  badgeText,
                  style: AppTypography.brandTagline(color: badgeFg, fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$statusDetail • Cycle Day $cycleDay',
            style: AppTypography.body(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.favorite_border, size: 16, color: AppColors.petalRose),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  selectedSymptoms.isNotEmpty
                      ? 'Logged symptoms: ${selectedSymptoms.map((s) => s.type).join(", ")}'
                      : 'No symptoms logged for this day',
                  style: AppTypography.body(fontSize: 12, color: AppColors.textMain),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Button to Log Data for Selected Date
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dropCoral,
                padding: const EdgeInsets.all(AppSpacing.sm),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
              onPressed: () => _openLoggerForSelectedDate(_selectedDate),
              icon: const Icon(Icons.edit_note, color: Colors.white, size: 18),
              label: Text(
                status == CalendarDayStatus.loggedPeriod
                    ? 'UPDATE LOG FOR ${_selectedDate.day} ${SafeBloomDateUtils.monthAbbr(_selectedDate.month).toUpperCase()}'
                    : 'LOG FLOW & SYMPTOMS FOR ${_selectedDate.day} ${SafeBloomDateUtils.monthAbbr(_selectedDate.month).toUpperCase()}',
                style: AppTypography.brandTagline(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
          if (status == CalendarDayStatus.loggedPeriod && loggedEntry != null) ...[
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.dropCoral,
                  side: const BorderSide(color: AppColors.dropCoral),
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                ),
                onPressed: () async {
                  await _repository.deletePeriodEntry(loggedEntry.id);
                  await refresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Period log for ${_selectedDate.day} ${SafeBloomDateUtils.monthAbbr(_selectedDate.month)} removed.'),
                        backgroundColor: AppColors.dropCoral,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.delete_outline, color: AppColors.dropCoral, size: 16),
                label: Text(
                  'UNCHECK / REMOVE PERIOD FOR THIS DAY',
                  style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {bool isLogged = false, bool isPredicted = false}) {
    BoxDecoration decoration;
    if (isPredicted) {
      decoration = BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      );
    } else {
      decoration = BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      );
    }

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: decoration,
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.body(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}

class BouncingCalendarCell extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDoubleTap;

  const BouncingCalendarCell({
    super.key,
    required this.child,
    required this.onTap,
    required this.onLongPress,
    required this.onDoubleTap,
  });

  @override
  State<BouncingCalendarCell> createState() => _BouncingCalendarCellState();
}

class _BouncingCalendarCellState extends State<BouncingCalendarCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 260),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.86).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerBounce() async {
    await _controller.forward();
    if (mounted) {
      await _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        _triggerBounce();
        widget.onTap();
      },
      onLongPress: () {
        _triggerBounce();
        widget.onLongPress();
      },
      onDoubleTap: () {
        _triggerBounce();
        widget.onDoubleTap();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
