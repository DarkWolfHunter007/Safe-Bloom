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
