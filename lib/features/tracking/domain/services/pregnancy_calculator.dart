class PregnancyAge {
  final int weeks;
  final int days;

  const PregnancyAge({required this.weeks, required this.days});

  @override
  String toString() => '$weeks weeks, $days days';
}

class PregnancyCalculator {
  /// Calculates gestational age (weeks and remaining days) from last period start date
  static PregnancyAge getGestationalAge(DateTime lastPeriodStart, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    final cleanStart = DateTime(lastPeriodStart.year, lastPeriodStart.month, lastPeriodStart.day);

    final totalDays = cleanToday.difference(cleanStart).inDays.clamp(0, 310);
    final weeks = totalDays ~/ 7;
    final days = totalDays % 7;

    return PregnancyAge(weeks: weeks, days: days);
  }

  /// Calculates estimated due date (280 days after last period start)
  static DateTime getEstimatedDueDate(DateTime lastPeriodStart) {
    final cleanStart = DateTime(lastPeriodStart.year, lastPeriodStart.month, lastPeriodStart.day);
    return cleanStart.add(const Duration(days: 280));
  }

  /// Calculates days remaining until due date
  static int getDaysUntilDueDate(DateTime dueDate, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    final cleanDue = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return cleanDue.difference(cleanToday).inDays.clamp(0, 280);
  }

  /// Returns trimester string for a given gestational week
  static String getTrimester(int week) {
    if (week <= 13) {
      return '1st Trimester';
    } else if (week <= 27) {
      return '2nd Trimester';
    } else {
      return '3rd Trimester';
    }
  }

  /// Returns weekly baby fruit/size comparison
  static String getBabySizeComparison(int week) {
    if (week < 4) return 'Poppy Seed 🌰';
    if (week < 8) return 'Raspberry 🫐';
    if (week < 12) return 'Lime 🍋';
    if (week < 16) return 'Avocado 🥑';
    if (week < 20) return 'Banana 🍌';
    if (week < 24) return 'Cantaloupe 🍈';
    if (week < 28) return 'Eggplant 🍆';
    if (week < 32) return 'Pineapple 🍍';
    if (week < 36) return 'Honeydew 🍈';
    return 'Watermelon 🍉';
  }

  /// Returns medical & lifestyle pregnancy guidance by gestational week
  static String getPregnancyAdvice(int week) {
    if (week <= 13) {
      return '1st Trimester Focus: Prioritize daily prenatal vitamins with 400mcg+ folic acid. Stay well-hydrated, rest during peak fatigue, and eat small frequent meals if experiencing morning sickness.';
    } else if (week <= 27) {
      return '2nd Trimester Focus: Energy levels typically rise! Practice gentle pelvic floor exercises, include iron and calcium rich foods, and sleep on your left side to optimize placental blood circulation.';
    } else {
      return '3rd Trimester Focus: Monitor daily baby kicks and movements. Finalize your birth plan and hospital bag, stay gently active, and practice slow diaphragmatic breathing for birth preparation.';
    }
  }

  /// Calculates LMP anchor from an ultrasound / doctor-estimated Due Date
  static DateTime calculateLmpFromDueDate(DateTime dueDate) {
    final cleanDue = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return cleanDue.subtract(const Duration(days: 280));
  }

  /// Calculates LMP anchor from a known Conception Date
  static DateTime calculateLmpFromConception(DateTime conceptionDate) {
    final cleanConception = DateTime(conceptionDate.year, conceptionDate.month, conceptionDate.day);
    return cleanConception.subtract(const Duration(days: 14));
  }
}
