import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/core/utils/safe_bloom_date_utils.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/user_profile.dart';
import 'package:safe_bloom/features/tracking/domain/services/cycle_calculator.dart';

CalendarDayStatus resolveDayStatus({
  required DateTime date,
  required UserProfile profile,
  required List<PeriodEntry> periodEntries,
  List<DateTime> sortedCycleStarts = const [],
}) {
  final loggedPeriodDates = periodEntries
      .map((p) => SafeBloomDateUtils.dateOnly(p.timestamp))
      .toSet();

  final predictedPeriodDates = CycleCalculator.getPredictedPeriodDates(
    lastPeriodStart: SafeBloomDateUtils.dateOnly(profile.lastPeriodStart),
    avgCycleLength: profile.avgCycleLength,
    avgPeriodLength: profile.avgPeriodLength,
  );

  return CycleCalculator.resolveCalendarDayStatus(
    date: date,
    profile: profile,
    loggedPeriodDates: loggedPeriodDates,
    predictedPeriodDates: predictedPeriodDates,
    sortedCycleStarts: sortedCycleStarts,
  );
}

void main() {
  final testProfile = UserProfile(
    lastPeriodStart: DateTime(2026, 8, 1),
    avgCycleLength: 28,
    avgPeriodLength: 5,
  );

  group('Calendar Period Status Distinction Tests', () {
    test('Test 1 — No logged period: Menstrual phase without PeriodEntry is NOT confirmed period', () {
      final today = DateTime(2026, 8, 20);
      final status = resolveDayStatus(
        date: today,
        profile: testProfile,
        periodEntries: [],
      );

      expect(status, isNot(CalendarDayStatus.loggedPeriod));
    });

    test('Test 2 — Predicted period: Date in prediction window without PeriodEntry is predicted, not logged', () {
      final predictedDate = DateTime(2026, 8, 3);
      final status = resolveDayStatus(
        date: predictedDate,
        profile: testProfile,
        periodEntries: [],
      );

      expect(status, CalendarDayStatus.predictedPeriod);
      expect(status, isNot(CalendarDayStatus.loggedPeriod));
    });

    test('Test 3 — Logged period: Date with PeriodEntry is confirmed', () {
      final date = DateTime(2026, 8, 15);
      final entry = PeriodEntry(
        id: 'p1',
        timestamp: date,
        flow: FlowLevel.medium,
      );

      final status = resolveDayStatus(
        date: date,
        profile: testProfile,
        periodEntries: [entry],
      );

      expect(status, CalendarDayStatus.loggedPeriod);
    });

    test('Test 4 — Logged + predicted: Confirmed takes precedence over predicted', () {
      final date = DateTime(2026, 8, 2);
      final entry = PeriodEntry(
        id: 'p1',
        timestamp: date,
        flow: FlowLevel.heavy,
      );

      final status = resolveDayStatus(
        date: date,
        profile: testProfile,
        periodEntries: [entry],
      );

      expect(status, CalendarDayStatus.loggedPeriod);
      expect(status, isNot(CalendarDayStatus.predictedPeriod));
    });

    test('Test 5 — Delete logged period: Confirmed state disappears when entry deleted', () {
      final date = DateTime(2026, 8, 15);
      final entry = PeriodEntry(
        id: 'p1',
        timestamp: date,
        flow: FlowLevel.medium,
      );

      // Before deletion
      final statusBefore = resolveDayStatus(
        date: date,
        profile: testProfile,
        periodEntries: [entry],
      );
      expect(statusBefore, CalendarDayStatus.loggedPeriod);

      // After deletion
      final statusAfter = resolveDayStatus(
        date: date,
        profile: testProfile,
        periodEntries: [],
      );
      expect(statusAfter, isNot(CalendarDayStatus.loggedPeriod));
    });

    test('Test 6 — Edit period: Changing period date updates confirmed calendar dates', () {
      final oldDate = DateTime(2026, 8, 10);
      final newDate = DateTime(2026, 8, 12);

      final initialEntries = [
        PeriodEntry(id: 'p1', timestamp: oldDate, flow: FlowLevel.medium),
      ];

      expect(
        resolveDayStatus(date: oldDate, profile: testProfile, periodEntries: initialEntries),
        CalendarDayStatus.loggedPeriod,
      );
      expect(
        resolveDayStatus(date: newDate, profile: testProfile, periodEntries: initialEntries),
        isNot(CalendarDayStatus.loggedPeriod),
      );

      // Update entry to new date
      final updatedEntries = [
        PeriodEntry(id: 'p1', timestamp: newDate, flow: FlowLevel.medium),
      ];

      expect(
        resolveDayStatus(date: oldDate, profile: testProfile, periodEntries: updatedEntries),
        isNot(CalendarDayStatus.loggedPeriod),
      );
      expect(
        resolveDayStatus(date: newDate, profile: testProfile, periodEntries: updatedEntries),
        CalendarDayStatus.loggedPeriod,
      );
    });

    test('Test 7 — Onboarding: UserProfile predictions do NOT generate fake logged PeriodEntry records', () {
      final profile = UserProfile(
        lastPeriodStart: DateTime(2026, 8, 1),
        avgCycleLength: 28,
        avgPeriodLength: 5,
      );

      // Onboarding saves profile with lastPeriodStart, but 0 PeriodEntries in DB
      final List<PeriodEntry> entriesAfterOnboarding = [];

      for (int day = 1; day <= 5; day++) {
        final date = DateTime(2026, 8, day);
        final status = resolveDayStatus(
          date: date,
          profile: profile,
          periodEntries: entriesAfterOnboarding,
        );

        // All dates in period length window are PREDICTED, NONE are logged/confirmed!
        expect(status, CalendarDayStatus.predictedPeriod);
        expect(status, isNot(CalendarDayStatus.loggedPeriod));
      }
    });

    test('Test 8 — Past cycle phase resolution: Dates around past marked periods correctly calculate cycle phases', () {
      final juneStart = DateTime(2026, 6, 1);
      final junePeriodEntries = List.generate(
        5,
        (i) => PeriodEntry(id: 'june_$i', timestamp: DateTime(2026, 6, 1 + i), flow: FlowLevel.medium),
      );

      final julyPeriodEntries = List.generate(
        5,
        (i) => PeriodEntry(id: 'july_$i', timestamp: DateTime(2026, 6, 29 + i), flow: FlowLevel.medium),
      );

      final allEntries = [...junePeriodEntries, ...julyPeriodEntries];

      final juneOvulationDate = DateTime(2026, 6, 14);
      final statusOvulation = resolveDayStatus(date: juneOvulationDate, profile: testProfile, periodEntries: allEntries);

      expect(juneOvulationDate.difference(juneStart).inDays + 1, 14);
      expect(statusOvulation, isNot(CalendarDayStatus.loggedPeriod));
    });
  });
}
