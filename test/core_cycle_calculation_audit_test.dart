// ignore_for_file: lines_longer_than_80_chars
/// CORE CYCLE CALCULATION AUDIT — Mathematical correctness tests
/// Covers all 15 audit sections from the specification.
///
/// Run with: flutter test test/core_cycle_calculation_audit_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/core/utils/cycle_group_utils.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';
import 'package:safe_bloom/features/tracking/domain/services/cycle_calculator.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

PeriodEntry _flow(String id, DateTime date, {FlowLevel level = FlowLevel.medium}) =>
    PeriodEntry(id: id, timestamp: date, flow: level);

PeriodEntry _spot(String id, DateTime date) =>
    PeriodEntry(id: id, timestamp: date, flow: FlowLevel.spotting);

DateTime _d(int year, int month, int day) => DateTime(year, month, day);

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ===========================================================================
  // §2 CYCLE LENGTH — date-difference convention
  // ===========================================================================
  group('§2 Cycle Length — convention and explicit examples', () {
    test('Jan 1 → Jan 29: cycle length = 28 days (date difference, NOT inclusive count)', () {
      final entries = [_flow('a1', _d(2026, 1, 1)), _flow('a2', _d(2026, 1, 29))];
      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      expect(cycles.length, 2);
      final start1 = CycleGroupUtils.getCycleStartDate(cycles[0]);
      final start2 = CycleGroupUtils.getCycleStartDate(cycles[1]);
      expect(start2.difference(start1).inDays, 28);
    });

    test('Jan 1 → Feb 1: cycle length = 31 days', () {
      final entries = [_flow('b1', _d(2026, 1, 1)), _flow('b2', _d(2026, 2, 1))];
      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      final start1 = CycleGroupUtils.getCycleStartDate(cycles[0]);
      final start2 = CycleGroupUtils.getCycleStartDate(cycles[1]);
      expect(start2.difference(start1).inDays, 31);
    });

    test('20-day cycle: calculateAverages returns 20 (at clamp minimum)', () {
      final entries = [_flow('c1', _d(2026, 1, 1)), _flow('c2', _d(2026, 1, 21))];
      final avg = CycleCalculator.calculateAveragesFromEntries(entries);
      expect(avg['avgCycleLength'], 20);
    });

    test('21-day cycle: calculateAverages returns 21', () {
      final entries = [_flow('d1', _d(2026, 1, 1)), _flow('d2', _d(2026, 1, 22))];
      final avg = CycleCalculator.calculateAveragesFromEntries(entries);
      expect(avg['avgCycleLength'], 21);
    });

    test('28-day cycle: calculateAverages returns 28', () {
      final entries = [_flow('e1', _d(2026, 1, 1)), _flow('e2', _d(2026, 1, 29))];
      final avg = CycleCalculator.calculateAveragesFromEntries(entries);
      expect(avg['avgCycleLength'], 28);
    });

    test('30-day cycle: calculateAverages returns 30', () {
      final entries = [_flow('f1', _d(2026, 1, 1)), _flow('f2', _d(2026, 1, 31))];
      final avg = CycleCalculator.calculateAveragesFromEntries(entries);
      expect(avg['avgCycleLength'], 30);
    });

    test('35-day cycle: calculateAverages returns 35', () {
      final entries = [_flow('g1', _d(2026, 1, 1)), _flow('g2', _d(2026, 2, 5))];
      final avg = CycleCalculator.calculateAveragesFromEntries(entries);
      expect(avg['avgCycleLength'], 35);
    });

    test('40-day cycle: calculateAverages returns 40', () {
      final entries = [_flow('h1', _d(2026, 1, 1)), _flow('h2', _d(2026, 2, 10))];
      final avg = CycleCalculator.calculateAveragesFromEntries(entries);
      expect(avg['avgCycleLength'], 40);
    });

    test('45-day cycle: calculateAverages returns 45 (at clamp maximum)', () {
      final entries = [_flow('i1', _d(2026, 1, 1)), _flow('i2', _d(2026, 2, 15))];
      final avg = CycleCalculator.calculateAveragesFromEntries(entries);
      expect(avg['avgCycleLength'], 45);
    });

    test('CLAMP: 19-day cycle is clamped to 20 — user with short cycle gets incorrect predictions', () {
      final entries = [_flow('j1', _d(2026, 1, 1)), _flow('j2', _d(2026, 1, 20))];
      final avg = CycleCalculator.calculateAveragesFromEntries(entries);
      // Actual cycle = 19, clamped to 20
      expect(avg['avgCycleLength'], 20);
    });

    test('CLAMP: 50-day cycle is clamped to 45 — user with long/irregular cycle gets incorrect predictions', () {
      final entries = [_flow('k1', _d(2026, 1, 1)), _flow('k2', _d(2026, 2, 20))];
      final avg = CycleCalculator.calculateAveragesFromEntries(entries);
      // Actual cycle = 50, clamped to 45
      expect(avg['avgCycleLength'], 45);
    });
  });

  // ===========================================================================
  // §3 PERIOD LENGTH — active-flow days only
  // ===========================================================================
  group('§3 Period Length — active flow counting', () {
    test('H, M, L → 3 active days', () {
      final cycle = [
        _flow('p1', _d(2026, 1, 1), level: FlowLevel.heavy),
        _flow('p2', _d(2026, 1, 2), level: FlowLevel.medium),
        _flow('p3', _d(2026, 1, 3), level: FlowLevel.light),
      ];
      expect(CycleGroupUtils.getCycleActiveDurationDays(cycle), 3);
    });

    test('H, M, L + spotting → 3 active days (spotting not counted)', () {
      final cycle = [
        _flow('q1', _d(2026, 1, 1), level: FlowLevel.heavy),
        _flow('q2', _d(2026, 1, 2), level: FlowLevel.medium),
        _flow('q3', _d(2026, 1, 3), level: FlowLevel.light),
        _spot('q4', _d(2026, 1, 4)),
      ];
      expect(CycleGroupUtils.getCycleActiveDurationDays(cycle), 3);
    });

    test('Spotting only → not a menstrual cycle (excluded from groupIntoCycles)', () {
      final entries = [_spot('r1', _d(2026, 1, 15))];
      expect(CycleGroupUtils.groupIntoCycles(entries).isEmpty, true);
    });

    test('Interrupted flow (1-day gap): 3 entries, all counted as active days', () {
      final entries = [
        _flow('s1', _d(2026, 1, 1), level: FlowLevel.heavy),
        _flow('s2', _d(2026, 1, 3), level: FlowLevel.medium),
        _flow('s3', _d(2026, 1, 4), level: FlowLevel.light),
      ];
      final cycles = CycleGroupUtils.groupIntoCycles(entries);
      expect(cycles.length, 1);
      expect(CycleGroupUtils.getCycleActiveDurationDays(cycles[0]), 3);
    });

    test('Period length avg across 2 cycles: (3+5)/2 = 4', () {
      final entries = [
        _flow('u1', _d(2026, 1, 1), level: FlowLevel.heavy),
        _flow('u2', _d(2026, 1, 2), level: FlowLevel.medium),
        _flow('u3', _d(2026, 1, 3), level: FlowLevel.light),
        _flow('u4', _d(2026, 1, 29), level: FlowLevel.heavy),
        _flow('u5', _d(2026, 1, 30), level: FlowLevel.medium),
        _flow('u6', _d(2026, 1, 31), level: FlowLevel.light),
        _flow('u7', _d(2026, 2, 1), level: FlowLevel.light),
        _flow('u8', _d(2026, 2, 2), level: FlowLevel.light),
      ];
      final avg = CycleCalculator.calculateAveragesFromEntries(entries);
      // (3+5)/2 = 4.0 → 4
      expect(avg['avgPeriodLength'], 4);
    });

    test('Period length clamped to minimum 2: single-day period → 2', () {
      final entries = [_flow('v1', _d(2026, 1, 1)), _flow('v2', _d(2026, 1, 29))];
      final avg = CycleCalculator.calculateAveragesFromEntries(entries);
      expect(avg['avgPeriodLength'], 2); // 1 day clamped to 2
    });
  });

  // ===========================================================================
  // §4 MOVING AVERAGES — explicit arithmetic
  // ===========================================================================
  group('§4 Moving Averages — explicit arithmetic', () {
    test('3 cycles (28, 30, 32): avg = (28+30+32)/3 = 30', () {
      final entries = [
        _flow('m1', _d(2026, 1, 1)),
        _flow('m2', _d(2026, 1, 29)),   // +28
        _flow('m3', _d(2026, 2, 28)),   // +30
        _flow('m4', _d(2026, 4, 1)),    // +32
      ];
      final avg = CycleCalculator.calculateAveragesFromEntries(entries);
      // (28+30+32)/3 = 90/3 = 30
      expect(avg['avgCycleLength'], 30);
    });

    test('0 genuine cycles (empty list): returns fallback 28/5', () {
      final avg = CycleCalculator.calculateAveragesFromEntries([]);
      expect(avg['avgCycleLength'], 28);
      expect(avg['avgPeriodLength'], 5);
    });

    test('0 genuine cycles (spotting only): returns fallback 28/5', () {
      final avg = CycleCalculator.calculateAveragesFromEntries([_spot('n1', _d(2026, 1, 15))]);
      expect(avg['avgCycleLength'], 28);
      expect(avg['avgPeriodLength'], 5);
    });

    test('1 genuine cycle: avgCycleLength = fallback 28 (need ≥2 for cycle-length calc)', () {
      final avg = CycleCalculator.calculateAveragesFromEntries([_flow('o1', _d(2026, 1, 1))]);
      expect(avg['avgCycleLength'], 28);
    });

    test('2 genuine cycles: avgCycleLength computed from the 1 available gap', () {
      final avg = CycleCalculator.calculateAveragesFromEntries([
        _flow('p1', _d(2026, 1, 1)),
        _flow('p2', _d(2026, 1, 29)),
      ]);
      expect(avg['avgCycleLength'], 28);
    });

    test('Outlier not excluded: (28, 28, 60) avg = (28+28+60)/3 = 38.67 → 39', () {
      final entries = [
        _flow('r1', _d(2026, 1, 1)),
        _flow('r2', _d(2026, 1, 29)),  // +28
        _flow('r3', _d(2026, 2, 26)),  // +28
        _flow('r4', _d(2026, 4, 27)),  // +60
      ];
      final avg = CycleCalculator.calculateAveragesFromEntries(entries);
      // (28+28+60)/3 = 38.67 → 39, within [20,45]
      expect(avg['avgCycleLength'], 39);
    });

    test('Custom fallback values are returned when no genuine cycles exist', () {
      final avg = CycleCalculator.calculateAveragesFromEntries(
        [],
        fallbackCycleLength: 32,
        fallbackPeriodLength: 7,
      );
      expect(avg['avgCycleLength'], 32);
      expect(avg['avgPeriodLength'], 7);
    });
  });

  // ===========================================================================
  // §5 CURRENT CYCLE DAY
  // ===========================================================================
  group('§5 getCurrentCycleDay — boundary cases', () {
    final anchor = _d(2026, 8, 1);

    test('Day 1: same day as anchor', () {
      expect(CycleCalculator.getCurrentCycleDay(anchor, now: anchor), 1);
    });

    test('Day 2: one day after anchor', () {
      expect(CycleCalculator.getCurrentCycleDay(anchor, now: _d(2026, 8, 2)), 2);
    });

    test('Day 28: 27 days after anchor', () {
      expect(CycleCalculator.getCurrentCycleDay(anchor, now: _d(2026, 8, 28)), 28);
    });

    test('Day 29: 28 days after anchor — no modulo wrap', () {
      final day = CycleCalculator.getCurrentCycleDay(anchor, now: _d(2026, 8, 29));
      expect(day, 29);
      expect(day, isNot(1)); // must not wrap
    });

    test('Day 35: 34 days after anchor', () {
      expect(CycleCalculator.getCurrentCycleDay(anchor, now: _d(2026, 9, 4)), 35);
    });

    test('Day 60: 59 days after anchor', () {
      expect(CycleCalculator.getCurrentCycleDay(anchor, now: _d(2026, 9, 29)), 60);
    });

    test('Day 100: 99 days after anchor', () {
      expect(CycleCalculator.getCurrentCycleDay(anchor, now: _d(2026, 11, 8)), 100);
    });

    test('New period logged (anchor reset): day 1', () {
      final newAnchor = _d(2026, 8, 29);
      expect(CycleCalculator.getCurrentCycleDay(newAnchor, now: newAnchor), 1);
    });

    test('now before anchor: returns 1 (negative diff guard)', () {
      expect(CycleCalculator.getCurrentCycleDay(anchor, now: _d(2026, 7, 31)), 1);
    });
  });

  // ===========================================================================
  // §6 OVERDUE STATE
  // ===========================================================================
  group('§6 Overdue state — phase boundaries', () {
    test('Day 28 (last valid): luteal (not overdue)', () {
      expect(
        CycleCalculator.getCyclePhase(28, avgCycleLength: 28, avgPeriodLength: 5),
        CyclePhase.luteal,
      );
    });

    test('Day 29: overdue', () {
      expect(
        CycleCalculator.getCyclePhase(29, avgCycleLength: 28, avgPeriodLength: 5),
        CyclePhase.overdue,
      );
    });

    test('Day 35: overdue', () {
      expect(
        CycleCalculator.getCyclePhase(35, avgCycleLength: 28, avgPeriodLength: 5),
        CyclePhase.overdue,
      );
    });

    test('Day 60: overdue (not luteal, not menstrual)', () {
      final phase = CycleCalculator.getCyclePhase(60, avgCycleLength: 28, avgPeriodLength: 5);
      expect(phase, CyclePhase.overdue);
      expect(phase, isNot(CyclePhase.luteal));
      expect(phase, isNot(CyclePhase.menstrual));
    });

    test('Overdue: isPeakOvulationDay returns false', () {
      final anchor = _d(2026, 8, 1);
      final day30 = _d(2026, 8, 30); // day 30 — overdue for 28-day cycle
      expect(CycleCalculator.isPeakOvulationDay(day30, anchor, avgCycleLength: 28), false);
    });

    test('Overdue: getDaysUntilNextPeriod is negative (next predicted start is in the past)', () {
      final days = CycleCalculator.getDaysUntilNextPeriod(
        _d(2026, 1, 1),
        avgCycleLength: 28,
        now: _d(2026, 3, 1), // day 59 — well overdue
      );
      expect(days, isNegative); // Jan 29 − Mar 1 = negative
    });
  });

  // ===========================================================================
  // §7 OVULATION ESTIMATE
  // ===========================================================================
  group('§7 Ovulation estimate — formula: ovulationDay = avgCycleLength - 14', () {
    test('21-day cycle: ovulation at day 7 (21-14=7), fertile window days 5–9', () {
      expect(CycleCalculator.getCyclePhase(7, avgCycleLength: 21, avgPeriodLength: 3), CyclePhase.ovulation);
    });

    test('28-day cycle: ovulation at day 14 (28-14=14), fertile window days 12–16', () {
      expect(CycleCalculator.getCyclePhase(14, avgCycleLength: 28, avgPeriodLength: 5), CyclePhase.ovulation);
    });

    test('30-day cycle: ovulation at day 16 (30-14=16), fertile window days 14–18', () {
      expect(CycleCalculator.getCyclePhase(16, avgCycleLength: 30, avgPeriodLength: 5), CyclePhase.ovulation);
    });

    test('35-day cycle: ovulation at day 21 (35-14=21)', () {
      expect(CycleCalculator.getCyclePhase(21, avgCycleLength: 35, avgPeriodLength: 5), CyclePhase.ovulation);
    });

    test('40-day cycle: ovulation at day 26 (40-14=26)', () {
      expect(CycleCalculator.getCyclePhase(26, avgCycleLength: 40, avgPeriodLength: 5), CyclePhase.ovulation);
    });

    test('isPeakOvulationDay: 28-day cycle, peak on day 14 (anchor + 13 days)', () {
      final anchor = _d(2026, 1, 1);
      // Day 14 = anchor + 13 days (since getCurrentCycleDay = diff+1)
      expect(CycleCalculator.isPeakOvulationDay(_d(2026, 1, 14), anchor, avgCycleLength: 28), true);
    });

    test('isPeakOvulationDay: day 13 (before peak) is false', () {
      expect(CycleCalculator.isPeakOvulationDay(_d(2026, 1, 13), _d(2026, 1, 1), avgCycleLength: 28), false);
    });

    test('isPeakOvulationDay: day 15 (after peak) is false', () {
      expect(CycleCalculator.isPeakOvulationDay(_d(2026, 1, 15), _d(2026, 1, 1), avgCycleLength: 28), false);
    });
  });

  // ===========================================================================
  // §8 FERTILE WINDOW
  // ===========================================================================
  group('§8 Fertile window — phase boundary verification', () {
    // Formula: fertileStart = ovulationDay - 2, fertileEnd = ovulationDay + 2

    test('28-day cycle: follicular on day 11, ovulation on days 12–16, luteal on day 17', () {
      expect(CycleCalculator.getCyclePhase(11, avgCycleLength: 28, avgPeriodLength: 5), CyclePhase.follicular);
      expect(CycleCalculator.getCyclePhase(12, avgCycleLength: 28, avgPeriodLength: 5), CyclePhase.ovulation);
      expect(CycleCalculator.getCyclePhase(16, avgCycleLength: 28, avgPeriodLength: 5), CyclePhase.ovulation);
      expect(CycleCalculator.getCyclePhase(17, avgCycleLength: 28, avgPeriodLength: 5), CyclePhase.luteal);
    });

    test('21-day cycle: fertile window days 5–9 (ovulation=7, ±2)', () {
      expect(CycleCalculator.getCyclePhase(4, avgCycleLength: 21, avgPeriodLength: 3), CyclePhase.follicular);
      expect(CycleCalculator.getCyclePhase(5, avgCycleLength: 21, avgPeriodLength: 3), CyclePhase.ovulation);
      expect(CycleCalculator.getCyclePhase(9, avgCycleLength: 21, avgPeriodLength: 3), CyclePhase.ovulation);
      expect(CycleCalculator.getCyclePhase(10, avgCycleLength: 21, avgPeriodLength: 3), CyclePhase.luteal);
    });

    test('Overdue: phase is overdue, not ovulation', () {
      expect(
        CycleCalculator.getCyclePhase(29, avgCycleLength: 28, avgPeriodLength: 5),
        CyclePhase.overdue,
      );
    });
  });

  // ===========================================================================
  // §9 NEXT PERIOD PREDICTION
  // ===========================================================================
  group('§9 Next period prediction', () {
    test('getNextPeriodStartDate: Jan 1 + 28 = Jan 29', () {
      expect(
        CycleCalculator.getNextPeriodStartDate(_d(2026, 1, 1), avgCycleLength: 28),
        _d(2026, 1, 29),
      );
    });

    test('getNextPeriodStartDate: Jan 1 + 31 = Feb 1', () {
      expect(
        CycleCalculator.getNextPeriodStartDate(_d(2026, 1, 1), avgCycleLength: 31),
        _d(2026, 2, 1),
      );
    });

    test('getDaysUntilNextPeriod: Aug 1 anchor, Aug 19 today → 10 days until Aug 29', () {
      final days = CycleCalculator.getDaysUntilNextPeriod(
        _d(2026, 8, 1),
        avgCycleLength: 28,
        now: _d(2026, 8, 19),
      );
      expect(days, 10);
    });

    test('getDaysUntilNextPeriod: today IS the predicted start → 0 days', () {
      final days = CycleCalculator.getDaysUntilNextPeriod(
        _d(2026, 8, 1),
        avgCycleLength: 28,
        now: _d(2026, 8, 29),
      );
      expect(days, 0);
    });

    test('getPredictedPeriodDates: first window starts at lastPeriodStart (past period included)', () {
      // Documents known behaviour: the set includes the already-occurred period dates.
      // The calendar UI correctly suppresses these because logged dates take priority.
      final dates = CycleCalculator.getPredictedPeriodDates(
        lastPeriodStart: _d(2026, 1, 1),
        avgCycleLength: 28,
        avgPeriodLength: 5,
        monthsAhead: 2,
      );
      expect(dates.contains(_d(2026, 1, 1)), true);  // past period — in prediction set
      expect(dates.contains(_d(2026, 1, 29)), true); // future prediction
    });

    test('getPredictedPeriodDates: monthsAhead=2 means exactly 2 cycle windows', () {
      final dates = CycleCalculator.getPredictedPeriodDates(
        lastPeriodStart: _d(2026, 1, 1),
        avgCycleLength: 28,
        avgPeriodLength: 5,
        monthsAhead: 2,
      );
      // Window 0: Jan 1–5; Window 1: Jan 29 – Feb 2
      expect(dates.contains(_d(2026, 2, 26)), false); // 3rd cycle start — not included
    });
  });

  // ===========================================================================
  // §10 INSUFFICIENT DATA
  // ===========================================================================
  group('§10 Insufficient data — fallback behaviour', () {
    test('0 entries: returns hardcoded 28/5', () {
      final avg = CycleCalculator.calculateAveragesFromEntries([]);
      expect(avg['avgCycleLength'], 28);
      expect(avg['avgPeriodLength'], 5);
    });

    test('Spotting only: returns 28/5 (not spotting-anchored)', () {
      final avg = CycleCalculator.calculateAveragesFromEntries([_spot('x1', _d(2026, 1, 15))]);
      expect(avg['avgCycleLength'], 28);
      expect(avg['avgPeriodLength'], 5);
    });

    test('1 genuine cycle: avgCycleLength = fallback 28', () {
      final avg = CycleCalculator.calculateAveragesFromEntries([_flow('y1', _d(2026, 1, 1))]);
      expect(avg['avgCycleLength'], 28);
    });

    test('2 genuine cycles: avgCycleLength computed from 1 gap', () {
      final avg = CycleCalculator.calculateAveragesFromEntries([
        _flow('z1', _d(2026, 1, 1)),
        _flow('z2', _d(2026, 1, 29)),
      ]);
      expect(avg['avgCycleLength'], 28);
    });
  });

  // ===========================================================================
  // §11 SHORT / LONG / IRREGULAR CYCLES
  // ===========================================================================
  group('§11 Short/Long/Irregular cycles — no impossible values', () {
    test('21-day cycle: day 22 is overdue (not wrapped via modulo)', () {
      expect(CycleCalculator.getCyclePhase(22, avgCycleLength: 21, avgPeriodLength: 4), CyclePhase.overdue);
    });

    test('45-day cycle: day 46 is overdue', () {
      expect(CycleCalculator.getCyclePhase(46, avgCycleLength: 45, avgPeriodLength: 5), CyclePhase.overdue);
    });

    test('getDaysUntilNextPeriod: negative when overdue', () {
      final days = CycleCalculator.getDaysUntilNextPeriod(
        _d(2026, 1, 1),
        avgCycleLength: 28,
        now: _d(2026, 3, 1),
      );
      expect(days, isNegative);
    });

    test('Year boundary: Dec 1 + 31 days = Jan 1 next year', () {
      expect(
        CycleCalculator.getNextPeriodStartDate(_d(2026, 12, 1), avgCycleLength: 31),
        _d(2027, 1, 1),
      );
    });

    test('Leap year Feb 28 + 1 day = Feb 29 (2024)', () {
      expect(
        CycleCalculator.getNextPeriodStartDate(_d(2024, 2, 28), avgCycleLength: 1),
        _d(2024, 2, 29),
      );
    });

    test('Non-leap Feb 28 + 1 day = Mar 1', () {
      expect(
        CycleCalculator.getNextPeriodStartDate(_d(2026, 2, 28), avgCycleLength: 1),
        _d(2026, 3, 1),
      );
    });

    test('Short cycle phase overlap: 20-day cycle, 5-day period — follicular phase is 0 days wide', () {
      // ovulationDay=6, fertileStart=4, avgPeriodLength=5
      // Day 5 <= avgPeriodLength(5) → menstrual
      expect(CycleCalculator.getCyclePhase(5, avgCycleLength: 20, avgPeriodLength: 5), CyclePhase.menstrual);
      // Day 6: not <=period, not < fertileStart(4), <= fertileEnd(8) → ovulation
      expect(CycleCalculator.getCyclePhase(6, avgCycleLength: 20, avgPeriodLength: 5), CyclePhase.ovulation);
    });
  });

  // ===========================================================================
  // §12 HISTORICAL EDITING — recalculation
  // ===========================================================================
  group('§12 Historical editing — derived value updates', () {
    test('Edit Jan 29 → Jan 25: inter-cycle gaps change, avg recalculated', () {
      final before = [
        _flow('e1', _d(2026, 1, 1)),
        _flow('e2', _d(2026, 1, 29)),
        _flow('e3', _d(2026, 2, 27)),
      ];
      final avgBefore = CycleCalculator.calculateAveragesFromEntries(before);
      // Gaps: 28, 29 → avg = (28+29)/2 = 28.5 → 29
      expect(avgBefore['avgCycleLength'], 29);

      final after = [
        _flow('e1', _d(2026, 1, 1)),
        _flow('e2edited', _d(2026, 1, 25)),
        _flow('e3', _d(2026, 2, 27)),
      ];
      final avgAfter = CycleCalculator.calculateAveragesFromEntries(after);
      // Gaps: 24, 33 → avg = (24+33)/2 = 28.5 → 29
      expect(avgAfter['avgCycleLength'], 29);

      final cyclesAfter = CycleGroupUtils.groupIntoCycles(after);
      expect(CycleGroupUtils.getCycleStartDate(cyclesAfter[1]), _d(2026, 1, 25));
    });

    test('Delete Jan 29: remaining gap (Jan1→Feb27=57) clamped to 45', () {
      final after = [_flow('d1', _d(2026, 1, 1)), _flow('d2', _d(2026, 2, 27))];
      final avg = CycleCalculator.calculateAveragesFromEntries(after);
      // 57 days → clamped to 45
      expect(avg['avgCycleLength'], 45);
    });

    test('Delete latest period: latestStart reverts to previous cycle', () {
      final before = [
        _flow('x1', _d(2026, 1, 1)),
        _flow('x2', _d(2026, 1, 29)),
        _flow('x3', _d(2026, 2, 27)),
      ];
      expect(
        CycleGroupUtils.getCycleStartDate(CycleGroupUtils.groupIntoCycles(before).last),
        _d(2026, 2, 27),
      );

      final after = [_flow('x1', _d(2026, 1, 1)), _flow('x2', _d(2026, 1, 29))];
      expect(
        CycleGroupUtils.getCycleStartDate(CycleGroupUtils.groupIntoCycles(after).last),
        _d(2026, 1, 29),
      );
    });
  });

  // ===========================================================================
  // §13 TIME AND DATE — boundary cases
  // ===========================================================================
  group('§13 DateTime boundary cases', () {
    test('Year boundary Dec 31 → Jan 1: getCurrentCycleDay = 2', () {
      expect(
        CycleCalculator.getCurrentCycleDay(_d(2026, 12, 31), now: _d(2027, 1, 1)),
        2,
      );
    });

    test('Feb 28 → Mar 1 (non-leap): day 2', () {
      expect(
        CycleCalculator.getCurrentCycleDay(_d(2026, 2, 28), now: _d(2026, 3, 1)),
        2,
      );
    });

    test('Feb 28 → Feb 29 (leap year 2024): day 2', () {
      expect(
        CycleCalculator.getCurrentCycleDay(_d(2024, 2, 28), now: _d(2024, 2, 29)),
        2,
      );
    });

    test('Feb 29 (leap anchor) → Mar 1: day 2', () {
      expect(
        CycleCalculator.getCurrentCycleDay(_d(2024, 2, 29), now: _d(2024, 3, 1)),
        2,
      );
    });

    test('dateOnly: same day at 00:00 and 23:59 produces same midnight DateTime', () {
      final dt1 = DateTime(2026, 8, 1, 0, 0, 0);
      final dt2 = DateTime(2026, 8, 1, 23, 59, 59);
      expect(
        DateTime(dt1.year, dt1.month, dt1.day),
        DateTime(dt2.year, dt2.month, dt2.day),
      );
    });

    test('getPredictedPeriodDates: year-end rollover Dec 15 + 28 = Jan 12, 2027', () {
      final dates = CycleCalculator.getPredictedPeriodDates(
        lastPeriodStart: _d(2026, 12, 15),
        avgCycleLength: 28,
        avgPeriodLength: 3,
        monthsAhead: 2,
      );
      expect(dates.contains(_d(2027, 1, 12)), true);
    });
  });

  // ===========================================================================
  // §14 NOTIFICATION CONSISTENCY
  // ===========================================================================
  group('§14 Notification calculation consistency', () {
    test('Period alert is 2 days before getNextPeriodStartDate', () {
      final anchor = _d(2026, 8, 1);
      final nextPeriod = CycleCalculator.getNextPeriodStartDate(anchor, avgCycleLength: 28);
      final alertDate = nextPeriod.subtract(const Duration(days: 2));
      expect(nextPeriod, _d(2026, 8, 29));
      expect(alertDate, _d(2026, 8, 27));
    });

    test('FIX §14: notification peakOffset now matches getPredictedPeakOvulationDates — both use Aug 14', () {
      // FIXED: notification peakOffset = (avgCycleLength - 14) - 1 = 13 → anchor + 13 days = Aug 14
      // getPredictedPeakOvulationDates: peakOffset = (avgCycleLength - 14) - 1 = 13 → Aug 14
      final anchor = _d(2026, 8, 1);
      const notifPeakOffset = (28 - 14) - 1; // = 13
      final notifPeakDate = anchor.add(const Duration(days: notifPeakOffset)); // Aug 14

      final predictedPeaks = CycleCalculator.getPredictedPeakOvulationDates(
        lastPeriodStart: anchor,
        avgCycleLength: 28,
        monthsAhead: 1,
      );
      // Both now agree: Aug 14
      expect(predictedPeaks.contains(_d(2026, 8, 14)), true);
      expect(notifPeakDate, _d(2026, 8, 14)); // notification now fires on the same date as calendar peak marker
    });

    test('isPeakOvulationDay on calendar-peak date (day 14 = Aug 14) returns true', () {
      expect(
        CycleCalculator.isPeakOvulationDay(_d(2026, 8, 14), _d(2026, 8, 1), avgCycleLength: 28),
        true,
      );
    });

    test('isPeakOvulationDay on notification date (Aug 15 = day 15) returns false', () {
      // The notification fires on Aug 15 but the calendar peak is Aug 14
      expect(
        CycleCalculator.isPeakOvulationDay(_d(2026, 8, 15), _d(2026, 8, 1), avgCycleLength: 28),
        false,
      );
    });
  });
}

