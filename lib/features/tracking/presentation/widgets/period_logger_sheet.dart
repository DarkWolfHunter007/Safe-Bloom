import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/period_entry.dart';

class PeriodLoggerSheet extends StatefulWidget {
  final DateTime? selectedDate;
  final FlowLevel? initialFlow;
  final Function(FlowLevel? flow, List<String> symptoms, String? notes) onSave;
  final VoidCallback? onDelete;

  const PeriodLoggerSheet({
    super.key,
    this.selectedDate,
    this.initialFlow,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<PeriodLoggerSheet> createState() => _PeriodLoggerSheetState();
}

class _PeriodLoggerSheetState extends State<PeriodLoggerSheet> {
  late FlowLevel _selectedFlow;
  final Set<String> _selectedSymptoms = {};
  final TextEditingController _notesController = TextEditingController();

  final Map<String, List<String>> _categorizedSymptoms = const {
    'BODY & PAIN': [
      '⚡ Cramps',
      '💆 Headache',
      '🤢 Nausea',
      '🎈 Bloating',
      '🦴 Backache',
      '🪷 Breast Tenderness',
    ],
    'MOOD & MIND': [
      '😊 Happy',
      '🌸 Calm',
      '⚡ High Energy',
      '😴 Fatigued',
      '🌀 Anxious',
      '⛈️ Irritable',
      '💧 Sad',
    ],
    'CERVICAL FLUID': [
      '🥚 Egg White (Fertile)',
      '💧 Watery',
      '🥛 Creamy',
      '🍯 Sticky',
      '🌵 Dry',
    ],
    'BIOMARKERS': [
      '🌡️ BBT: 97.5°F',
      '🌡️ BBT: 98.0°F',
      '🌡️ BBT: 98.6°F',
      '🌡️ BBT: 99.0°F',
    ],
    'INTIMACY': [
      '🔒 Protected Sex',
      '🔓 Unprotected Sex',
      '💖 High Libido',
    ],
  };

  Widget _buildSymptomCategorySection(String title, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          style: AppTypography.brandTagline(fontSize: 10),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: options.map((symptom) {
            final isSelected = _selectedSymptoms.contains(symptom);
            return FilterChip(
              visualDensity: VisualDensity.compact,
              label: Text(
                symptom,
                style: AppTypography.body(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textMain,
                ),
              ),
              selected: isSelected,
              selectedColor: (title == 'CERVICAL FLUID' || title == 'BIOMARKERS')
                  ? AppColors.phaseOvulation
                  : AppColors.petalRose,
              backgroundColor: AppColors.lightBackground,
              onSelected: (val) {
                setState(() {
                  isSelected ? _selectedSymptoms.remove(symptom) : _selectedSymptoms.add(symptom);
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedFlow = widget.initialFlow ?? FlowLevel.medium;
  }

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
        ? "Log Today's Symptoms & Notes"
        : "Log Symptoms for ${targetDate.day} ${_getMonthName(targetDate.month)} ${targetDate.year}";

    final isPeriodActive = widget.initialFlow != null;

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
              if (isPeriodActive) ...[
                Text(
                  'PERIOD FLOW INTENSITY',
                  style: AppTypography.brandTagline(fontSize: 10),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: FlowLevel.values.map((flow) {
                    final isSelected = _selectedFlow == flow;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedFlow = flow),
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
                const SizedBox(height: AppSpacing.md),
              ],
              ..._categorizedSymptoms.entries.map((entry) {
                return _buildSymptomCategorySection(entry.key, entry.value);
              }),
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
                      isPeriodActive ? _selectedFlow : null,
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
                      'UNMARK / REMOVE PERIOD LOG',
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
