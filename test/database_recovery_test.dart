import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safe_bloom/core/services/backup_crypto_service.dart';
import 'package:safe_bloom/features/tracking/data/datasources/database_helper.dart';
import 'package:safe_bloom/features/tracking/data/repositories/tracking_repository.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/symptom_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const MethodChannel secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const MethodChannel notificationsChannel =
      MethodChannel('dexterous.com/flutter/local_notifications');
  final Map<String, String> mockStorage = <String, String>{};

  setUp(() async {
    mockStorage.clear();

    await DatabaseHelper.instance.resetForTesting();
    try {
      final dbPath = await databaseFactoryFfi.getDatabasesPath();
      for (final name in [
        'test1_valid.db',
        'test2_corrupt.db',
        'test3_missing_key.db',
        'test4_wrong_key.db',
        'test5_restore.db',
        'test6_purge.db',
        'safebloom_encrypted.db',
        'safebloom_recovery_isolated.db'
      ]) {
        final path = p.join(dbPath, name);
        try {
          final f = File(path);
          if (f.existsSync()) f.deleteSync();
          for (final ext in ['-wal', '-shm', '-journal']) {
            final jf = File('$path$ext');
            if (jf.existsSync()) jf.deleteSync();
          }
        } catch (_) {}
      }
    } catch (_) {}

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (MethodCall methodCall) async {
      final Map<dynamic, dynamic>? args =
          methodCall.arguments as Map<dynamic, dynamic>?;
      final String? key = args?['key'] as String?;
      final String? value = args?['value'] as String?;

      switch (methodCall.method) {
        case 'write':
          if (key != null && value != null) {
            mockStorage[key] = value;
          }
          return null;
        case 'read':
          return mockStorage[key];
        case 'delete':
          if (key != null) {
            mockStorage.remove(key);
          }
          return null;
        case 'deleteAll':
          mockStorage.clear();
          return null;
        case 'readAll':
          return mockStorage;
        default:
          return null;
      }
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (MethodCall methodCall) async {
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);

    try {
      await DatabaseHelper.instance.resetForTesting();
      final dbPath = await databaseFactoryFfi.getDatabasesPath();
      for (final name in [
        'test1_valid.db',
        'test2_corrupt.db',
        'test3_missing_key.db',
        'test4_wrong_key.db',
        'test5_restore.db',
        'test6_purge.db',
        'safebloom_encrypted.db',
        'safebloom_recovery_isolated.db'
      ]) {
        final path = p.join(dbPath, name);
        try {
          final f = File(path);
          if (f.existsSync()) f.deleteSync();
          for (final ext in ['-wal', '-shm', '-journal']) {
            final jf = File('$path$ext');
            if (jf.existsSync()) jf.deleteSync();
          }
        } catch (_) {}
      }
    } catch (_) {}
  });

  group('Database Recovery State & Integrity Tests', () {
    test('1. Valid Database: normal startup creates DB and loads profile without error', () async {
      const dbName = 'test1_valid.db';
      await DatabaseHelper.instance.resetForTesting(databaseFactoryFfi, dbName);

      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;
      expect(db.isOpen, isTrue);

      final profile = UserProfile(
        lastPeriodStart: DateTime(2026, 8, 1),
        avgCycleLength: 28,
        avgPeriodLength: 5,
        isCloudBackupEnabled: true,
      );
      await dbHelper.saveUserProfile(profile);

      final loaded = await dbHelper.getUserProfile();
      expect(loaded, isNotNull);
      expect(loaded!.avgCycleLength, equals(28));
      expect(mockStorage.containsKey('safebloom_db_key'), isTrue);

      await db.close();
    });

    test('2. Corrupted Database: corrupted file triggers DatabaseCorruptedOrInvalidKeyException and preserves file', () async {
      const dbName = 'test2_corrupt.db';
      await DatabaseHelper.instance.resetForTesting(databaseFactoryFfi, dbName);
      final dbPath = await databaseFactoryFfi.getDatabasesPath();
      final path = p.join(dbPath, dbName);

      // Simulate a pre-existing corrupted file (1024 bytes of malformed binary)
      final corruptBytes = List<int>.filled(1024, 0x55);
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(corruptBytes, flush: true);
      mockStorage['safebloom_db_key'] = 'some_valid_looking_key_1234567890';

      final dbHelper = DatabaseHelper.instance;
      await expectLater(
        () => dbHelper.database,
        throwsA(isA<DatabaseCorruptedOrInvalidKeyException>()),
      );

      // Verify the corrupted database file was NOT deleted or overwritten
      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync(), equals(corruptBytes));
    });

    test('3. Missing Key: existing DB file with missing Keystore key throws DatabaseKeyMissingException and does NOT generate key', () async {
      const dbName = 'test3_missing_key.db';
      await DatabaseHelper.instance.resetForTesting(databaseFactoryFfi, dbName);
      final dbPath = await databaseFactoryFfi.getDatabasesPath();
      final path = p.join(dbPath, dbName);

      // File exists on disk
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('EXISTING_VALID_OR_PREVIOUS_DATABASE', flush: true);

      // Secure storage is EMPTY (e.g. Keystore wiped after OS reset or app data desync)
      mockStorage.remove('safebloom_db_key');

      final dbHelper = DatabaseHelper.instance;
      await expectLater(
        () => dbHelper.database,
        throwsA(isA<DatabaseKeyMissingException>()),
      );

      // Verify NO new key was generated over the existing database
      expect(mockStorage.containsKey('safebloom_db_key'), isFalse);
      expect(file.existsSync(), isTrue);
    });

    test('4. Wrong Key: database fails health check when invalid encryption key is supplied and preserves data', () async {
      const dbName = 'test4_wrong_key.db';
      await DatabaseHelper.instance.resetForTesting(databaseFactoryFfi, dbName);
      final dbPath = await databaseFactoryFfi.getDatabasesPath();
      final path = p.join(dbPath, dbName);

      // Corrupted / wrong key supplied
      final corruptBytes = List<int>.filled(1024, 0x55);
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(corruptBytes, flush: true);
      mockStorage['safebloom_db_key'] = 'wrong_mismatched_key_9999999999999999';

      final dbHelper = DatabaseHelper.instance;
      await expectLater(
        () => dbHelper.database,
        throwsA(isA<DatabaseCorruptedOrInvalidKeyException>()),
      );

      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync(), equals(corruptBytes));
    });

    test('5. Restore after Corruption: valid encrypted backup successfully restores database', () async {
      const dbName = 'test5_restore.db';
      await DatabaseHelper.instance.resetForTesting(databaseFactoryFfi, dbName);
      final dbPath = await databaseFactoryFfi.getDatabasesPath();
      final path = p.join(dbPath, dbName);

      // 1. Create a valid backup payload first
      final testProfile = UserProfile(
        lastPeriodStart: DateTime(2026, 7, 20),
        avgCycleLength: 30,
        avgPeriodLength: 6,
        isCloudBackupEnabled: true,
        preferredGoal: AppMode.ttc.name,
      );
      final testPeriod = PeriodEntry(
        id: 'p_restore_1',
        timestamp: DateTime(2026, 7, 20),
        flow: FlowLevel.heavy,
        notes: 'Restored period entry',
      );
      final testSymptom = SymptomEntry(
        id: 's_restore_1',
        timestamp: DateTime(2026, 7, 20),
        category: SymptomCategory.pain,
        type: 'Mild Cramps',
        intensity: 2,
      );

      final rawJson = jsonEncode({
        'version': 1,
        'profile': testProfile.toMap(),
        'period_entries': [testPeriod.toMap()],
        'symptom_entries': [testSymptom.toMap()],
      });

      const backupPass = 'SafeBloomSecretPassword2026!';
      final encryptedVault = BackupCryptoService.encryptVault(
        plaintextJson: rawJson,
        passphrase: backupPass,
      );

      // 2. Corrupt the database on disk
      final corruptBytes = List<int>.filled(1024, 0x55);
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(corruptBytes, flush: true);
      mockStorage['safebloom_db_key'] = 'some_valid_looking_key_1234567890';

      final dbHelper = DatabaseHelper.instance;
      // 3. Attempting to open fails with recovery exception
      await expectLater(
        () => dbHelper.database,
        throwsA(isA<DatabaseCorruptedOrInvalidKeyException>()),
      );

      // 4. Test wrong passphrase does NOT touch the database
      await expectLater(
        () => TrackingRepository.instance.recoverAndRestoreFromEncryptedVault(
          vaultJsonString: encryptedVault,
          passphrase: 'WrongPassword123!',
        ),
        throwsA(isA<InvalidBackupPasswordException>()),
      );
      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync(), equals(corruptBytes));

      // 5. Restore with correct passphrase
      final result = await TrackingRepository.instance.recoverAndRestoreFromEncryptedVault(
        vaultJsonString: encryptedVault,
        passphrase: backupPass,
      );

      expect(result['periods'], equals(1));
      expect(result['symptoms'], equals(1));

      // 6. Verify database is now healthy and readable
      final restoredProfile = await TrackingRepository.instance.getUserProfile();
      expect(restoredProfile.avgCycleLength, equals(30));
      expect(restoredProfile.preferredGoal, equals(AppMode.ttc.name));

      final restoredPeriods = await TrackingRepository.instance.getPeriodEntries();
      expect(restoredPeriods.length, equals(1));
      expect(restoredPeriods.first.id, equals('p_restore_1'));
      expect(restoredPeriods.first.notes, equals('Restored period entry'));

      await DatabaseHelper.instance.resetForTesting();
    });

    test('6. Explicit Purge after Corruption: user-confirmed purge completely wipes corrupted data and keys', () async {
      const dbName = 'test6_purge.db';
      await DatabaseHelper.instance.resetForTesting(databaseFactoryFfi, dbName);
      final dbPath = await databaseFactoryFfi.getDatabasesPath();
      final path = p.join(dbPath, dbName);

      // Corrupt database
      final corruptBytes = List<int>.filled(1024, 0x55);
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(corruptBytes, flush: true);
      mockStorage['safebloom_db_key'] = 'corrupt_key_xyz';

      // Execute explicit user wipe
      await TrackingRepository.instance.wipeAllUserData();

      // Verify files and storage are clean
      expect(mockStorage.isEmpty, isTrue);
      expect(file.existsSync(), isFalse);

      // Fresh startup should now create a new key and start onboarding state
      final freshDb = await DatabaseHelper.instance.database;
      expect(freshDb.isOpen, isTrue);
      expect(mockStorage.containsKey('safebloom_db_key'), isTrue);

      final profile = await DatabaseHelper.instance.getUserProfile();
      expect(profile, isNull); // Clean slate for OnboardingView

      await DatabaseHelper.instance.resetForTesting();
    });
  });
}
