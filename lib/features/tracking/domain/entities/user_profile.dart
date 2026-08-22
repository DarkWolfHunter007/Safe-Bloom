class UserProfile {
  final DateTime lastPeriodStart;
  final DateTime initialLastPeriodStart;
  final int avgCycleLength;
  final int avgPeriodLength;
  final bool isCloudBackupEnabled;
  final bool isPregnancyModeEnabled;
  final String? preferredGoal;
  final DateTime createdAt;

  UserProfile({
    required this.lastPeriodStart,
    DateTime? initialLastPeriodStart,
    this.avgCycleLength = 28,
    this.avgPeriodLength = 5,
    this.isCloudBackupEnabled = true,
    bool? isPregnancyModeEnabled,
    this.preferredGoal,
    DateTime? createdAt,
  })  : initialLastPeriodStart = initialLastPeriodStart ?? lastPeriodStart,
        isPregnancyModeEnabled = isPregnancyModeEnabled ??
            (preferredGoal == 'pregnancy' ||
                preferredGoal == 'track_pregnancy' ||
                preferredGoal == '🤰 Track Pregnancy' ||
                preferredGoal == 'Track Pregnancy' ||
                preferredGoal == 'Pregnancy'),
        createdAt = createdAt ?? DateTime.now();

  UserProfile copyWith({
    DateTime? lastPeriodStart,
    DateTime? initialLastPeriodStart,
    int? avgCycleLength,
    int? avgPeriodLength,
    bool? isCloudBackupEnabled,
    bool? isPregnancyModeEnabled,
    String? preferredGoal,
    DateTime? createdAt,
  }) {
    final effectiveGoal = preferredGoal ?? this.preferredGoal;
    final isNewPregGoal = effectiveGoal == 'pregnancy' ||
        effectiveGoal == 'track_pregnancy' ||
        effectiveGoal == '🤰 Track Pregnancy' ||
        effectiveGoal == 'Track Pregnancy' ||
        effectiveGoal == 'Pregnancy';

    return UserProfile(
      lastPeriodStart: lastPeriodStart ?? this.lastPeriodStart,
      initialLastPeriodStart: initialLastPeriodStart ?? this.initialLastPeriodStart,
      avgCycleLength: avgCycleLength ?? this.avgCycleLength,
      avgPeriodLength: avgPeriodLength ?? this.avgPeriodLength,
      isCloudBackupEnabled: isCloudBackupEnabled ?? this.isCloudBackupEnabled,
      isPregnancyModeEnabled: isPregnancyModeEnabled ??
          (isNewPregGoal ? true : this.isPregnancyModeEnabled),
      preferredGoal: effectiveGoal,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'last_period_start': lastPeriodStart.toIso8601String(),
      'initial_last_period_start': initialLastPeriodStart.toIso8601String(),
      'avg_cycle_length': avgCycleLength,
      'avg_period_length': avgPeriodLength,
      'is_cloud_backup_enabled': isCloudBackupEnabled ? 1 : 0,
      'is_pregnancy_mode_enabled': isPregnancyModeEnabled ? 1 : 0,
      'preferred_goal': preferredGoal,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final goal = map['preferred_goal'] as String?;
    final defaultPreg = goal == 'pregnancy' ||
        goal == 'track_pregnancy' ||
        goal == '🤰 Track Pregnancy' ||
        goal == 'Track Pregnancy' ||
        goal == 'Pregnancy';
    return UserProfile(
      lastPeriodStart: DateTime.parse(map['last_period_start']),
      initialLastPeriodStart: map['initial_last_period_start'] != null
          ? DateTime.parse(map['initial_last_period_start'])
          : DateTime.parse(map['last_period_start']),
      avgCycleLength: map['avg_cycle_length'],
      avgPeriodLength: map['avg_period_length'],
      isCloudBackupEnabled: (map['is_cloud_backup_enabled'] ?? 1) == 1,
      isPregnancyModeEnabled: map['is_pregnancy_mode_enabled'] != null
          ? (map['is_pregnancy_mode_enabled'] == 1)
          : defaultPreg,
      preferredGoal: goal,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

enum AppMode {
  trackCycle,
  ttc,
  pregnancy,
}

extension UserProfileAppMode on UserProfile {
  AppMode get appMode {
    if (preferredGoal == null) return AppMode.trackCycle;
    switch (preferredGoal!.trim()) {
      case 'trackCycle':
      case 'track_cycle':
      case '🌸 Track Cycle & Symptoms':
      case 'Track Cycle & Symptoms':
      case 'Track Cycle':
      case 'Track Period & Ovulation':
      case 'Track Period':
      case '🔒 Private & Anonymous Health Journal':
      case '⚡ Manage PMS & Energy Levels':
        return AppMode.trackCycle;
      case 'ttc':
      case 'get_pregnant':
      case '👶 Conceive / Track Ovulation':
      case 'Conceive / Track Ovulation':
      case 'Conceive':
      case 'Try to Conceive (TTC)':
      case 'Try to Conceive':
      case 'TTC (Conception)':
      case 'TTC':
        return AppMode.ttc;
      case 'pregnancy':
      case 'track_pregnancy':
      case '🤰 Track Pregnancy':
      case 'Track Pregnancy':
      case 'Pregnancy':
        return isPregnancyModeEnabled ? AppMode.pregnancy : AppMode.trackCycle;
      default:
        return AppMode.trackCycle;
    }
  }
}

