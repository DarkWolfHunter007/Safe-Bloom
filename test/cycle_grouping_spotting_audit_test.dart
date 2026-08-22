import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/core/utils/cycle_group_utils.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';
import 'package:safe_bloom/features/tracking/domain/services/cycle_calculator.dart';

void main() {
  group('Cycle Grouping & Spotting Audit — 12 Test Scenarios', () {
    // ── Scenario 1: Consecutive Flow Days ────────────────────────────────────
    test('1. Consecutive Flow Days: Groups uninterrupted period into 1 cycle', () {
      final start = DateTime(2026, 8, 1);
      final entries = [
        PeriodEntry(id: '1', timestamp: start, flow: FlowLevel.heavy),
        PeriodEntry(id: '2', timestamp: start.add(const Duration(days: 1)), flow: FlowLevel.medium),
        PeriodEntry(id: '3', timestamp: start.add(const Duration(days: 2)), flow: FlowLevel.medium),
        PeriodEntry(id: '4', timestamp: start.add(const Duration(days: 3)), flow: FlowLevel.light),
        PeriodEntry(id: '5', timestamp: start.add(const Duration(days: 4)), flow: FlowLevel.light),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries, gapDays: 4);

      expect(cycles.length, 1);
      expect(cycles.first.length, 5);
      expect(cycles.first.first.timestamp, start);
      expect(cycles.first.last.timestamp, start.add(const Duration(days: 4)));
    });

    // ── Scenario 2: 1-Day Gap ────────────────────────────────────────────────
    test('2. 1-Day Gap: Mid-period pause groups into 1 cycle under gapDays=4', () {
      final start = DateTime(2026, 8, 1);
      final entries = [
        PeriodEntry(id: '1', timestamp: start, flow: FlowLevel.heavy),
        PeriodEntry(id: '2', timestamp: start.add(const Duration(days: 1)), flow: FlowLevel.medium),
        // Day 3 (Aug 3) is skipped — 1 day gap (diff = 2)
        PeriodEntry(id: '3', timestamp: start.add(const Duration(days: 3)), flow: FlowLevel.medium),
        PeriodEntry(id: '4', timestamp: start.add(const Duration(days: 4)), flow: FlowLevel.light),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries, gapDays: 4);

      expect(cycles.length, 1);
      expect(cycles.first.length, 4);
      expect(cycles.first.first.timestamp, start);
    });

    // ── Scenario 3: 2-Day Gap ────────────────────────────────────────────────
    test('3. 2-Day Gap: 2 skipped days (diff = 3 <= 4) groups into 1 cycle', () {
      final start = DateTime(2026, 8, 1);
      final entries = [
        PeriodEntry(id: '1', timestamp: start, flow: FlowLevel.heavy),
        PeriodEntry(id: '2', timestamp: start.add(const Duration(days: 1)), flow: FlowLevel.medium),
        // Days 3 & 4 skipped — 2 day gap (diff = 3)
        PeriodEntry(id: '3', timestamp: start.add(const Duration(days: 4)), flow: FlowLevel.light),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries, gapDays: 4);

      expect(cycles.length, 1);
      expect(cycles.first.length, 3);
    });

    // ── Scenario 4: 3-Day Gap ────────────────────────────────────────────────
    test('4. 3-Day Gap: 3 skipped days (diff = 4 <= 4) groups into 1 cycle', () {
      final start = DateTime(2026, 8, 1);
      final entries = [
        PeriodEntry(id: '1', timestamp: start, flow: FlowLevel.heavy),
        PeriodEntry(id: '2', timestamp: start.add(const Duration(days: 1)), flow: FlowLevel.medium),
        // Days 3, 4, 5 skipped — 3 day gap (diff = 4)
        PeriodEntry(id: '3', timestamp: start.add(const Duration(days: 5)), flow: FlowLevel.light),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries, gapDays: 4);

      expect(cycles.length, 1);
      expect(cycles.first.length, 3);
    });

    // ── Scenario 5: 4-Day Gap ────────────────────────────────────────────────
    test('5. 4-Day Gap: 4 skipped days (diff = 5 > 4) splits into 2 distinct cycles', () {
      final start = DateTime(2026, 8, 1);
      final entries = [
        PeriodEntry(id: '1', timestamp: start, flow: FlowLevel.heavy),
        // Days 2, 3, 4, 5 skipped — 4 day gap (diff = 5 > 4)
        PeriodEntry(id: '2', timestamp: start.add(const Duration(days: 5)), flow: FlowLevel.heavy),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries, gapDays: 4);

      expect(cycles.length, 2);
      expect(cycles[0].length, 1);
      expect(cycles[1].length, 1);
    });

    // ── Scenario 6: Spotting Followed by Flow (adjacent) ─────────────────────
    test('6. Adjacent spotting + flow: one cycle group, getCycleStartDate anchors to active flow day', () {
      final spottingDate = DateTime(2026, 8, 1);
      final trueFlowDate = DateTime(2026, 8, 2);
      final entries = [
        PeriodEntry(id: '1', timestamp: spottingDate, flow: FlowLevel.spotting),
        PeriodEntry(id: '2', timestamp: trueFlowDate, flow: FlowLevel.heavy),
        PeriodEntry(id: '3', timestamp: spottingDate.add(const Duration(days: 2)), flow: FlowLevel.medium),
        PeriodEntry(id: '4', timestamp: spottingDate.add(const Duration(days: 3)), flow: FlowLevel.light),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries, gapDays: 4);

      expect(cycles.length, 1);
      // Group still contains the leading spotting entry (it's within the gap)
      expect(cycles.first.first.flow, FlowLevel.spotting);
      // But the CYCLE ANCHOR (Cycle Day 1) must be the first active-flow day
      expect(CycleGroupUtils.getCycleStartDate(cycles.first), trueFlowDate);
    });

    // ── Scenario 7: Spotting 1 Day Before Flow ───────────────────────────────
    test('7. Spotting 1 day before flow: one cycle group, anchor = first active-flow day', () {
      final spottingDate = DateTime(2026, 8, 1);
      final trueFlowDate = DateTime(2026, 8, 3); // diff = 2 <= 4
      final entries = [
        PeriodEntry(id: '1', timestamp: spottingDate, flow: FlowLevel.spotting),
        PeriodEntry(id: '2', timestamp: trueFlowDate, flow: FlowLevel.heavy),
        PeriodEntry(id: '3', timestamp: trueFlowDate.add(const Duration(days: 1)), flow: FlowLevel.medium),
        PeriodEntry(id: '4', timestamp: trueFlowDate.add(const Duration(days: 2)), flow: FlowLevel.light),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries, gapDays: 4);

      expect(cycles.length, 1);
      expect(CycleGroupUtils.getCycleStartDate(cycles.first), trueFlowDate);
    });

    // ── Scenario 8: Spotting 2 Days Before Flow ──────────────────────────────
    test('8. Spotting 2 days before flow: one cycle group, anchor = first active-flow day', () {
      final spottingDate = DateTime(2026, 8, 1);
      final trueFlowDate = DateTime(2026, 8, 4); // diff = 3 <= 4
      final entries = [
        PeriodEntry(id: '1', timestamp: spottingDate, flow: FlowLevel.spotting),
        PeriodEntry(id: '2', timestamp: trueFlowDate, flow: FlowLevel.heavy),
        PeriodEntry(id: '3', timestamp: trueFlowDate.add(const Duration(days: 1)), flow: FlowLevel.medium),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries, gapDays: 4);

      expect(cycles.length, 1);
      expect(CycleGroupUtils.getCycleStartDate(cycles.first), trueFlowDate);
    });

    // ── Scenario 9: Spotting 3 Days Before Flow ──────────────────────────────
    test('9. Spotting 3 days before flow: one cycle group, anchor = first active-flow day', () {
      final spottingDate = DateTime(2026, 8, 1);
      final trueFlowDate = DateTime(2026, 8, 5); // diff = 4 <= 4
      final entries = [
        PeriodEntry(id: '1', timestamp: spottingDate, flow: FlowLevel.spotting),
        PeriodEntry(id: '2', timestamp: trueFlowDate, flow: FlowLevel.heavy),
        PeriodEntry(id: '3', timestamp: trueFlowDate.add(const Duration(days: 1)), flow: FlowLevel.medium),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries, gapDays: 4);

      expect(cycles.length, 1);
      expect(CycleGroupUtils.getCycleStartDate(cycles.first), trueFlowDate);
    });

    // ── Scenario 10: Spotting 4 Days Before Flow ─────────────────────────────
    test('10. Spotting 4 days before flow: (diff = 5 > 4) groupAllEvents splits into 2 raw groups; groupIntoCycles yields 1 genuine cycle (spotting-only group excluded)', () {
      final spottingDate = DateTime(2026, 8, 1);
      final trueFlowDate = DateTime(2026, 8, 6); // 4 days gap (diff = 5 > 4)
      final entries = [
        PeriodEntry(id: '1', timestamp: spottingDate, flow: FlowLevel.spotting),
        PeriodEntry(id: '2', timestamp: trueFlowDate, flow: FlowLevel.heavy),
        PeriodEntry(id: '3', timestamp: trueFlowDate.add(const Duration(days: 1)), flow: FlowLevel.medium),
        PeriodEntry(id: '4', timestamp: trueFlowDate.add(const Duration(days: 2)), flow: FlowLevel.light),
      ];

      // Raw event grouping: 2 groups (spotting-only group + genuine period group)
      final allEvents = CycleGroupUtils.groupAllEvents(entries, gapDays: 4);
      expect(allEvents.length, 2);
      expect(allEvents[0].first.flow, FlowLevel.spotting);
      expect(allEvents[1].first.flow, FlowLevel.heavy);

      // Genuine cycle grouping: 1 cycle (spotting-only group is excluded)
      final cycles = CycleGroupUtils.groupIntoCycles(entries, gapDays: 4);
      expect(cycles.length, 1);
      expect(cycles[0].length, 3);
      expect(cycles[0].first.flow, FlowLevel.heavy);
    });

    // ── Scenario 11: Isolated Mid-Cycle Spotting ─────────────────────────────
    test('11. Isolated Spotting: groupIntoCycles correctly excludes the isolated spotting group; no phantom cycle created', () {
      final periodStart = DateTime(2026, 8, 1);
      final midCycleSpotting = DateTime(2026, 8, 15); // Day 15 ovulation spotting
      final entries = [
        PeriodEntry(id: '1', timestamp: periodStart, flow: FlowLevel.heavy),
        PeriodEntry(id: '2', timestamp: periodStart.add(const Duration(days: 1)), flow: FlowLevel.medium),
        PeriodEntry(id: '3', timestamp: periodStart.add(const Duration(days: 2)), flow: FlowLevel.light),
        PeriodEntry(id: '4', timestamp: midCycleSpotting, flow: FlowLevel.spotting),
      ];

      // groupIntoCycles only returns the genuine menstrual cycle — NOT the spotting event.
      final cycles = CycleGroupUtils.groupIntoCycles(entries, gapDays: 4);
      expect(cycles.length, 1);
      expect(cycles.first.first.timestamp, periodStart);

      // The genuine cycle start anchor is Aug 1 (not Aug 15 spotting)
      final latestStart = CycleGroupUtils.getCycleStartDate(cycles.last);
      expect(latestStart, periodStart);

      // Averages calculate correctly using only the genuine cycle
      final averages = CycleCalculator.calculateAveragesFromEntries(entries);
      // With only 1 cycle, fallback 28-day default is used for cycle length
      expect(averages['avgCycleLength'], 28);
      expect(averages['avgPeriodLength'], 3); // 3 active flow days

      // Isolated spotting is correctly identified as intermenstrual
      final isolated = CycleGroupUtils.getIsolatedSpottingEntries(entries, gapDays: 4);
      expect(isolated.length, 1);
      expect(isolated.first.timestamp, midCycleSpotting);
    });

    // ── Scenario 12: Two Genuine Periods Unusually Close (20-day cycle) ──────
    test('12. Two Genuine Periods 20 days apart: Accurately isolates two independent cycles', () {
      final p1Start = DateTime(2026, 8, 1);
      final p2Start = DateTime(2026, 8, 21); // 20 days later (gap = 18 days > 4)
      final entries = [
        PeriodEntry(id: '1', timestamp: p1Start, flow: FlowLevel.heavy),
        PeriodEntry(id: '2', timestamp: p1Start.add(const Duration(days: 1)), flow: FlowLevel.medium),
        PeriodEntry(id: '3', timestamp: p1Start.add(const Duration(days: 2)), flow: FlowLevel.light),
        PeriodEntry(id: '4', timestamp: p2Start, flow: FlowLevel.heavy),
        PeriodEntry(id: '5', timestamp: p2Start.add(const Duration(days: 1)), flow: FlowLevel.medium),
        PeriodEntry(id: '6', timestamp: p2Start.add(const Duration(days: 2)), flow: FlowLevel.light),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries, gapDays: 4);

      expect(cycles.length, 2);
      expect(cycles[0].length, 3);
      expect(cycles[1].length, 3);

      final averages = CycleCalculator.calculateAveragesFromEntries(entries);
      expect(averages['avgCycleLength'], 20);
      expect(averages['avgPeriodLength'], 3);
    });
  });
}
