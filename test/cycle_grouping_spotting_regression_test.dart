import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/core/utils/cycle_group_utils.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';
import 'package:safe_bloom/features/tracking/domain/services/cycle_calculator.dart';

void main() {
  PeriodEntry e(String id, DateTime date, FlowLevel flow) =>
      PeriodEntry(id: id, timestamp: date, flow: flow);

  group('Cycle Grouping — Flow-Aware Spotting Regression Suite', () {
    // ── R01 ──────────────────────────────────────────────────────────────────
    test('R01: Isolated mid-cycle spotting does NOT become a new cycle', () {
      final p1 = DateTime(2026, 8, 1);
      final spot = DateTime(2026, 8, 15);
      final entries = [
        e('1', p1, FlowLevel.heavy),
        e('2', p1.add(const Duration(days: 1)), FlowLevel.medium),
        e('3', p1.add(const Duration(days: 2)), FlowLevel.light),
        e('4', spot, FlowLevel.spotting),
      ];
      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      expect(cycles.length, 1, reason: 'Isolated spotting must NOT create a phantom cycle');
    });

    // ── R02 ──────────────────────────────────────────────────────────────────
    test('R02: Isolated mid-cycle spotting is captured by getIsolatedSpottingEntries', () {
      final p1 = DateTime(2026, 8, 1);
      final spot = DateTime(2026, 8, 15);
      final entries = [
        e('1', p1, FlowLevel.heavy),
        e('2', p1.add(const Duration(days: 1)), FlowLevel.medium),
        e('3', spot, FlowLevel.spotting),
      ];
      final isolated = CycleGroupUtils.getIsolatedSpottingEntries(entries);
      expect(isolated.length, 1);
      expect(isolated.first.timestamp, spot);
    });

    // ── R03 ──────────────────────────────────────────────────────────────────
    test('R03: Isolated spotting does NOT reset lastPeriodStart anchor', () {
      final p1 = DateTime(2026, 8, 1);
      final spot = DateTime(2026, 8, 15);
      final entries = [
        e('1', p1, FlowLevel.heavy),
        e('2', p1.add(const Duration(days: 1)), FlowLevel.medium),
        e('3', p1.add(const Duration(days: 2)), FlowLevel.light),
        e('4', spot, FlowLevel.spotting),
      ];
      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      final latestStart = CycleGroupUtils.getCycleStartDate(cycles.last);
      expect(latestStart, p1);
    });

    // ── R04 ──────────────────────────────────────────────────────────────────
    test('R04: Leading spotting (adjacent) does NOT become Cycle Day 1', () {
      final spot = DateTime(2026, 8, 1);
      final flow = DateTime(2026, 8, 2);
      final entries = [
        e('1', spot, FlowLevel.spotting),
        e('2', flow, FlowLevel.heavy),
        e('3', flow.add(const Duration(days: 1)), FlowLevel.medium),
      ];
      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      final cycleStart = CycleGroupUtils.getCycleStartDate(cycles.first);
      expect(cycles.length, 1);
      expect(cycleStart, flow, reason: 'Cycle Day 1 must be the first active-flow day, not spotting');
    });

    // ── R05 ──────────────────────────────────────────────────────────────────
    test('R05: Leading spotting 3 days before active flow — cycle anchors to active flow', () {
      final spot = DateTime(2026, 8, 1);
      final flow = DateTime(2026, 8, 4);
      final entries = [
        e('1', spot, FlowLevel.spotting),
        e('2', flow, FlowLevel.heavy),
        e('3', flow.add(const Duration(days: 1)), FlowLevel.medium),
        e('4', flow.add(const Duration(days: 2)), FlowLevel.light),
      ];
      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      final cycleStart = CycleGroupUtils.getCycleStartDate(cycles.first);
      expect(cycles.length, 1);
      expect(cycleStart, flow);
    });

    // ── R06 ──────────────────────────────────────────────────────────────────
    test('R06: Pure spotting-only history yields no genuine cycles', () {
      final entries = [
        e('1', DateTime(2026, 8, 1), FlowLevel.spotting),
        e('2', DateTime(2026, 8, 2), FlowLevel.spotting),
        e('3', DateTime(2026, 8, 3), FlowLevel.spotting),
      ];
      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      expect(cycles, isEmpty);
    });

    // ── R07 ──────────────────────────────────────────────────────────────────
    test('R07: Pure spotting-only history — averages return fallback values', () {
      final entries = [
        e('1', DateTime(2026, 8, 1), FlowLevel.spotting),
        e('2', DateTime(2026, 8, 15), FlowLevel.spotting),
      ];
      final averages = CycleCalculator.calculateAveragesFromEntries(
        entries,
        fallbackCycleLength: 28,
        fallbackPeriodLength: 5,
      );
      expect(averages['avgCycleLength'], 28);
      expect(averages['avgPeriodLength'], 5);
    });

    // ── R08 ──────────────────────────────────────────────────────────────────
    test('R08: Two genuine periods — cycle length measured between active-flow anchors', () {
      final p1 = DateTime(2026, 8, 1);
      final p2 = DateTime(2026, 8, 29);
      final entries = [
        e('1', p1, FlowLevel.heavy),
        e('2', p1.add(const Duration(days: 1)), FlowLevel.medium),
        e('3', p1.add(const Duration(days: 2)), FlowLevel.light),
        e('4', p2, FlowLevel.heavy),
        e('5', p2.add(const Duration(days: 1)), FlowLevel.medium),
      ];
      final averages = CycleCalculator.calculateAveragesFromEntries(entries);
      expect(averages['avgCycleLength'], 28);
    });

    // ── R09 ──────────────────────────────────────────────────────────────────
    test('R09: Mid-cycle spotting does not alter inter-period cycle length', () {
      final p1 = DateTime(2026, 8, 1);
      final spot = DateTime(2026, 8, 15);
      final p2 = DateTime(2026, 8, 29);
      final entries = [
        e('1', p1, FlowLevel.heavy),
        e('2', p1.add(const Duration(days: 1)), FlowLevel.medium),
        e('3', p1.add(const Duration(days: 2)), FlowLevel.light),
        e('4', spot, FlowLevel.spotting),
        e('5', p2, FlowLevel.heavy),
        e('6', p2.add(const Duration(days: 1)), FlowLevel.medium),
      ];
      final averages = CycleCalculator.calculateAveragesFromEntries(entries);
      expect(averages['avgCycleLength'], 28);
    });

    // ── R10 ──────────────────────────────────────────────────────────────────
    test('R10: getCycleActiveDurationDays counts only active-flow days', () {
      final p1 = DateTime(2026, 8, 1);
      final entries = [
        e('1', p1, FlowLevel.heavy),
        e('2', p1.add(const Duration(days: 1)), FlowLevel.medium),
        e('3', p1.add(const Duration(days: 2)), FlowLevel.light),
        e('4', p1.add(const Duration(days: 3)), FlowLevel.spotting),
      ];
      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      final duration = CycleGroupUtils.getCycleActiveDurationDays(cycles.first);
      expect(duration, 3);
    });

    // ── R11 ──────────────────────────────────────────────────────────────────
    test('R11: getCycleEndDate returns last entry in cycle group', () {
      final p1 = DateTime(2026, 8, 1);
      final trailing = p1.add(const Duration(days: 3));
      final entries = [
        e('1', p1, FlowLevel.heavy),
        e('2', p1.add(const Duration(days: 1)), FlowLevel.medium),
        e('3', p1.add(const Duration(days: 2)), FlowLevel.light),
        e('4', trailing, FlowLevel.spotting),
      ];
      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      final endDate = CycleGroupUtils.getCycleEndDate(cycles.first);
      expect(endDate, trailing);
    });

    // ── R12 ──────────────────────────────────────────────────────────────────
    test('R12: Spotting after a period does NOT alter cycle start', () {
      final p1 = DateTime(2026, 8, 1);
      final postSpot = DateTime(2026, 8, 20);
      final entries = [
        e('1', p1, FlowLevel.heavy),
        e('2', p1.add(const Duration(days: 1)), FlowLevel.medium),
        e('3', p1.add(const Duration(days: 2)), FlowLevel.light),
        e('4', postSpot, FlowLevel.spotting),
      ];
      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      final cycleStart = CycleGroupUtils.getCycleStartDate(cycles.first);
      expect(cycles.length, 1);
      expect(cycleStart, p1);
    });

    // ── R13 ──────────────────────────────────────────────────────────────────
    test('R13: Post-period spotting is captured in isolated spotting list', () {
      final p1 = DateTime(2026, 8, 1);
      final postSpot = DateTime(2026, 8, 20);
      final entries = [
        e('1', p1, FlowLevel.heavy),
        e('2', p1.add(const Duration(days: 1)), FlowLevel.medium),
        e('3', postSpot, FlowLevel.spotting),
      ];
      final isolated = CycleGroupUtils.getIsolatedSpottingEntries(entries);
      expect(isolated.length, 1);
      expect(isolated.first.timestamp, postSpot);
    });

    // ── R14 ──────────────────────────────────────────────────────────────────
    test('R14: Two real periods 20 days apart are two distinct genuine cycles', () {
      final p1 = DateTime(2026, 8, 1);
      final p2 = DateTime(2026, 8, 21);
      final entries = [
        e('1', p1, FlowLevel.heavy),
        e('2', p1.add(const Duration(days: 1)), FlowLevel.medium),
        e('3', p2, FlowLevel.heavy),
        e('4', p2.add(const Duration(days: 1)), FlowLevel.medium),
      ];
      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      expect(cycles.length, 2);
      expect(CycleGroupUtils.getCycleStartDate(cycles[0]), p1);
      expect(CycleGroupUtils.getCycleStartDate(cycles[1]), p2);
    });

    // ── R15 ──────────────────────────────────────────────────────────────────
    test('R15: Intra-period gap diff=4 (<=gapDays) preserves single cycle', () {
      final start = DateTime(2026, 8, 1);
      final entries = [
        e('1', start, FlowLevel.heavy),
        e('2', start.add(const Duration(days: 1)), FlowLevel.medium),
        e('3', start.add(const Duration(days: 5)), FlowLevel.light), // diff=4
      ];
      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      expect(cycles.length, 1);
      expect(cycles.first.length, 3);
    });

    // ── R16 ──────────────────────────────────────────────────────────────────
    test('R16: Intra-period gap diff=5 (>gapDays) splits into two genuine cycles', () {
      final start = DateTime(2026, 8, 1);
      final entries = [
        e('1', start, FlowLevel.heavy),
        e('2', start.add(const Duration(days: 6)), FlowLevel.heavy), // diff=6
      ];
      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      expect(cycles.length, 2);
    });

    // ── R17 ──────────────────────────────────────────────────────────────────
    test('R17: Spotting 5+ days before flow is isolated; active flow is the only genuine cycle', () {
      final spot = DateTime(2026, 8, 1);
      final flow = DateTime(2026, 8, 7); // diff=6 > 4
      final entries = [
        e('1', spot, FlowLevel.spotting),
        e('2', flow, FlowLevel.heavy),
        e('3', flow.add(const Duration(days: 1)), FlowLevel.medium),
      ];
      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      expect(cycles.length, 1);
      expect(CycleGroupUtils.getCycleStartDate(cycles.first), flow);
      final isolated = CycleGroupUtils.getIsolatedSpottingEntries(entries);
      expect(isolated.length, 1);
      expect(isolated.first.timestamp, spot);
    });

    // ── R18 ──────────────────────────────────────────────────────────────────
    test('R18: Multiple isolated spotting clusters are all captured as isolated', () {
      final entries = [
        e('1', DateTime(2026, 8, 1), FlowLevel.spotting),
        e('2', DateTime(2026, 8, 2), FlowLevel.spotting),
        e('3', DateTime(2026, 8, 15), FlowLevel.heavy),
        e('4', DateTime(2026, 8, 16), FlowLevel.medium),
        e('5', DateTime(2026, 9, 1), FlowLevel.spotting),
      ];
      final isolated = CycleGroupUtils.getIsolatedSpottingEntries(entries);
      expect(isolated.length, 3);
    });

    // ── R19 ──────────────────────────────────────────────────────────────────
    test('R19: avgPeriodLength reflects active-flow days only, not total entry count', () {
      final p1 = DateTime(2026, 8, 1);
      final p2 = DateTime(2026, 9, 1);
      final entries = [
        e('1', p1, FlowLevel.heavy),
        e('2', p1.add(const Duration(days: 1)), FlowLevel.medium),
        e('3', p1.add(const Duration(days: 2)), FlowLevel.spotting),
        e('4', p2, FlowLevel.heavy),
        e('5', p2.add(const Duration(days: 1)), FlowLevel.light),
        e('6', p2.add(const Duration(days: 2)), FlowLevel.spotting),
      ];
      final averages = CycleCalculator.calculateAveragesFromEntries(entries);
      expect(averages['avgPeriodLength'], 2,
          reason: 'avgPeriodLength must count active-flow days only');
    });

    // ── R20 ──────────────────────────────────────────────────────────────────
    test('R20: FlowLevelExtension and PeriodEntry helpers classify flow correctly', () {
      expect(FlowLevel.heavy.isActiveFlow, isTrue);
      expect(FlowLevel.medium.isActiveFlow, isTrue);
      expect(FlowLevel.light.isActiveFlow, isTrue);
      expect(FlowLevel.spotting.isActiveFlow, isFalse);

      expect(FlowLevel.spotting.isSpotting, isTrue);
      expect(FlowLevel.heavy.isSpotting, isFalse);
      expect(FlowLevel.medium.isSpotting, isFalse);
      expect(FlowLevel.light.isSpotting, isFalse);

      final spotEntry = PeriodEntry(id: 'x', timestamp: DateTime(2026, 8, 1), flow: FlowLevel.spotting);
      expect(spotEntry.isActiveFlow, isFalse);
      expect(spotEntry.isSpotting, isTrue);

      final heavyEntry = PeriodEntry(id: 'y', timestamp: DateTime(2026, 8, 1), flow: FlowLevel.heavy);
      expect(heavyEntry.isActiveFlow, isTrue);
      expect(heavyEntry.isSpotting, isFalse);
    });
  });
}

