class UserProfile {
  final DateTime lastPeriodStart;
  final DateTime initialLastPeriodStart;
  final int avgCycleLength;
  final int avgPeriodLength;
  final bool isCloudBackupEnabled;
  final String? preferredGoal;
  final DateTime createdAt;

  UserProfile({
    required this.lastPeriodStart,
    DateTime? initialLastPeriodStart,
    this.avgCycleLength = 28,
    this.avgPeriodLength = 5,
    this.isCloudBackupEnabled = true,
    this.preferredGoal,
    DateTime? createdAt,
  })  : initialLastPeriodStart = initialLastPeriodStart ?? lastPeriodStart,
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'last_period_start': lastPeriodStart.toIso8601String(),
      'initial_last_period_start': initialLastPeriodStart.toIso8601String(),
      'avg_cycle_length': avgCycleLength,
      'avg_period_length': avgPeriodLength,
      'is_cloud_backup_enabled': isCloudBackupEnabled ? 1 : 0,
      'preferred_goal': preferredGoal,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      lastPeriodStart: DateTime.parse(map['last_period_start']),
      initialLastPeriodStart: map['initial_last_period_start'] != null
          ? DateTime.parse(map['initial_last_period_start'])
          : DateTime.parse(map['last_period_start']),
      avgCycleLength: map['avg_cycle_length'],
      avgPeriodLength: map['avg_period_length'],
      isCloudBackupEnabled: (map['is_cloud_backup_enabled'] ?? 1) == 1,
      preferredGoal: map['preferred_goal'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
