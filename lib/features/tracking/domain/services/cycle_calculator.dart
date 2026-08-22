import 'package:safe_bloom/core/utils/cycle_group_utils.dart';
import '../entities/period_entry.dart';
import '../entities/user_profile.dart';

enum CyclePhase {
  menstrual,
  follicular,
  ovulation,
  luteal,
  overdue,
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
      case CyclePhase.overdue:
        return 'Cycle Overdue';
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
      case CyclePhase.overdue:
        return 'Your cycle has exceeded your typical duration. Fluctuations are normal due to stress, hormonal shifts, sleep, travel, or pregnancy. Log your period when it begins.';
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
    if (rawCycleDay < 1) {
      return CyclePhase.menstrual;
    }
    if (rawCycleDay > avgCycleLength) {
      return CyclePhase.overdue;
    }

    final ovulationDay = avgCycleLength - 14;
    final fertileStart = ovulationDay - 2;
    final fertileEnd = ovulationDay + 2;

    if (rawCycleDay <= avgPeriodLength) {
      return CyclePhase.menstrual;
    } else if (rawCycleDay < fertileStart) {
      return CyclePhase.follicular;
    } else if (rawCycleDay <= fertileEnd) {
      return CyclePhase.ovulation;
    } else {
      return CyclePhase.luteal;
    }
  }

  static int getDaysUntilNextPeriod(DateTime lastPeriodStart, {int avgCycleLength = 28, DateTime? now}) {
    final today = now ?? DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    final cleanStart = DateTime(lastPeriodStart.year, lastPeriodStart.month, lastPeriodStart.day);
    final expectedNext = cleanStart.add(Duration(days: avgCycleLength));
    return expectedNext.difference(cleanToday).inDays;
  }

  static DateTime getNextPeriodStartDate(DateTime lastPeriodStart, {int avgCycleLength = 28, DateTime? now}) {
    final cleanStart = DateTime(lastPeriodStart.year, lastPeriodStart.month, lastPeriodStart.day);
    return cleanStart.add(Duration(days: avgCycleLength));
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

  /// Checks if a date is the peak ovulation day for a given cycle anchor
  static bool isPeakOvulationDay(DateTime date, DateTime cycleAnchor, {int avgCycleLength = 28}) {
    final rawDay = getCurrentCycleDay(cycleAnchor, now: date);
    if (rawDay < 1 || rawDay > avgCycleLength) {
      return false;
    }
    final peakDay = avgCycleLength - 14;
    return rawDay == peakDay;
  }

  /// Returns predicted peak ovulation dates for calendar rendering
  static Set<DateTime> getPredictedPeakOvulationDates({
    required DateTime lastPeriodStart,
    int avgCycleLength = 28,
    int monthsAhead = 6,
  }) {
    final Set<DateTime> dates = {};
    DateTime currentStart = DateTime(lastPeriodStart.year, lastPeriodStart.month, lastPeriodStart.day);
    final peakOffset = (avgCycleLength - 14) - 1; // 0-indexed offset from cycle day 1

    for (int m = 0; m < monthsAhead; m++) {
      final peakDate = currentStart.add(Duration(days: peakOffset));
      dates.add(DateTime(peakDate.year, peakDate.month, peakDate.day));
      currentStart = currentStart.add(Duration(days: avgCycleLength));
    }

    return dates;
  }

  /// Calculates dynamic averages from logged historical periods
  static Map<String, int> calculateAveragesFromEntries(
    List<PeriodEntry> entries, {
    int fallbackCycleLength = 28,
    int fallbackPeriodLength = 5,
  }) {
    if (entries.isEmpty) {
      return {'avgCycleLength': fallbackCycleLength, 'avgPeriodLength': fallbackPeriodLength};
    }

    final cycles = CycleGroupUtils.groupIntoCycles(entries);
    if (cycles.isEmpty) {
      return {'avgCycleLength': fallbackCycleLength, 'avgPeriodLength': fallbackPeriodLength};
    }

    // Average period length across genuine menstrual cycles
    final periodLengths = cycles.map((c) => CycleGroupUtils.getCycleActiveDurationDays(c)).toList();
    final avgPeriodLength = periodLengths.isNotEmpty
        ? (periodLengths.reduce((a, b) => a + b) / periodLengths.length).round()
        : fallbackPeriodLength;

    // Average cycle length between consecutive genuine cycle start dates
    if (cycles.length < 2) {
      return {
        'avgCycleLength': fallbackCycleLength,
        'avgPeriodLength': avgPeriodLength.clamp(2, 10),
      };
    }

    final List<int> cycleLengths = [];
    for (int i = 0; i < cycles.length - 1; i++) {
      final start1 = CycleGroupUtils.getCycleStartDate(cycles[i]);
      final start2 = CycleGroupUtils.getCycleStartDate(cycles[i + 1]);
      final d1 = DateTime(start1.year, start1.month, start1.day);
      final d2 = DateTime(start2.year, start2.month, start2.day);
      cycleLengths.add(d2.difference(d1).inDays);
    }

    final avgCycleLength = cycleLengths.isNotEmpty
        ? (cycleLengths.reduce((a, b) => a + b) / cycleLengths.length).round()
        : fallbackCycleLength;

    return {
      'avgCycleLength': avgCycleLength.clamp(20, 45),
      'avgPeriodLength': avgPeriodLength.clamp(2, 10),
    };
  }

  /// Resolves the comprehensive calendar day status for a given date.
  static CalendarDayStatus resolveCalendarDayStatus({
    required DateTime date,
    required UserProfile profile,
    required Set<DateTime> loggedPeriodDates,
    required Set<DateTime> predictedPeriodDates,
    List<DateTime> sortedCycleStarts = const [],
  }) {
    final cleanDate = DateTime(date.year, date.month, date.day);

    // 1. CONFIRMED / LOGGED PERIOD (Highest priority)
    if (loggedPeriodDates.contains(cleanDate)) {
      return CalendarDayStatus.loggedPeriod;
    }

    // 2. PREDICTED PERIOD (Only if NOT explicitly logged by user)
    if (predictedPeriodDates.contains(cleanDate)) {
      return CalendarDayStatus.predictedPeriod;
    }

    // 3. Resolve cycle anchor for phase calculation
    DateTime anchor = DateTime(profile.lastPeriodStart.year, profile.lastPeriodStart.month, profile.lastPeriodStart.day);
    if (sortedCycleStarts.isNotEmpty) {
      for (int i = sortedCycleStarts.length - 1; i >= 0; i--) {
        final cycleStart = DateTime(sortedCycleStarts[i].year, sortedCycleStarts[i].month, sortedCycleStarts[i].day);
        if (!cleanDate.isBefore(cycleStart)) {
          anchor = cycleStart;
          break;
        }
      }
    }

    final cycleDay = getCurrentCycleDay(anchor, now: cleanDate);
    final phase = getCyclePhase(
      cycleDay,
      avgCycleLength: profile.avgCycleLength,
      avgPeriodLength: profile.avgPeriodLength,
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
}

enum CalendarDayStatus {
  loggedPeriod,
  predictedPeriod,
  follicular,
  ovulation,
  luteal,
  regular,
}
