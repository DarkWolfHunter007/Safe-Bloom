import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/cycle_group_utils.dart';
import '../../../tracking/data/repositories/tracking_repository.dart';
import '../../../tracking/domain/entities/period_entry.dart';
import '../../../tracking/domain/entities/symptom_entry.dart';
import '../../../tracking/domain/entities/user_profile.dart';
import '../../../tracking/domain/services/cycle_calculator.dart';

class CycleTrendPoint {
  final String monthLabel;
  final double cycleLength;
  final bool isRealData;
  final DateTime date;

  CycleTrendPoint({
    required this.monthLabel,
    required this.cycleLength,
    required this.isRealData,
    required this.date,
  });
}

class SymptomFrequencyPoint {
  final String type;
  final SymptomCategory category;
  final int count;
  final double avgIntensity;

  SymptomFrequencyPoint({
    required this.type,
    required this.category,
    required this.count,
    required this.avgIntensity,
  });
}

class CycleChartsWidget extends StatefulWidget {
  const CycleChartsWidget({super.key});

  @override
  State<CycleChartsWidget> createState() => CycleChartsWidgetState();
}

class CycleChartsWidgetState extends State<CycleChartsWidget> {
  final TrackingRepository _repository = TrackingRepository.instance;
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Cycle Trends, 1: Symptom Frequency

  List<CycleTrendPoint> _trendPoints = [];
  List<SymptomFrequencyPoint> _symptomFrequencies = [];

  double _avgCycleLength = 28.0;
  double _minCycleLength = 28.0;
  double _maxCycleLength = 28.0;
  double _cycleVariation = 0.0;
  bool _hasRealCycleData = false;
  bool _hasRealSymptomData = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => _isLoading = true);

    try {
      final profile = await _repository.getUserProfile();
      final periodEntries = await _repository.getPeriodEntries();
      final symptomEntries = await _repository.getAllSymptoms();

      _processCycleTrends(periodEntries, profile);
      _processSymptomFrequencies(symptomEntries);
    } catch (e) {
      debugPrint('Error loading cycle chart data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _processCycleTrends(List<PeriodEntry> entries, UserProfile profile) {
    final now = DateTime.now();
    final List<CycleTrendPoint> points = [];

    // Calculate dynamic averages (groupIntoCycles inside filters pure-spotting groups automatically)
    final averages = CycleCalculator.calculateAveragesFromEntries(
      entries,
      fallbackCycleLength: profile.avgCycleLength,
      fallbackPeriodLength: profile.avgPeriodLength,
    );
    final userAvg = averages['avgCycleLength']?.toDouble() ?? profile.avgCycleLength.toDouble();
    _avgCycleLength = userAvg;

    // Group consecutive entries into distinct period cycles (genuine cycles for cycle-to-cycle lengths)
    final cycles = CycleGroupUtils.groupIntoCycles(entries);

    _hasRealCycleData = entries.any((e) => e.isActiveFlow);

    // Extract real cycle lengths if we have at least 2 distinct cycles
    final Map<String, double> realCycleByMonth = {};
    if (cycles.length >= 2) {
      for (int i = 0; i < cycles.length - 1; i++) {
        final start1 = CycleGroupUtils.getCycleStartDate(cycles[i]);
        final start2 = CycleGroupUtils.getCycleStartDate(cycles[i + 1]);
        final d1 = DateTime(start1.year, start1.month, start1.day);
        final d2 = DateTime(start2.year, start2.month, start2.day);
        final length = d2.difference(d1).inDays.toDouble();
        final monthKey = DateFormat('yyyy-MM').format(start2);
        realCycleByMonth[monthKey] = length.clamp(18.0, 45.0);
      }
    }

    // Build 6-month timeline points (past 5 months + current month)
    final List<double> lengthsForStats = [];
    for (int i = 5; i >= 0; i--) {
      final targetMonthDate = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('yyyy-MM').format(targetMonthDate);
      final monthName = DateFormat('MMM').format(targetMonthDate);

      if (realCycleByMonth.containsKey(monthKey)) {
        final len = realCycleByMonth[monthKey]!;
        points.add(CycleTrendPoint(
          monthLabel: monthName,
          cycleLength: len,
          isRealData: true,
          date: targetMonthDate,
        ));
        lengthsForStats.add(len);
      } else {
        // Use exact profile average cycle length
        points.add(CycleTrendPoint(
          monthLabel: monthName,
          cycleLength: userAvg,
          isRealData: entries.isNotEmpty,
          date: targetMonthDate,
        ));
        lengthsForStats.add(userAvg);
      }
    }

    _trendPoints = points;

    if (lengthsForStats.isNotEmpty) {
      _minCycleLength = lengthsForStats.reduce((a, b) => a < b ? a : b);
      _maxCycleLength = lengthsForStats.reduce((a, b) => a > b ? a : b);
      _cycleVariation = (_maxCycleLength - _minCycleLength) / 2.0;
    }
  }

  void _processSymptomFrequencies(List<SymptomEntry> entries) {
    if (entries.isNotEmpty) {
      _hasRealSymptomData = true;
      final Map<String, Map<String, dynamic>> counts = {};

      for (final entry in entries) {
        final key = entry.type;
        if (!counts.containsKey(key)) {
          counts[key] = {
            'type': entry.type,
            'category': entry.category,
            'count': 0,
            'intensitySum': 0,
          };
        }
        counts[key]!['count'] = (counts[key]!['count'] as int) + 1;
        counts[key]!['intensitySum'] = (counts[key]!['intensitySum'] as int) + entry.intensity;
      }

      final List<SymptomFrequencyPoint> list = counts.values.map((item) {
        final count = item['count'] as int;
        final intensitySum = item['intensitySum'] as int;
        return SymptomFrequencyPoint(
          type: item['type'] as String,
          category: item['category'] as SymptomCategory,
          count: count,
          avgIntensity: count > 0 ? (intensitySum / count) : 3.0,
        );
      }).toList();

      list.sort((a, b) => b.count.compareTo(a.count));
      _symptomFrequencies = list.take(6).toList();
    } else {
      _hasRealSymptomData = false;
      _symptomFrequencies = [];
    }
  }

  Color _getCategoryColor(SymptomCategory category) {
    switch (category) {
      case SymptomCategory.pain:
        return AppColors.phaseMenstrual;
      case SymptomCategory.mood:
        return AppColors.phaseLuteal;
      case SymptomCategory.energy:
        return AppColors.energyYellow;
      case SymptomCategory.sleep:
        return AppColors.waterBlue;
      case SymptomCategory.skin:
        return AppColors.phaseFollicular;
      case SymptomCategory.intimate:
        return AppColors.phaseOvulation;
      case SymptomCategory.exercise:
        return AppColors.dropCoral;
      case SymptomCategory.cervicalFluid:
        return AppColors.phaseOvulation;
      case SymptomCategory.biomarker:
        return const Color(0xFFD4AF37);
      case SymptomCategory.custom:
        return AppColors.textMuted;
    }
  }

  String _getRegularityStatus() {
    if (_cycleVariation <= 1.5) {
      return 'Regular (±${_cycleVariation.toStringAsFixed(1)}d)';
    } else if (_cycleVariation <= 3.5) {
      return 'Slight Variance (±${_cycleVariation.toStringAsFixed(1)}d)';
    } else {
      return 'Irregular (±${_cycleVariation.toStringAsFixed(1)}d)';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: AppColors.lightCardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.lightCardBorder),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.dropCoral),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightCardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.lightCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title & Refresh button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.dropCoral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: AppColors.dropCoral,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cycle Trends & Symptoms',
                      style: AppTypography.brandTitle(fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '6-MONTH VARIATION & RECURRING PATTERNS',
                      style: AppTypography.brandTagline(
                        color: AppColors.petalRose,
                        fontSize: 9,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textMuted),
                onPressed: refresh,
                tooltip: 'Refresh Chart Data',
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Key Stat Pills Row
          Row(
            children: [
              Expanded(
                child: _buildStatBadge(
                  label: 'AVG CYCLE',
                  value: '${_avgCycleLength.toStringAsFixed(1)}d',
                  color: AppColors.dropCoral,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _buildStatBadge(
                  label: 'VARIATION',
                  value: '±${_cycleVariation.toStringAsFixed(1)}d',
                  color: AppColors.phaseFollicular,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _buildStatBadge(
                  label: 'REGULARITY',
                  value: _getRegularityStatus().split(' ').first,
                  color: AppColors.phaseLuteal,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Segmented Tab Switcher (Cycle Trends vs Symptom Frequency)
          Container(
            decoration: BoxDecoration(
              color: AppColors.lightBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? AppColors.dropCoral : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Text(
                          '6-MO CYCLE TRENDS',
                          style: AppTypography.brandTagline(
                            color: _selectedTab == 0 ? Colors.white : AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? AppColors.dropCoral : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Text(
                          'SYMPTOM BREAKDOWN',
                          style: AppTypography.brandTagline(
                            color: _selectedTab == 1 ? Colors.white : AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Chart Display Body
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _selectedTab == 0
                ? RepaintBoundary(child: _buildCycleTrendLineChart())
                : RepaintBoundary(child: _buildSymptomFrequencyBarChart()),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Footer Data Source Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      _selectedTab == 0
                          ? (_hasRealCycleData ? Icons.check_circle_outline : Icons.info_outline)
                          : (_hasRealSymptomData ? Icons.check_circle_outline : Icons.info_outline),
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _selectedTab == 0
                            ? (_hasRealCycleData ? 'Real cycle tracking history' : 'Baseline profile estimate')
                            : (_hasRealSymptomData ? 'Based on your logged symptoms' : 'Sample symptom distribution'),
                        style: AppTypography.body(fontSize: 11, color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Safe Bloom Privacy Protected',
                style: AppTypography.brandTagline(color: AppColors.petalRose.withValues(alpha: 0.6), fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.brandTagline(color: color, fontSize: 8),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.body(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. Line Chart for 6-Month Cycle Variation Trends ---

  Widget _buildCycleTrendLineChart() {
    final minY = (_minCycleLength - 4.0).clamp(16.0, 24.0);
    final maxY = (_maxCycleLength + 4.0).clamp(32.0, 45.0);

    return Column(
      key: const ValueKey('CycleTrendChart'),
      children: [
        SizedBox(
          height: 190,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, top: 12, bottom: 4),
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: AppColors.lightCardBorder,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${value.toInt()}d',
                            style: AppTypography.body(fontSize: 10, color: AppColors.textMuted),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _trendPoints.length) {
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              _trendPoints[index].monthLabel,
                              style: AppTypography.body(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMain,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: _avgCycleLength,
                      color: AppColors.petalRose,
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 6, bottom: 2),
                        style: AppTypography.brandTagline(color: AppColors.petalRose, fontSize: 8),
                        labelResolver: (line) => 'Target: ${_avgCycleLength.toStringAsFixed(0)}d',
                      ),
                    ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => AppColors.deepPlum,
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        final point = _trendPoints[index];
                        final diff = spot.y - _avgCycleLength;
                        final diffStr = diff >= 0
                            ? '+${diff.toStringAsFixed(1)}d vs avg'
                            : '${diff.toStringAsFixed(1)}d vs avg';

                        return LineTooltipItem(
                          '${point.monthLabel}: ${spot.y.toStringAsFixed(1)} Days\n$diffStr',
                          AppTypography.body(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _trendPoints.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.cycleLength);
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.dropCoral,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: AppColors.dropCoral,
                          strokeWidth: 2.5,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.dropCoral.withValues(alpha: 0.35),
                          AppColors.dropCoral.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- 2. Bar Chart & Donut for Symptom Frequency Breakdown ---

  Widget _buildSymptomFrequencyBarChart() {
    if (_symptomFrequencies.isEmpty) {
      return Container(
        height: 190,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.lightBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart_outlined, color: AppColors.textMuted, size: 36),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No symptom data logged yet',
              style: AppTypography.body(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              'Log symptoms during your cycle to see personalized trends here.',
              textAlign: TextAlign.center,
              style: AppTypography.body(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final maxCount = _symptomFrequencies.fold<int>(0, (max, item) => item.count > max ? item.count : max);
    final maxY = (maxCount + 2).toDouble();

    return Column(
      key: const ValueKey('SymptomFrequencyChart'),
      children: [
        SizedBox(
          height: 190,
          child: Padding(
            padding: const EdgeInsets.only(right: 12, top: 12, bottom: 4),
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => AppColors.deepPlum,
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = _symptomFrequencies[groupIndex];
                      return BarTooltipItem(
                        '${item.type}\n${item.count} logs (Avg ${item.avgIntensity.toStringAsFixed(1)}/5)',
                        AppTypography.body(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 2,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            value.toInt().toString(),
                            style: AppTypography.body(fontSize: 10, color: AppColors.textMuted),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _symptomFrequencies.length) {
                          final label = _symptomFrequencies[index].type;
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              label.length > 7 ? '${label.substring(0, 6)}…' : label,
                              style: AppTypography.body(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMain,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: AppColors.lightCardBorder,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: _symptomFrequencies.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final color = _getCategoryColor(item.category);

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: item.count.toDouble(),
                        color: color,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: AppColors.lightBackground,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
