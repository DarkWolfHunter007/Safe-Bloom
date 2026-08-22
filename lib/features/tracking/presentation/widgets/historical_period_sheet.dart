import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/utils/safe_bloom_date_utils.dart';
import '../../domain/entities/period_entry.dart';

class HistoricalPeriodSheet extends StatefulWidget {
  final DateTime? initialStartDate;
  final int? initialDurationDays;
  final Function(List<PeriodEntry> entries) onSaveEntries;

  const HistoricalPeriodSheet({
    super.key,
    this.initialStartDate,
    this.initialDurationDays,
    required this.onSaveEntries,
  });

  @override
  State<HistoricalPeriodSheet> createState() => _HistoricalPeriodSheetState();
}

class _HistoricalPeriodSheetState extends State<HistoricalPeriodSheet> {
  late DateTime _startDate;
  late int _durationDays;
  FlowLevel _uniformFlow = FlowLevel.medium;
  bool _isCustomDailyFlows = false;
  final Map<int, FlowLevel> _dailyFlows = {};
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate ?? DateTime.now().subtract(const Duration(days: 28));
    _durationDays = widget.initialDurationDays ?? 5;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  DateTime get _endDate => _startDate.add(Duration(days: _durationDays - 1));

  void _submit() {
    final notes = _notesController.text.trim();
    final List<PeriodEntry> entries = [];

    for (int i = 0; i < _durationDays; i++) {
      final date = SafeBloomDateUtils.dateOnly(_startDate.add(Duration(days: i)));
      final flow = _isCustomDailyFlows ? (_dailyFlows[i] ?? _uniformFlow) : _uniformFlow;

      entries.add(
        PeriodEntry(
          id: IdGenerator.newId('hist_period'),
          timestamp: date,
          flow: flow,
          notes: notes.isEmpty ? 'Historical log' : notes,
        ),
      );
    }

    widget.onSaveEntries(entries);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.lightCardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Log Past Period Range',
                style: AppTypography.brandTitle(fontSize: 22),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Add historical period dates & daily flow patterns to refine predictions',
                style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Date Range Selection Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.lightCardBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('START DATE', style: AppTypography.brandTagline(fontSize: 9)),
                            const SizedBox(height: 2),
                            Text(
                              '${_startDate.day} ${SafeBloomDateUtils.monthAbbr(_startDate.month)} ${_startDate.year}',
                              style: AppTypography.brandTitle(fontSize: 18),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.dropCoral),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 730)),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _startDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                          label: Text('CHANGE', style: AppTypography.brandTagline(color: Colors.white, fontSize: 10)),
                        ),
                      ],
                    ),
                    const Divider(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PERIOD DURATION', style: AppTypography.brandTagline(fontSize: 9)),
                            const SizedBox(height: 2),
                            Text(
                              '$_durationDays Days (Ends ${_endDate.day} ${SafeBloomDateUtils.monthAbbr(_endDate.month)})',
                              style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Slider(
                      key: const ValueKey('historical_period_duration_slider'),
                      value: _durationDays.toDouble(),
                      min: 1,
                      max: 12,
                      divisions: 11,
                      activeColor: AppColors.dropCoral,
                      inactiveColor: AppColors.lightCardBorder,
                      onChanged: (val) => setState(() => _durationDays = val.round()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Flow Mode Toggle Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _isCustomDailyFlows ? 'DAILY FLOW BREAKDOWN' : 'UNIFORM FLOW LEVEL',
                      style: AppTypography.brandTagline(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => setState(() => _isCustomDailyFlows = !_isCustomDailyFlows),
                    icon: Icon(
                      _isCustomDailyFlows ? Icons.tune : Icons.edit_calendar,
                      size: 14,
                      color: AppColors.dropCoral,
                    ),
                    label: Text(
                      _isCustomDailyFlows ? 'USE UNIFORM FLOW' : 'CUSTOMIZE DAILY FLOWS',
                      style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              if (!_isCustomDailyFlows) ...[
                Row(
                  children: FlowLevel.values.map((flow) {
                    final isSelected = _uniformFlow == flow;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: GestureDetector(
                          onTap: () => setState(() => _uniformFlow = flow),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.dropCoral : AppColors.lightBackground,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              border: Border.all(
                                color: isSelected ? AppColors.dropCoral : AppColors.lightCardBorder,
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                flow.name.toUpperCase(),
                                style: AppTypography.body(
                                  fontSize: 10,
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
              ] else ...[
                // Custom Day-by-Day Breakdown List
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.dropCoral.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: List.generate(_durationDays, (i) {
                      final date = _startDate.add(Duration(days: i));
                      final selectedFlow = _dailyFlows[i] ?? _uniformFlow;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(
                                '${date.day} ${SafeBloomDateUtils.monthAbbr(date.month)}',
                                style: AppTypography.body(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: FlowLevel.values.map((flow) {
                                  final isSelected = selectedFlow == flow;
                                  final label = flow.name[0].toUpperCase() + flow.name.substring(1);
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                      child: GestureDetector(
                                        onTap: () => setState(() => _dailyFlows[i] = flow),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppColors.dropCoral : AppColors.lightCardBackground,
                                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                            border: Border.all(
                                              color: isSelected ? AppColors.dropCoral : AppColors.lightCardBorder,
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              label,
                                              style: AppTypography.body(
                                                fontSize: 10,
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
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),

              Text('NOTES (OPTIONAL)', style: AppTypography.brandTagline(fontSize: 10)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _notesController,
                maxLines: 2,
                maxLength: 150,
                style: AppTypography.body(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Past historical cycle',
                  hintStyle: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.lightBackground,
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dropCoral,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  onPressed: _submit,
                  child: Text(
                    'LOG HISTORICAL PERIOD ($_durationDays DAYS)',
                    style: AppTypography.brandTagline(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
