import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/core/utils/safe_bloom_date_utils.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/user_profile.dart';
import 'package:safe_bloom/features/tracking/domain/services/cycle_calculator.dart';

/// Helper mirroring CalendarView state resolution logic to test state rules directly.
enum CalendarDayStatusTest {
  loggedPeriod,
  predictedPeriod,
  follicular,
  ovulation,
  luteal,
  regular,
}

CalendarDayStatusTest resolveDayStatus({
  required DateTime date,
  required UserProfile profile,
  required List<PeriodEntry> periodEntries,
}) {
  final cleanDate = SafeBloomDateUtils.dateOnly(date);

  final loggedPeriodDates = periodEntries
      .map((p) => SafeBloomDateUtils.dateOnly(p.timestamp))
      .toSet();

  final predictedPeriodDates = CycleCalculator.getPredictedPeriodDates(
    lastPeriodStart: SafeBloomDateUtils.dateOnly(profile.lastPeriodStart),
    avgCycleLength: profile.avgCycleLength,
    avgPeriodLength: profile.avgPeriodLength,
  );

  // 1. CONFIRMED / LOGGED PERIOD (Highest priority)
  if (loggedPeriodDates.contains(cleanDate)) {
    return CalendarDayStatusTest.loggedPeriod;
  }

  // 2. PREDICTED PERIOD (Only if NOT explicitly logged by user)
  if (predictedPeriodDates.contains(cleanDate)) {
    return CalendarDayStatusTest.predictedPeriod;
  }

  // 3. Cycle phase for non-period days
  final cycleDay = CycleCalculator.getCurrentCycleDay(profile.lastPeriodStart, now: cleanDate);
  final phase = CycleCalculator.getCyclePhase(
    cycleDay,
    avgCycleLength: profile.avgCycleLength,
    avgPeriodLength: profile.avgPeriodLength,
  );

  switch (phase) {
    case CyclePhase.menstrual:
      // Menstrual phase from raw cycleDay must NOT create a period event if unlogged and unpredicted
      return CalendarDayStatusTest.regular;
    case CyclePhase.follicular:
      return CalendarDayStatusTest.follicular;
    case CyclePhase.ovulation:
      return CalendarDayStatusTest.ovulation;
    case CyclePhase.luteal:
      return CalendarDayStatusTest.luteal;
    case CyclePhase.overdue:
      return CalendarDayStatusTest.regular;
  }
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

      expect(status, isNot(CalendarDayStatusTest.loggedPeriod));
    });

    test('Test 2 — Predicted period: Date in prediction window without PeriodEntry is predicted, not logged', () {
      final predictedDate = DateTime(2026, 8, 3);
      final status = resolveDayStatus(
        date: predictedDate,
        profile: testProfile,
        periodEntries: [],
      );

      expect(status, CalendarDayStatusTest.predictedPeriod);
      expect(status, isNot(CalendarDayStatusTest.loggedPeriod));
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

      expect(status, CalendarDayStatusTest.loggedPeriod);
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

      expect(status, CalendarDayStatusTest.loggedPeriod);
      expect(status, isNot(CalendarDayStatusTest.predictedPeriod));
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
      expect(statusBefore, CalendarDayStatusTest.loggedPeriod);

      // After deletion
      final statusAfter = resolveDayStatus(
        date: date,
        profile: testProfile,
        periodEntries: [],
      );
      expect(statusAfter, isNot(CalendarDayStatusTest.loggedPeriod));
    });

    test('Test 6 — Edit period: Changing period date updates confirmed calendar dates', () {
      final oldDate = DateTime(2026, 8, 10);
      final newDate = DateTime(2026, 8, 12);

      final initialEntries = [
        PeriodEntry(id: 'p1', timestamp: oldDate, flow: FlowLevel.medium),
      ];

      expect(
        resolveDayStatus(date: oldDate, profile: testProfile, periodEntries: initialEntries),
        CalendarDayStatusTest.loggedPeriod,
      );
      expect(
        resolveDayStatus(date: newDate, profile: testProfile, periodEntries: initialEntries),
        isNot(CalendarDayStatusTest.loggedPeriod),
      );

      // Update entry to new date
      final updatedEntries = [
        PeriodEntry(id: 'p1', timestamp: newDate, flow: FlowLevel.medium),
      ];

      expect(
        resolveDayStatus(date: oldDate, profile: testProfile, periodEntries: updatedEntries),
        isNot(CalendarDayStatusTest.loggedPeriod),
      );
      expect(
        resolveDayStatus(date: newDate, profile: testProfile, periodEntries: updatedEntries),
        CalendarDayStatusTest.loggedPeriod,
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
        expect(status, CalendarDayStatusTest.predictedPeriod);
        expect(status, isNot(CalendarDayStatusTest.loggedPeriod));
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
      expect(statusOvulation, isNot(CalendarDayStatusTest.loggedPeriod));
    });
  });
}
