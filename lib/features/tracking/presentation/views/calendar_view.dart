import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  int _selectedDay = 14;

  String _getPhaseForDay(int day) {
    if (day <= 5) return 'Menstrual Phase';
    if (day <= 11) return 'Follicular Phase';
    if (day <= 16) return 'Ovulation Phase';
    return 'Luteal Phase';
  }

  Color _getPhaseColorForDay(int day) {
    if (day <= 5) return AppColors.phaseMenstrual;
    if (day <= 11) return AppColors.phaseFollicular;
    if (day <= 16) return AppColors.phaseOvulation;
    return AppColors.phaseLuteal;
  }

  String _getFertilityForDay(int day) {
    if (day >= 12 && day <= 16) return 'High Chance of Pregnancy';
    if (day >= 10 && day <= 17) return 'Medium Chance of Pregnancy';
    return 'Low Chance of Pregnancy';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cycle Calendar', style: AppTypography.brandTitle(fontSize: 28)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightCardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightCardBorder),
                ),
                child: Text('August 2026', style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Phase Legend Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildLegendItem('Period', AppColors.phaseMenstrual),
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

          // Calendar Card
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
                  itemCount: 28,
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final isSelected = day == _selectedDay;
                    final phaseColor = _getPhaseColorForDay(day);

                    return GestureDetector(
                      onTap: () => setState(() => _selectedDay = day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected ? phaseColor : phaseColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          border: isSelected
                              ? Border.all(color: AppColors.dropCoral, width: 2)
                              : Border.all(color: phaseColor.withOpacity(0.3)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: AppTypography.body(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? Colors.white : AppColors.textMain,
                              ),
                            ),
                            if (day == 14 || day == 1) ...[
                              const SizedBox(height: 2),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? Colors.white : phaseColor,
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

          // Selected Day Details Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.lightCardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: _getPhaseColorForDay(_selectedDay).withOpacity(0.5)),
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
                    Text('Day $_selectedDay Overview', style: AppTypography.brandTitle(fontSize: 20)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPhaseColorForDay(_selectedDay),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getPhaseForDay(_selectedDay).toUpperCase(),
                        style: AppTypography.brandTagline(color: Colors.white, fontSize: 9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _getFertilityForDay(_selectedDay),
                  style: AppTypography.body(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.favorite_border, size: 16, color: AppColors.petalRose),
                    const SizedBox(width: 6),
                    Text(
                      _selectedDay == 14 ? 'Logged: High Energy, Cramps' : 'No symptoms logged for this day',
                      style: AppTypography.body(fontSize: 12, color: AppColors.textMain),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.body(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}
