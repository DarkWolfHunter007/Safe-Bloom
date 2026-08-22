import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/cycle_group_utils.dart';
import '../../../../core/utils/safe_bloom_date_utils.dart';
import '../../data/repositories/tracking_repository.dart';
import '../../domain/entities/period_entry.dart';
import '../../domain/entities/user_profile.dart';
import '../widgets/historical_period_sheet.dart';
import 'edit_period_view.dart';

class CycleHistoryView extends StatefulWidget {
  const CycleHistoryView({super.key});

  @override
  State<CycleHistoryView> createState() => _CycleHistoryViewState();
}

class _CycleHistoryViewState extends State<CycleHistoryView> {
  final TrackingRepository _repository = TrackingRepository.instance;
  bool _isLoading = true;
  UserProfile? _profile;
  List<List<PeriodEntry>> _cycles = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await _repository.getUserProfile();
    final entries = await _repository.getPeriodEntries();
    final cycles = CycleGroupUtils.groupIntoCycles(entries);

    if (mounted) {
      setState(() {
        _profile = profile;
        _cycles = cycles.reversed.toList(); // Newest first
        _isLoading = false;
      });
    }
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
          await _loadData();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${entries.length} historical period days logged! Predictions updated.'),
                backgroundColor: AppColors.dropCoral,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.dropCoral));
    }

    final profile = _profile;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Cycle History & Stats',
          style: AppTypography.brandTitle(fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.dropCoral),
            tooltip: 'Log Past Period',
            onPressed: _openHistoricalPeriodSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overview Stats Card
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
                    Text('CYCLE METRICS SUMMARY', style: AppTypography.brandTagline(fontSize: 10)),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile('Avg Cycle', '${profile?.avgCycleLength ?? 28} days'),
                        ),
                        Expanded(
                          child: _buildMetricTile('Avg Period', '${profile?.avgPeriodLength ?? 5} days'),
                        ),
                        Expanded(
                          child: _buildMetricTile('Total Logged', '${_cycles.length} cycles'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PAST LOGGED CYCLES', style: AppTypography.brandTagline(fontSize: 10)),
                  TextButton.icon(
                    onPressed: _openHistoricalPeriodSheet,
                    icon: const Icon(Icons.add, size: 14, color: AppColors.dropCoral),
                    label: Text('LOG PAST PERIOD', style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              if (_cycles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.lightCardBackground,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.history_toggle_off, color: AppColors.textMuted, size: 40),
                      const SizedBox(height: AppSpacing.sm),
                      Text('No cycle history logged yet', style: AppTypography.body(color: AppColors.textMuted)),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.dropCoral),
                        onPressed: _openHistoricalPeriodSheet,
                        icon: const Icon(Icons.add, size: 16, color: Colors.white),
                        label: Text('LOG YOUR FIRST PAST PERIOD', style: AppTypography.brandTagline(color: Colors.white, fontSize: 11)),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _cycles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final cycle = _cycles[index];
                    final start = CycleGroupUtils.getCycleStartDate(cycle);
                    final end = CycleGroupUtils.getCycleEndDate(cycle);
                    final periodDays = CycleGroupUtils.getCycleActiveDurationDays(cycle);

                    String cycleLenStr = 'Current';
                    if (index < _cycles.length - 1) {
                      final prevCycleStart = CycleGroupUtils.getCycleStartDate(_cycles[index + 1]);
                      final d1 = DateTime(prevCycleStart.year, prevCycleStart.month, prevCycleStart.day);
                      final d2 = DateTime(start.year, start.month, start.day);
                      final cycleDays = d2.difference(d1).inDays;
                      cycleLenStr = '$cycleDays-day cycle';
                    }

                    return Material(
                      color: AppColors.lightCardBackground,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(color: AppColors.lightCardBorder),
                        ),
                        child: ListTile(
                          title: Text(
                            '${start.day} ${SafeBloomDateUtils.monthAbbr(start.month)} – ${end.day} ${SafeBloomDateUtils.monthAbbr(end.month)} ${end.year}',
                            style: AppTypography.body(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Duration: $periodDays days bleeding • $cycleLenStr',
                            style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_note, color: AppColors.dropCoral),
                                onPressed: () async {
                                  final updated = await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => EditPeriodView(
                                        entry: cycle.first,
                                        fullCycle: cycle,
                                      ),
                                    ),
                                  );
                                  if (updated == true) {
                                    _loadData();
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.dropCoral),
                                onPressed: () => _deleteCycle(cycle),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCycle(List<PeriodEntry> cycle) async {
    final start = cycle.first.timestamp;
    final end = cycle.last.timestamp;
    final dateRangeStr = '${start.day} ${SafeBloomDateUtils.monthAbbr(start.month)} – ${end.day} ${SafeBloomDateUtils.monthAbbr(end.month)} ${end.year}';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.lightCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        title: Text(
          'Delete Entire Period Cycle?',
          style: AppTypography.brandTitle(fontSize: 20),
        ),
        content: Text(
          'Are you sure you want to delete all period logs recorded for $dateRangeStr (${cycle.length} days)?',
          style: AppTypography.body(fontSize: 13, color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
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
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'DELETE CYCLE',
              style: AppTypography.brandTagline(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final entry in cycle) {
        await _repository.deletePeriodEntry(entry.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Period cycle deleted completely'),
            backgroundColor: AppColors.dropCoral,
          ),
        );
      }
      await _loadData();
    }
  }

  Widget _buildMetricTile(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.body(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: AppTypography.brandTitle(fontSize: 16, color: AppColors.dropCoral)),
      ],
    );
  }
}
