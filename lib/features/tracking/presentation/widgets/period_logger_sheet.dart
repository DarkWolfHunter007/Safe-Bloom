import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/period_entry.dart';

class PeriodLoggerSheet extends StatefulWidget {
  final Function(FlowLevel flow, List<String> symptoms) onSave;

  const PeriodLoggerSheet({super.key, required this.onSave});

  @override
  State<PeriodLoggerSheet> createState() => _PeriodLoggerSheetState();
}

class _PeriodLoggerSheetState extends State<PeriodLoggerSheet> {
  FlowLevel _selectedFlow = FlowLevel.medium;
  final Set<String> _selectedSymptoms = {'Cramps'};

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
                    color: AppColors.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "Log Today's Cycle",
                style: AppTypography.brandTitle(fontSize: 24),
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
                'SYMPTOMS',
                style: AppTypography.brandTagline(fontSize: 10),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: ['⚡ Cramps', '😊 Happy', '😴 Fatigued', '💆 Headache'].map((symptom) {
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
                    widget.onSave(_selectedFlow, _selectedSymptoms.toList());
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'SAVE ENCRYPTED LOG',
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
