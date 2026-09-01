import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:safe_bloom/core/services/backup_crypto_service.dart';
import 'package:safe_bloom/core/services/local_notification_service.dart';
import 'package:safe_bloom/core/services/secure_storage_service.dart';
import 'package:safe_bloom/core/services/vault_file_service.dart';
import 'package:safe_bloom/core/utils/cycle_group_utils.dart';
import 'package:safe_bloom/core/utils/safe_bloom_date_utils.dart';
import '../datasources/database_helper.dart';
import '../../domain/entities/period_entry.dart';
import '../../domain/entities/symptom_entry.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/services/cycle_calculator.dart';

class TrackingRepository {
  // Singleton: prevents multiple instances from desynchronising state.
  static final TrackingRepository instance = TrackingRepository._();
  TrackingRepository._();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  // Shared secure storage instance — configured with hardware-isolated options.
  final FlutterSecureStorage _secureStorage = SafeBloomSecureStorage.instance;

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
    await LocalNotificationService.instance.rescheduleWithLatestData(profile);
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
    final currentProfile = await getUserProfile();

    if (allEntries.isEmpty) {
      // No logged entries exist — revert lastPeriodStart back to initial baseline setup date!
      if (currentProfile.lastPeriodStart != currentProfile.initialLastPeriodStart) {
        final revertedProfile = currentProfile.copyWith(
          lastPeriodStart: currentProfile.initialLastPeriodStart,
        );
        await _dbHelper.saveUserProfile(revertedProfile);
        await LocalNotificationService.instance.rescheduleWithLatestData(revertedProfile);
      }
      return;
    }

    // groupIntoCycles only returns groups with ≥1 active-flow entry (light/medium/heavy).
    // Pure spotting groups are excluded from the result automatically.
    final genuineCycles = CycleGroupUtils.groupIntoCycles(allEntries);

    if (genuineCycles.isEmpty) {
      // Only isolated spotting entries exist. Revert to initialLastPeriodStart as genuine cycle anchor.
      if (currentProfile.lastPeriodStart != currentProfile.initialLastPeriodStart) {
        final revertedProfile = currentProfile.copyWith(
          lastPeriodStart: currentProfile.initialLastPeriodStart,
        );
        await _dbHelper.saveUserProfile(revertedProfile);
        await LocalNotificationService.instance.rescheduleWithLatestData(revertedProfile);
      }
      return;
    }

    // calculateAveragesFromEntries calls groupIntoCycles internally — passing all entries
    // is correct; spotting-only groups are excluded inside.
    final averages = CycleCalculator.calculateAveragesFromEntries(
      allEntries,
      fallbackCycleLength: currentProfile.avgCycleLength,
      fallbackPeriodLength: currentProfile.avgPeriodLength,
    );

    // Cycle anchor = first ACTIVE-FLOW day of the latest genuine cycle.
    // Leading spotting entries do NOT become Cycle Day 1.
    final DateTime latestStart = CycleGroupUtils.getCycleStartDate(genuineCycles.last);

    final updatedProfile = currentProfile.copyWith(
      lastPeriodStart: latestStart,
      avgCycleLength: averages['avgCycleLength'],
      avgPeriodLength: averages['avgPeriodLength'],
    );
    await _dbHelper.saveUserProfile(updatedProfile);
    await LocalNotificationService.instance.rescheduleWithLatestData(updatedProfile);
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
      'version': 1,
      'profile': profile.toMap(),
      'period_entries': periods.map((e) => e.toMap()).toList(),
      'symptom_entries': symptoms.map((e) => e.toMap()).toList(),
      'exported_at': DateTime.now().toUtc().toIso8601String(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Exports an authenticated, password-encrypted backup vault JSON string.
  Future<String> exportEncryptedVault({required String passphrase}) async {
    final plaintextJson = await exportUserDataJson();
    return BackupCryptoService.encryptVault(
      plaintextJson: plaintextJson,
      passphrase: passphrase,
    );
  }

  /// Exports an authenticated, password-encrypted .safebloom vault file.
  Future<File> exportEncryptedVaultFile({
    required String passphrase,
    Directory? targetDir,
    String? customFileName,
  }) async {
    final encryptedVault = await exportEncryptedVault(passphrase: passphrase);
    return await VaultFileService.createVaultFile(
      vaultContent: encryptedVault,
      directory: targetDir,
      customFileName: customFileName,
    );
  }

  /// Atomically imports unencrypted JSON data in a single ACID transaction after strict schema validation.
  /// If any entry is invalid or parsing fails, the database is restored untouched.
  Future<Map<String, int>> importUserDataJson(String jsonStr, {bool clearExisting = true}) async {
    final payload = BackupCryptoService.validateAndParseDecryptedPayload(jsonStr);

    // Execute in a single atomic ACID transaction
    await _dbHelper.executeAtomicImport(
      profile: payload.profile,
      periodEntries: payload.periodEntries,
      symptomEntries: payload.symptomEntries,
      clearExisting: clearExisting,
    );

    await _recalculateProfileAverages();

    return {
      'periods': payload.periodEntries.length,
      'symptoms': payload.symptomEntries.length,
    };
  }

  /// Decrypts, verifies MAC integrity, validates schema, and atomically imports an encrypted vault.
  /// If any cryptographic or schema check fails, the existing database is left 100% untouched.
  Future<Map<String, int>> importEncryptedVault({
    required String vaultJsonString,
    required String passphrase,
    bool clearExisting = true,
  }) async {
    final decryptedJson = BackupCryptoService.decryptVault(
      vaultJsonString: vaultJsonString,
      passphrase: passphrase,
    );
    return importUserDataJson(decryptedJson, clearExisting: clearExisting);
  }

  /// Reads an encrypted vault file from disk, decrypts, validates, and atomically restores it.
  Future<Map<String, int>> importEncryptedVaultFile({
    required File file,
    required String passphrase,
    bool clearExisting = true,
  }) async {
    try {
      final vaultJsonString = await VaultFileService.readVaultFile(file);
      return await importEncryptedVault(
        vaultJsonString: vaultJsonString,
        passphrase: passphrase,
        clearExisting: clearExisting,
      );
    } finally {
      await VaultFileService.cleanTemporaryVaultFiles(file);
    }
  }

  /// Safely recovers from database corruption by decrypting a backup vault and
  /// recreating the database with the restored payload.
  /// If the password is wrong or the vault is corrupted, this throws WITHOUT touching
  /// the corrupted database file on disk.
  Future<Map<String, int>> recoverAndRestoreFromEncryptedVault({
    required String vaultJsonString,
    required String passphrase,
  }) async {
    final decryptedJson = BackupCryptoService.decryptVault(
      vaultJsonString: vaultJsonString,
      passphrase: passphrase,
    );
    return recoverAndRestoreFromJson(decryptedJson);
  }

  /// Safely recovers from database corruption by reading an encrypted vault file from disk,
  /// decrypting it with password, validating schema, and recreating the database.
  Future<Map<String, int>> recoverAndRestoreFromEncryptedVaultFile({
    required File file,
    required String passphrase,
  }) async {
    try {
      final vaultJsonString = await VaultFileService.readVaultFile(file);
      return await recoverAndRestoreFromEncryptedVault(
        vaultJsonString: vaultJsonString,
        passphrase: passphrase,
      );
    } finally {
      await VaultFileService.cleanTemporaryVaultFiles(file);
    }
  }

  /// Recreates the database and imports valid JSON data.
  /// Validates all entries BEFORE replacing the database file on disk.
  Future<Map<String, int>> recoverAndRestoreFromJson(String jsonStr) async {
    final payload = BackupCryptoService.validateAndParseDecryptedPayload(jsonStr);

    await _dbHelper.resetAndRecreateDatabase(
      profile: payload.profile,
      periodEntries: payload.periodEntries,
      symptomEntries: payload.symptomEntries,
    );

    await _recalculateProfileAverages();

    return {
      'periods': payload.periodEntries.length,
      'symptoms': payload.symptomEntries.length,
    };
  }

  // --- Zero Knowledge Wipe ---

  /// Wipes all user data including the DB key, encrypted databases, journal/WAL files,
  /// notification alarms, clipboard contents, and all app-level secure preferences.
  /// Intentional full zero-knowledge wipe — the app will restart as if fresh.
  Future<void> wipeAllUserData() async {
    try {
      await Clipboard.setData(const ClipboardData(text: ''));
    } catch (_) {}
    await LocalNotificationService.instance.cancelAll();
    await _dbHelper.wipeAllData();
    await _secureStorage.deleteAll();
  }
}


