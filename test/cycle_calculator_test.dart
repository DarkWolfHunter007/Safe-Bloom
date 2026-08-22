import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';
import 'package:safe_bloom/features/tracking/domain/services/cycle_calculator.dart';

void main() {
  group('CycleCalculator Tests', () {
    test('getCurrentCycleDay calculates correct day index', () {
      final start = DateTime(2026, 8, 1);
      final today = DateTime(2026, 8, 5);

      final day = CycleCalculator.getCurrentCycleDay(start, now: today);
      expect(day, 5);
    });

    test('getCurrentCycleDay handles same day as day 1', () {
      final start = DateTime(2026, 8, 1);
      final day = CycleCalculator.getCurrentCycleDay(start, now: start);
      expect(day, 1);
    });

    test('getCyclePhase returns correct phases for standard 28-day cycle', () {
      // Menstrual phase (days 1-5)
      expect(CycleCalculator.getCyclePhase(1), CyclePhase.menstrual);
      expect(CycleCalculator.getCyclePhase(5), CyclePhase.menstrual);

      // Follicular phase (days 6-11)
      expect(CycleCalculator.getCyclePhase(6), CyclePhase.follicular);
      expect(CycleCalculator.getCyclePhase(11), CyclePhase.follicular);

      // Ovulation window (days 12-16 for day 14 ovulation)
      expect(CycleCalculator.getCyclePhase(14), CyclePhase.ovulation);

      // Luteal phase (days 17-28)
      expect(CycleCalculator.getCyclePhase(20), CyclePhase.luteal);
      expect(CycleCalculator.getCyclePhase(28), CyclePhase.luteal);
    });

    test('getCyclePhase overdue regression tests for days 1, 5, 14, 28, 29, 35, 45, 60, and 100', () {
      const avgCycle = 28;
      const avgPeriod = 5;

      // In-cycle days
      expect(CycleCalculator.getCyclePhase(1, avgCycleLength: avgCycle, avgPeriodLength: avgPeriod), CyclePhase.menstrual);
      expect(CycleCalculator.getCyclePhase(5, avgCycleLength: avgCycle, avgPeriodLength: avgPeriod), CyclePhase.menstrual);
      expect(CycleCalculator.getCyclePhase(14, avgCycleLength: avgCycle, avgPeriodLength: avgPeriod), CyclePhase.ovulation);
      expect(CycleCalculator.getCyclePhase(28, avgCycleLength: avgCycle, avgPeriodLength: avgPeriod), CyclePhase.luteal);

      // Overdue cycle days: MUST NOT wrap around via modulo!
      // Day 29 must NOT become Day 1 (menstrual)
      final phase29 = CycleCalculator.getCyclePhase(29, avgCycleLength: avgCycle, avgPeriodLength: avgPeriod);
      expect(phase29, CyclePhase.overdue);
      expect(phase29, isNot(CyclePhase.menstrual));

      // Day 35 must NOT become Day 7 (follicular)
      final phase35 = CycleCalculator.getCyclePhase(35, avgCycleLength: avgCycle, avgPeriodLength: avgPeriod);
      expect(phase35, CyclePhase.overdue);
      expect(phase35, isNot(CyclePhase.follicular));

      // Day 45 must NOT wrap
      final phase45 = CycleCalculator.getCyclePhase(45, avgCycleLength: avgCycle, avgPeriodLength: avgPeriod);
      expect(phase45, CyclePhase.overdue);

      // Day 60 must NOT become Day 4 or 5 (menstrual)
      final phase60 = CycleCalculator.getCyclePhase(60, avgCycleLength: avgCycle, avgPeriodLength: avgPeriod);
      expect(phase60, CyclePhase.overdue);
      expect(phase60, isNot(CyclePhase.menstrual));

      // Day 100 must remain overdue
      final phase100 = CycleCalculator.getCyclePhase(100, avgCycleLength: avgCycle, avgPeriodLength: avgPeriod);
      expect(phase100, CyclePhase.overdue);
    });

    test('isPeakOvulationDay never triggers on overdue days', () {
      final anchor = DateTime(2026, 8, 1);

      // Day 14 (Aug 14) is peak ovulation for 28-day cycle
      final peakDay = DateTime(2026, 8, 14);
      expect(CycleCalculator.isPeakOvulationDay(peakDay, anchor, avgCycleLength: 28), isTrue);

      // Day 42 (Sept 11, 42 days later): Previously modulo (42-1)%28+1 = 14 triggered false positive!
      final day42 = DateTime(2026, 9, 11);
      expect(CycleCalculator.isPeakOvulationDay(day42, anchor, avgCycleLength: 28), isFalse);

      // Day 70 (Oct 9, 70 days later)
      final day70 = DateTime(2026, 10, 9);
      expect(CycleCalculator.isPeakOvulationDay(day70, anchor, avgCycleLength: 28), isFalse);
    });

    test('Newly logged period resets current cycle back to Day 1', () {
      final oldPeriodStart = DateTime(2026, 7, 1);
      final today = DateTime(2026, 8, 10); // Day 41 (overdue)

      final overdueCycleDay = CycleCalculator.getCurrentCycleDay(oldPeriodStart, now: today);
      expect(overdueCycleDay, 41);
      expect(CycleCalculator.getCyclePhase(overdueCycleDay, avgCycleLength: 28), CyclePhase.overdue);

      // User logs a new period starting today
      final newPeriodStart = today;
      final resetCycleDay = CycleCalculator.getCurrentCycleDay(newPeriodStart, now: today);
      expect(resetCycleDay, 1);
      expect(CycleCalculator.getCyclePhase(resetCycleDay, avgCycleLength: 28), CyclePhase.menstrual);
    });

    test('getDaysUntilNextPeriod calculates days remaining', () {
      final start = DateTime(2026, 8, 1);
      final now = DateTime(2026, 8, 15);

      final remaining = CycleCalculator.getDaysUntilNextPeriod(start, avgCycleLength: 28, now: now);
      expect(remaining, 14);
    });

    test('calculateAveragesFromEntries falls back to defaults for empty entries', () {
      final result = CycleCalculator.calculateAveragesFromEntries([]);
      expect(result['avgCycleLength'], 28);
      expect(result['avgPeriodLength'], 5);
    });

    test('calculateAveragesFromEntries calculates averages from multiple cycles', () {
      final c1Start = DateTime(2026, 6, 1);
      final c2Start = DateTime(2026, 6, 29); // 28 days later
      final c3Start = DateTime(2026, 7, 27); // 28 days later

      final entries = [
        PeriodEntry(id: '1', timestamp: c1Start, flow: FlowLevel.heavy),
        PeriodEntry(id: '2', timestamp: c1Start.add(const Duration(days: 1)), flow: FlowLevel.medium),
        PeriodEntry(id: '3', timestamp: c1Start.add(const Duration(days: 2)), flow: FlowLevel.light),
        PeriodEntry(id: '4', timestamp: c2Start, flow: FlowLevel.heavy),
        PeriodEntry(id: '5', timestamp: c2Start.add(const Duration(days: 1)), flow: FlowLevel.medium),
        PeriodEntry(id: '6', timestamp: c2Start.add(const Duration(days: 2)), flow: FlowLevel.light),
        PeriodEntry(id: '7', timestamp: c3Start, flow: FlowLevel.heavy),
        PeriodEntry(id: '8', timestamp: c3Start.add(const Duration(days: 1)), flow: FlowLevel.medium),
        PeriodEntry(id: '9', timestamp: c3Start.add(const Duration(days: 2)), flow: FlowLevel.light),
      ];

      final averages = CycleCalculator.calculateAveragesFromEntries(entries);
      expect(averages['avgPeriodLength'], 3);
      expect(averages['avgCycleLength'], 28);
    });
  });
}
