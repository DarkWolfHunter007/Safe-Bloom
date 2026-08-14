import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/core/utils/safe_bloom_date_utils.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';
import 'package:safe_bloom/features/tracking/domain/services/cycle_calculator.dart';

void main() {
  group('Historical Period Range Logging Tests', () {
    test('Calculates correct number of period entries across multi-day range', () {
      final startDate = DateTime(2026, 6, 1);
      final endDate = DateTime(2026, 6, 5);

      final entries = <PeriodEntry>[];
      DateTime curr = SafeBloomDateUtils.dateOnly(startDate);
      final cleanEnd = SafeBloomDateUtils.dateOnly(endDate);

      while (!curr.isAfter(cleanEnd)) {
        entries.add(
          PeriodEntry(
            id: 'hist_${curr.day}',
            timestamp: curr,
            flow: FlowLevel.medium,
            notes: 'Historical log test',
          ),
        );
        curr = curr.add(const Duration(days: 1));
      }

      expect(entries.length, 5);
      expect(entries.first.timestamp, DateTime(2026, 6, 1));
      expect(entries.last.timestamp, DateTime(2026, 6, 5));
    });

    test('Recalculates profile averages when historical entries are provided', () {
      // Historical entries for 2 previous cycles (June and July)
      final juneEntries = List.generate(
        5,
        (i) => PeriodEntry(id: 'june_$i', timestamp: DateTime(2026, 6, 1 + i), flow: FlowLevel.medium),
      );

      final julyEntries = List.generate(
        5,
        (i) => PeriodEntry(id: 'july_$i', timestamp: DateTime(2026, 6, 29 + i), flow: FlowLevel.medium), // 28 days later
      );

      final allEntries = [...juneEntries, ...julyEntries];
      final averages = CycleCalculator.calculateAveragesFromEntries(allEntries);

      expect(averages['avgPeriodLength'], 5);
      expect(averages['avgCycleLength'], 28);
    });

    test('Logs individual custom daily flow patterns for irregular cycles', () {
      final flows = [FlowLevel.medium, FlowLevel.heavy, FlowLevel.medium, FlowLevel.light, FlowLevel.light];
      final entries = List.generate(
        flows.length,
        (i) => PeriodEntry(
          id: 'feb_$i',
          timestamp: DateTime(2026, 2, 2 + i),
          flow: flows[i],
        ),
      );

      expect(entries.length, 5);
      expect(entries[0].flow, FlowLevel.medium);
      expect(entries[1].flow, FlowLevel.heavy);
      expect(entries[2].flow, FlowLevel.medium);
      expect(entries[3].flow, FlowLevel.light);
      expect(entries[4].flow, FlowLevel.light);
    });
  });
}
