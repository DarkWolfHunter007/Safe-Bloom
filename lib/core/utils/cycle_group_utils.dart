import '../../features/tracking/domain/entities/period_entry.dart';

class CycleGroupUtils {
  /// Groups all period/spotting entries into chronological events where consecutive entries
  /// are <= [gapDays] apart.
  static List<List<PeriodEntry>> groupAllEvents(
    List<PeriodEntry> entries, {
    int gapDays = 4,
  }) {
    if (entries.isEmpty) return [];

    final sorted = List<PeriodEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final List<List<PeriodEntry>> groups = [];
    List<PeriodEntry> currentGroup = [];

    for (final entry in sorted) {
      if (currentGroup.isEmpty) {
        currentGroup.add(entry);
      } else {
        final prev = currentGroup.last;
        final prevDate = DateTime(prev.timestamp.year, prev.timestamp.month, prev.timestamp.day);
        final entryDate = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
        final diff = entryDate.difference(prevDate).inDays;
        if (diff <= gapDays) {
          currentGroup.add(entry);
        } else {
          groups.add(currentGroup);
          currentGroup = [entry];
        }
      }
    }

    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }

    return groups;
  }

  /// Groups period entries into genuine MENSTRUAL CYCLES.
  /// An event group is a genuine menstrual cycle if and only if it contains at least one
  /// active flow entry (light, medium, heavy).
  ///
  /// Pure spotting groups (where every entry is FlowLevel.spotting) are excluded because
  /// isolated spotting does not constitute a menstrual cycle boundary.
  static List<List<PeriodEntry>> groupIntoCycles(
    List<PeriodEntry> entries, {
    int gapDays = 4,
  }) {
    final allEvents = groupAllEvents(entries, gapDays: gapDays);
    return allEvents.where((group) => group.any((e) => e.isActiveFlow)).toList();
  }

  /// Returns the cycle anchor (start date) for a menstrual cycle.
  /// The cycle start anchor is always the first active-flow day (light, medium, heavy).
  /// Any leading spotting entries do NOT become Cycle Day 1.
  static DateTime getCycleStartDate(List<PeriodEntry> cycleEntries) {
    if (cycleEntries.isEmpty) {
      throw ArgumentError('cycleEntries cannot be empty');
    }
    final firstActive = cycleEntries.cast<PeriodEntry?>().firstWhere(
      (e) => e != null && e.isActiveFlow,
      orElse: () => null,
    );
    return firstActive?.timestamp ?? cycleEntries.first.timestamp;
  }

  /// Returns the cycle end date (last entry in the cycle).
  static DateTime getCycleEndDate(List<PeriodEntry> cycleEntries) {
    if (cycleEntries.isEmpty) {
      throw ArgumentError('cycleEntries cannot be empty');
    }
    return cycleEntries.last.timestamp;
  }

  /// Returns the duration of active menstrual bleeding days in a cycle.
  static int getCycleActiveDurationDays(List<PeriodEntry> cycleEntries) {
    final activeEntries = cycleEntries.where((e) => e.isActiveFlow).toList();
    if (activeEntries.isEmpty) return cycleEntries.length;
    return activeEntries.length;
  }

  /// Returns isolated spotting events that are not part of any genuine menstrual cycle.
  static List<PeriodEntry> getIsolatedSpottingEntries(
    List<PeriodEntry> entries, {
    int gapDays = 4,
  }) {
    final allEvents = groupAllEvents(entries, gapDays: gapDays);
    final List<PeriodEntry> isolated = [];
    for (final group in allEvents) {
      if (!group.any((e) => e.isActiveFlow)) {
        isolated.addAll(group);
      }
    }
    return isolated;
  }
}

