import 'package:flutter_test/flutter_test.dart';
import 'package:safe_bloom/features/tracking/domain/services/pregnancy_calculator.dart';

void main() {
  group('PregnancyCalculator Unit Tests', () {
    test('Calculates gestational age accurately', () {
      final start = DateTime(2026, 1, 1);
      final now = DateTime(2026, 4, 15); // 104 days = 14 weeks, 6 days

      final age = PregnancyCalculator.getGestationalAge(start, now: now);
      expect(age.weeks, equals(14));
      expect(age.days, equals(6));
    });

    test('Calculates due date as 280 days after period start', () {
      final start = DateTime(2026, 1, 1);
      final dueDate = PregnancyCalculator.getEstimatedDueDate(start);

      expect(dueDate, equals(DateTime(2026, 10, 8)));
    });

    test('Determines trimester boundaries correctly', () {
      expect(PregnancyCalculator.getTrimester(8), equals('1st Trimester'));
      expect(PregnancyCalculator.getTrimester(14), equals('2nd Trimester'));
      expect(PregnancyCalculator.getTrimester(30), equals('3rd Trimester'));
    });

    test('Returns appropriate baby fruit size comparisons', () {
      expect(PregnancyCalculator.getBabySizeComparison(3), contains('Poppy Seed'));
      expect(PregnancyCalculator.getBabySizeComparison(12), contains('Avocado'));
      expect(PregnancyCalculator.getBabySizeComparison(38), contains('Watermelon'));
    });

    test('Provides trimester-specific pregnancy advice', () {
      expect(PregnancyCalculator.getPregnancyAdvice(6), contains('1st Trimester'));
      expect(PregnancyCalculator.getPregnancyAdvice(20), contains('2nd Trimester'));
      expect(PregnancyCalculator.getPregnancyAdvice(35), contains('3rd Trimester'));
    });

    test('Calculates LMP anchor correctly from due date and conception', () {
      final dueDate = DateTime(2026, 10, 8);
      final lmp = PregnancyCalculator.calculateLmpFromDueDate(dueDate);
      expect(lmp, equals(DateTime(2026, 1, 1)));

      final conception = DateTime(2026, 1, 15);
      final lmpFromConception = PregnancyCalculator.calculateLmpFromConception(conception);
      expect(lmpFromConception, equals(DateTime(2026, 1, 1)));
    });
  });
}
