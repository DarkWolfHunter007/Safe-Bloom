import 'dart:convert';
import 'package:safe_bloom/core/utils/cycle_group_utils.dart';
import 'package:safe_bloom/core/utils/safe_bloom_date_utils.dart';
import '../datasources/database_helper.dart';
import '../../domain/entities/period_entry.dart';
import '../../domain/entities/symptom_entry.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/services/cycle_calculator.dart';

class TrackingRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // --- Profile Management ---

  Future<UserProfile> getUserProfile() async {
    UserProfile? profile = await _dbHelper.getUserProfile();
    if (profile == null) {
      final defaultStart = DateTime.now().subtract(const Duration(days: 12));
      return UserProfile(
        lastPeriodStart: defaultStart,
        avgCycleLength: 28,
        avgPeriodLength: 5,
        isCloudBackupEnabled: true,
      );
    }
    return profile;
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    await _dbHelper.saveUserProfile(profile);
  }

  // --- Period Tracking ---

  Future<List<PeriodEntry>> getPeriodEntries() async {
    return await _dbHelper.getAllPeriodEntries();
  }

  Future<void> addPeriodEntry(PeriodEntry entry) async {
    await _dbHelper.insertPeriodEntry(entry);
    await _recalculateProfileAverages();
  }

  Future<void> updatePeriodEntry(PeriodEntry entry) async {
    await _dbHelper.updatePeriodEntry(entry);
    await _recalculateProfileAverages();
  }

  Future<void> deletePeriodEntry(String id) async {
    await _dbHelper.deletePeriodEntry(id);
    await _recalculateProfileAverages();
  }

  /// Ends current period by removing period entries in the latest cycle group that occur after endDate.
  Future<void> endCurrentPeriod(DateTime endDate) async {
    final cleanEnd = SafeBloomDateUtils.dateOnly(endDate);
    final allEntries = await _dbHelper.getAllPeriodEntries();
    if (allEntries.isEmpty) return;

    final cycles = CycleGroupUtils.groupIntoCycles(allEntries);
    if (cycles.isEmpty) return;

    final latestCycle = cycles.last;
    for (final entry in latestCycle) {
      final entryDate = SafeBloomDateUtils.dateOnly(entry.timestamp);
      if (entryDate.isAfter(cleanEnd)) {
        await _dbHelper.deletePeriodEntry(entry.id);
      }
    }
    await _recalculateProfileAverages();
  }

  Future<void> _recalculateProfileAverages() async {
    final allEntries = await _dbHelper.getAllPeriodEntries();
    final averages = CycleCalculator.calculateAveragesFromEntries(allEntries);
    final currentProfile = await getUserProfile();

    DateTime latestStart;
    if (allEntries.isNotEmpty) {
      final cycles = CycleGroupUtils.groupIntoCycles(allEntries);
      if (cycles.isNotEmpty) {
        latestStart = cycles.last.first.timestamp;
      } else {
        latestStart = allEntries.last.timestamp;
      }
    } else {
      latestStart = currentProfile.initialLastPeriodStart;
    }

    final updatedProfile = UserProfile(
      lastPeriodStart: latestStart,
      initialLastPeriodStart: currentProfile.initialLastPeriodStart,
      avgCycleLength: averages['avgCycleLength']!,
      avgPeriodLength: averages['avgPeriodLength']!,
      isCloudBackupEnabled: currentProfile.isCloudBackupEnabled,
      preferredGoal: currentProfile.preferredGoal,
      createdAt: currentProfile.createdAt,
    );
    await _dbHelper.saveUserProfile(updatedProfile);
  }

  // --- Symptom Tracking ---

  Future<List<SymptomEntry>> getSymptomsForDate(DateTime date) async {
    return await _dbHelper.getSymptomEntriesByDate(date);
  }

  Future<List<SymptomEntry>> getAllSymptoms() async {
    return await _dbHelper.getAllSymptomEntries();
  }

  Future<void> addSymptomEntry(SymptomEntry entry) async {
    await _dbHelper.insertSymptomEntry(entry);
  }

  Future<void> updateSymptomEntry(SymptomEntry entry) async {
    await _dbHelper.updateSymptomEntry(entry);
  }

  Future<void> deleteSymptomEntry(String id) async {
    await _dbHelper.deleteSymptomEntry(id);
  }

  // --- Water Intake ---

  Future<int> getWaterIntake(DateTime date) async {
    return await _dbHelper.getWaterIntakeForDate(date);
  }

  Future<void> setWaterIntake(DateTime date, int waterMl) async {
    await _dbHelper.setWaterIntakeForDate(date, waterMl);
  }

  // --- Backup & Data Export ---

  Future<String> exportUserDataJson() async {
    final profile = await getUserProfile();
    final periods = await getPeriodEntries();
    final symptoms = await getAllSymptoms();

    final data = {
      'profile': profile.toMap(),
      'period_entries': periods.map((e) => e.toMap()).toList(),
      'symptom_entries': symptoms.map((e) => e.toMap()).toList(),
      'exported_at': DateTime.now().toIso8601String(),
    };

    return jsonEncode(data);
  }

  Future<Map<String, int>> importUserDataJson(String jsonStr) async {
    final Map<String, dynamic> data = jsonDecode(jsonStr);

    int periodsImported = 0;
    int symptomsImported = 0;

    if (data.containsKey('profile') && data['profile'] != null) {
      final profileMap = Map<String, dynamic>.from(data['profile']);
      final profile = UserProfile.fromMap(profileMap);
      await saveUserProfile(profile);
    }

    if (data.containsKey('period_entries') && data['period_entries'] is List) {
      final List periodList = data['period_entries'];
      for (final item in periodList) {
        if (item is Map) {
          final entry = PeriodEntry.fromMap(Map<String, dynamic>.from(item));
          await _dbHelper.insertPeriodEntry(entry);
          periodsImported++;
        }
      }
    }

    if (data.containsKey('symptom_entries') && data['symptom_entries'] is List) {
      final List symptomList = data['symptom_entries'];
      for (final item in symptomList) {
        if (item is Map) {
          final entry = SymptomEntry.fromMap(Map<String, dynamic>.from(item));
          await _dbHelper.insertSymptomEntry(entry);
          symptomsImported++;
        }
      }
    }

    await _recalculateProfileAverages();

    return {
      'periods': periodsImported,
      'symptoms': symptomsImported,
    };
  }

  // --- Zero Knowledge Wipe ---

  Future<void> wipeAllUserData() async {
    await _dbHelper.wipeAllData();
  }
}
