class UserProfile {
  final DateTime lastPeriodStart;
  final int avgCycleLength;
  final int avgPeriodLength;
  final bool isCloudBackupEnabled;
  final DateTime createdAt;

  UserProfile({
    required this.lastPeriodStart,
    this.avgCycleLength = 28,
    this.avgPeriodLength = 5,
    this.isCloudBackupEnabled = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'last_period_start': lastPeriodStart.toIso8601String(),
      'avg_cycle_length': avgCycleLength,
      'avg_period_length': avgPeriodLength,
      'is_cloud_backup_enabled': isCloudBackupEnabled ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      lastPeriodStart: DateTime.parse(map['last_period_start']),
      avgCycleLength: map['avg_cycle_length'],
      avgPeriodLength: map['avg_period_length'],
      isCloudBackupEnabled: map['is_cloud_backup_enabled'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
