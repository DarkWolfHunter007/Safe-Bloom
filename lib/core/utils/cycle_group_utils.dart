import '../../features/tracking/domain/entities/period_entry.dart';

class CycleGroupUtils {
  /// Groups period entries into distinct period cycles.
  /// Two entries belong to the same cycle if they are <= [gapDays] apart.
  static List<List<PeriodEntry>> groupIntoCycles(
    List<PeriodEntry> entries, {
    int gapDays = 2,
  }) {
    if (entries.isEmpty) return [];

    final sorted = List<PeriodEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final List<List<PeriodEntry>> cycles = [];
    List<PeriodEntry> currentCycle = [];

    for (final entry in sorted) {
      if (currentCycle.isEmpty) {
        currentCycle.add(entry);
      } else {
        final prev = currentCycle.last;
        final diff = entry.timestamp.difference(prev.timestamp).inDays;
        if (diff <= gapDays) {
          currentCycle.add(entry);
        } else {
          cycles.add(currentCycle);
          currentCycle = [entry];
        }
      }
    }

    if (currentCycle.isNotEmpty) {
      cycles.add(currentCycle);
    }

    return cycles;
  }
}
