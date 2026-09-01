import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/core/utils/cycle_group_utils.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';

void main() {
  group('CycleGroupUtils Unit Tests', () {
    test('Empty entries return empty cycles list', () {
      final cycles = CycleGroupUtils.groupIntoCycles([]);
      expect(cycles, isEmpty);
    });

    test('Consecutive daily entries (gap of 1 day) group into a single cycle', () {
      final now = DateTime(2026, 8, 1);
      final entries = [
        PeriodEntry(id: '1', timestamp: now, flow: FlowLevel.heavy),
        PeriodEntry(id: '2', timestamp: now.add(const Duration(days: 1)), flow: FlowLevel.medium),
        PeriodEntry(id: '3', timestamp: now.add(const Duration(days: 2)), flow: FlowLevel.light),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      expect(cycles.length, 1);
      expect(cycles.first.length, 3);
    });

    test('Entries with gap of 2 days remain in the same cycle under gapDays=4', () {
      final start = DateTime(2026, 8, 1);
      final entries = [
        PeriodEntry(id: '1', timestamp: start, flow: FlowLevel.heavy),
        PeriodEntry(id: '2', timestamp: start.add(const Duration(days: 2)), flow: FlowLevel.medium),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      expect(cycles.length, 1);
      expect(cycles.first.length, 2);
    });

    test('Entries with gap of 3 days remain in the same cycle under gapDays=4', () {
      final start = DateTime(2026, 8, 1);
      final entries = [
        PeriodEntry(id: '1', timestamp: start, flow: FlowLevel.heavy),
        PeriodEntry(id: '2', timestamp: start.add(const Duration(days: 3)), flow: FlowLevel.spotting),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      expect(cycles.length, 1);
      expect(cycles.first.length, 2);
    });

    test('Entries with gap of 4 days remain in the same cycle (boundary test: diff <= 4)', () {
      final start = DateTime(2026, 8, 1);
      final entries = [
        PeriodEntry(id: '1', timestamp: start, flow: FlowLevel.heavy),
        PeriodEntry(id: '2', timestamp: start.add(const Duration(days: 4)), flow: FlowLevel.light),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      expect(cycles.length, 1);
      expect(cycles.first.length, 2);
    });

    test('Entries with gap of 5 days split into distinct cycles (boundary test: diff > 4)', () {
      final start = DateTime(2026, 8, 1);
      final entries = [
        PeriodEntry(id: '1', timestamp: start, flow: FlowLevel.heavy),
        PeriodEntry(id: '2', timestamp: start.add(const Duration(days: 5)), flow: FlowLevel.heavy),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      expect(cycles.length, 2);
      expect(cycles[0].length, 1);
      expect(cycles[1].length, 1);
    });

    test('Full 28-day gap correctly isolates two independent menstrual cycles', () {
      final start1 = DateTime(2026, 8, 1);
      final start2 = DateTime(2026, 8, 29);
      final entries = [
        PeriodEntry(id: '1', timestamp: start1, flow: FlowLevel.heavy),
        PeriodEntry(id: '2', timestamp: start1.add(const Duration(days: 1)), flow: FlowLevel.medium),
        PeriodEntry(id: '3', timestamp: start2, flow: FlowLevel.heavy),
        PeriodEntry(id: '4', timestamp: start2.add(const Duration(days: 1)), flow: FlowLevel.light),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      expect(cycles.length, 2);
      expect(cycles[0].length, 2);
      expect(cycles[1].length, 2);
    });

    test('Unsorted entries are sorted chronologically before grouping', () {
      final t1 = DateTime(2026, 8, 1);
      final t2 = DateTime(2026, 8, 2);
      final t3 = DateTime(2026, 8, 3);
      final entries = [
        PeriodEntry(id: '3', timestamp: t3, flow: FlowLevel.light),
        PeriodEntry(id: '1', timestamp: t1, flow: FlowLevel.heavy),
        PeriodEntry(id: '2', timestamp: t2, flow: FlowLevel.medium),
      ];

      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      expect(cycles.length, 1);
      expect(cycles.first.first.id, equals('1'));
      expect(cycles.first.last.id, equals('3'));
    });
  });
}
