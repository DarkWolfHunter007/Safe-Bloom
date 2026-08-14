import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/user_profile.dart';
import 'package:safe_bloom/features/tracking/domain/services/cycle_calculator.dart';

void main() {
  test('UserProfile retains initialLastPeriodStart when created', () {
    final onboardingDate = DateTime(2026, 8, 1);
    final profile = UserProfile(lastPeriodStart: onboardingDate);

    expect(profile.lastPeriodStart, equals(onboardingDate));
    expect(profile.initialLastPeriodStart, equals(onboardingDate));
  });

  test('CycleCalculator calculates correct cycle day after period entry removal', () {
    final onboardingDate = DateTime(2026, 8, 1);
    final today = DateTime(2026, 8, 14);

    // Initial state: 14 days since onboarding start (Day 14)
    final cycleDayBefore = CycleCalculator.getCurrentCycleDay(onboardingDate, now: today);
    expect(cycleDayBefore, equals(14));

    // User logs period today -> lastPeriodStart becomes today (Day 1)
    final cycleDayDuring = CycleCalculator.getCurrentCycleDay(today, now: today);
    expect(cycleDayDuring, equals(1));

    // User unmarks period today -> lastPeriodStart reverts to onboardingDate (Day 14)
    final cycleDayAfter = CycleCalculator.getCurrentCycleDay(onboardingDate, now: today);
    expect(cycleDayAfter, equals(14));
  });
}
