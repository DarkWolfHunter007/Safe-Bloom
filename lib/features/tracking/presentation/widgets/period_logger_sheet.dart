import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/period_entry.dart';

class PeriodLoggerSheet extends StatefulWidget {
  final DateTime? selectedDate;
  final Function(FlowLevel flow, List<String> symptoms, String? notes) onSave;
  final VoidCallback? onDelete;

  const PeriodLoggerSheet({
    super.key,
    this.selectedDate,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<PeriodLoggerSheet> createState() => _PeriodLoggerSheetState();
}

class _PeriodLoggerSheetState extends State<PeriodLoggerSheet> {
  FlowLevel _selectedFlow = FlowLevel.medium;
  final Set<String> _selectedSymptoms = {};
  final TextEditingController _notesController = TextEditingController();

  final List<String> _symptomOptions = const [
    '⚡ Cramps',
    '😊 Happy',
    '😴 Fatigued',
    '💆 Headache',
    '🍫 Cravings',
    '🌸 Calm',
    '🩸 Spotting',
    '🤢 Nausea',
    '⚡ High Energy',
    '💧 Water Retention',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final targetDate = widget.selectedDate ?? DateTime.now();
    final isToday = targetDate.year == DateTime.now().year &&
        targetDate.month == DateTime.now().month &&
        targetDate.day == DateTime.now().day;

    final dateTitle = isToday
        ? "Log Today's Cycle"
        : "Log Cycle for ${targetDate.day} ${_getMonthName(targetDate.month)} ${targetDate.year}";

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
                dateTitle,
                style: AppTypography.brandTitle(fontSize: 22),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'PERIOD FLOW',
                style: AppTypography.brandTagline(fontSize: 10),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: FlowLevel.values.map((flow) {
                  final isSelected = _selectedFlow == flow;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: ChoiceChip(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            flow.name.toUpperCase(),
                            style: AppTypography.body(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.textMain,
                            ),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.dropCoral,
                        backgroundColor: AppColors.lightBackground,
                        onSelected: (val) => setState(() => _selectedFlow = flow),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'SYMPTOMS & MOOD',
                style: AppTypography.brandTagline(fontSize: 10),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: _symptomOptions.map((symptom) {
                  final isSelected = _selectedSymptoms.contains(symptom);
                  return FilterChip(
                    label: Text(
                      symptom,
                      style: AppTypography.body(
                        fontSize: 12,
                        color: isSelected ? Colors.white : AppColors.textMain,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.petalRose,
                    backgroundColor: AppColors.lightBackground,
                    onSelected: (val) {
                      setState(() {
                        isSelected ? _selectedSymptoms.remove(symptom) : _selectedSymptoms.add(symptom);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'ADDITIONAL NOTES',
                style: AppTypography.brandTagline(fontSize: 10),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _notesController,
                maxLines: 3,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                style: AppTypography.body(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Describe any other symptoms, feelings, or observations…',
                  hintStyle: AppTypography.body(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.lightBackground,
                  counterStyle: AppTypography.body(fontSize: 11, color: AppColors.textMuted),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: const BorderSide(color: AppColors.petalRose, width: 1.5),
                  ),
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
                  onPressed: () {
                    final notes = _notesController.text.trim();
                    widget.onSave(
                      _selectedFlow,
                      _selectedSymptoms.toList(),
                      notes.isEmpty ? null : notes,
                    );
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'SAVE ENCRYPTED LOG',
                    style: AppTypography.brandTagline(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              if (widget.onDelete != null) ...[
                const SizedBox(height: AppSpacing.sm),
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
                    onPressed: () {
                      widget.onDelete!();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.dropCoral),
                    label: Text(
                      'UNCHECK / REMOVE PERIOD LOG',
                      style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
