import 'package:safe_bloom/core/utils/cycle_group_utils.dart';
import '../entities/period_entry.dart';

enum CyclePhase {
  menstrual,
  follicular,
  ovulation,
  luteal,
}

class CycleCalculator {
  static String getPhaseName(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual:
        return 'Menstrual Phase';
      case CyclePhase.follicular:
        return 'Follicular Phase';
      case CyclePhase.ovulation:
        return 'Ovulation Window';
      case CyclePhase.luteal:
        return 'Luteal Phase';
    }
  }

  static String getPhaseDescription(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual:
        return 'Uterine lining sheds. Energy may drop—prioritize rest, hydration, and iron-rich foods.';
      case CyclePhase.follicular:
        return 'Estrogen rises. Energy and focus peak—ideal time for intense workouts and strategic tasks.';
      case CyclePhase.ovulation:
        return 'LH surge releases egg. Peak fertility window and heightened social energy.';
      case CyclePhase.luteal:
        return 'Progesterone rises. Body temperature increases—focus on gentle movement and nutrient-dense foods.';
    }
  }

  static int getCurrentCycleDay(DateTime lastPeriodStart, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    final cleanStart = DateTime(lastPeriodStart.year, lastPeriodStart.month, lastPeriodStart.day);
    final diff = cleanToday.difference(cleanStart).inDays;
    return (diff >= 0) ? diff + 1 : 1;
  }

  static CyclePhase getCyclePhase(int rawCycleDay, {int avgCycleLength = 28, int avgPeriodLength = 5}) {
    final cycleDay = ((rawCycleDay - 1) % avgCycleLength) + 1;
    final ovulationDay = avgCycleLength - 14;

    if (cycleDay <= avgPeriodLength) {
      return CyclePhase.menstrual;
    } else if (cycleDay < (ovulationDay - 2)) {
      return CyclePhase.follicular;
    } else if (cycleDay <= (ovulationDay + 2)) {
      return CyclePhase.ovulation;
    } else {
      return CyclePhase.luteal;
    }
  }

  static int getDaysUntilNextPeriod(DateTime lastPeriodStart, {int avgCycleLength = 28, DateTime? now}) {
    final today = now ?? DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    final cleanStart = DateTime(lastPeriodStart.year, lastPeriodStart.month, lastPeriodStart.day);
    
    DateTime nextPeriod = cleanStart.add(Duration(days: avgCycleLength));
    while (nextPeriod.isBefore(cleanToday)) {
      nextPeriod = nextPeriod.add(Duration(days: avgCycleLength));
    }
    
    return nextPeriod.difference(cleanToday).inDays;
  }

  static DateTime getNextPeriodStartDate(DateTime lastPeriodStart, {int avgCycleLength = 28, DateTime? now}) {
    final today = now ?? DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    final cleanStart = DateTime(lastPeriodStart.year, lastPeriodStart.month, lastPeriodStart.day);

    DateTime nextPeriod = cleanStart.add(Duration(days: avgCycleLength));
    while (nextPeriod.isBefore(cleanToday)) {
      nextPeriod = nextPeriod.add(Duration(days: avgCycleLength));
    }
    return nextPeriod;
  }

  /// Generates predicted period dates for calendar rendering
  static Set<DateTime> getPredictedPeriodDates({
    required DateTime lastPeriodStart,
    int avgCycleLength = 28,
    int avgPeriodLength = 5,
    int monthsAhead = 6,
  }) {
    final Set<DateTime> dates = {};
    DateTime currentStart = DateTime(lastPeriodStart.year, lastPeriodStart.month, lastPeriodStart.day);

    for (int m = 0; m < monthsAhead; m++) {
      for (int day = 0; day < avgPeriodLength; day++) {
        final periodDate = currentStart.add(Duration(days: day));
        dates.add(DateTime(periodDate.year, periodDate.month, periodDate.day));
      }
      currentStart = currentStart.add(Duration(days: avgCycleLength));
    }

    return dates;
  }

  /// Calculates dynamic averages from logged historical periods
  static Map<String, int> calculateAveragesFromEntries(List<PeriodEntry> entries) {
    if (entries.isEmpty) {
      return {'avgCycleLength': 28, 'avgPeriodLength': 5};
    }

    final cycles = CycleGroupUtils.groupIntoCycles(entries);

    // Average period length
    final periodLengths = cycles.map((c) => c.length).toList();
    final avgPeriodLength = periodLengths.isNotEmpty
        ? (periodLengths.reduce((a, b) => a + b) / periodLengths.length).round()
        : 5;

    // Average cycle length between cycle start dates
    if (cycles.length < 2) {
      return {'avgCycleLength': 28, 'avgPeriodLength': avgPeriodLength};
    }

    final List<int> cycleLengths = [];
    for (int i = 0; i < cycles.length - 1; i++) {
      final start1 = cycles[i].first.timestamp;
      final start2 = cycles[i + 1].first.timestamp;
      cycleLengths.add(start2.difference(start1).inDays);
    }

    final avgCycleLength = cycleLengths.isNotEmpty
        ? (cycleLengths.reduce((a, b) => a + b) / cycleLengths.length).round()
        : 28;

    return {
      'avgCycleLength': avgCycleLength.clamp(20, 45),
      'avgPeriodLength': avgPeriodLength.clamp(2, 10),
    };
  }
}
