import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/core/utils/cycle_group_utils.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';

void main() {
  group('CycleGroupUtils Tests', () {
    test('Empty entries return empty cycles', () {
      final cycles = CycleGroupUtils.groupIntoCycles([]);
      expect(cycles, isEmpty);
    });

    test('Consecutive daily entries group into single cycle', () {
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

    test('Entries separated by more than 2 days split into separate cycles', () {
      final start1 = DateTime(2026, 8, 1);
      final start2 = DateTime(2026, 8, 28);
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
  });
}
