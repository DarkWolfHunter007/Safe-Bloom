import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safe_bloom/core/services/backup_crypto_service.dart';
import 'package:safe_bloom/core/services/vault_file_service.dart';
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

  late Directory tempTestDir;

  setUp(() async {
    mockStorage.clear();
    tempTestDir = Directory.systemTemp.createTempSync('safebloom_vault_test_');

    await DatabaseHelper.instance.resetForTesting();
    try {
      final dbPath = await databaseFactoryFfi.getDatabasesPath();
      for (final name in [
        'vault_test.db',
        'vault_atomic_test.db',
        'safebloom_encrypted.db',
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
      if (tempTestDir.existsSync()) {
        tempTestDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Encrypted Vault File Export & Import Tests', () {
    const testPassword = 'StrongVaultPassphrase2026!';

    test('1. Export produces a valid, non-empty .safebloom file with correct filename format', () async {
      const dbName = 'vault_test.db';
      await DatabaseHelper.instance.resetForTesting(databaseFactoryFfi, dbName);

      final repo = TrackingRepository.instance;
      final initialProfile = UserProfile(
        lastPeriodStart: DateTime(2026, 8, 15),
        avgCycleLength: 29,
        avgPeriodLength: 5,
        preferredGoal: AppMode.trackCycle.name,
      );
      await repo.saveUserProfile(initialProfile);

      final vaultFile = await repo.exportEncryptedVaultFile(
        passphrase: testPassword,
        targetDir: tempTestDir,
      );

      expect(vaultFile.existsSync(), isTrue);
      expect(vaultFile.path.endsWith('.safebloom'), isTrue);
      expect(p.basename(vaultFile.path), startsWith('SafeBloom-Vault-'));
      expect(await vaultFile.length(), greaterThan(0));
    });

    test('2. Exported file contains standard SafeBloomVault envelope and ZERO plaintext sensitive data', () async {
      const dbName = 'vault_test.db';
      await DatabaseHelper.instance.resetForTesting(databaseFactoryFfi, dbName);

      final repo = TrackingRepository.instance;
      const sensitiveNote = 'SUPER_SECRET_SENSITIVE_PERIOD_SYMPTOM_DIARY_ENTRY';
      final initialProfile = UserProfile(
        lastPeriodStart: DateTime(2026, 8, 15),
        avgCycleLength: 29,
        avgPeriodLength: 5,
      );
      await repo.saveUserProfile(initialProfile);
      await repo.addPeriodEntry(PeriodEntry(
        id: 'p_secret_1',
        timestamp: DateTime(2026, 8, 15),
        flow: FlowLevel.heavy,
        notes: sensitiveNote,
      ));
      await repo.addSymptomEntry(SymptomEntry(
        id: 's_secret_1',
        timestamp: DateTime(2026, 8, 15),
        category: SymptomCategory.pain,
        type: 'Severe Pelvic Pain',
        intensity: 5,
        notes: sensitiveNote,
      ));

      final vaultFile = await repo.exportEncryptedVaultFile(
        passphrase: testPassword,
        targetDir: tempTestDir,
      );

      final fileContent = await vaultFile.readAsString();

      // Check envelope format
      final Map<String, dynamic> envelope = jsonDecode(fileContent);
      expect(envelope['format'], equals('SafeBloomVault'));
      expect(envelope['version'], equals(1));
      expect(envelope['algorithm'], equals('AES-256-CTR-HMAC-SHA256'));
      expect(envelope['kdf'], equals('PBKDF2-HMAC-SHA256'));
      expect(envelope.containsKey('salt'), isTrue);
      expect(envelope.containsKey('iv'), isTrue);
      expect(envelope.containsKey('ciphertext'), isTrue);
      expect(envelope.containsKey('mac'), isTrue);

      // Verify ZERO plaintext sensitive health details appear anywhere in the file
      expect(fileContent, isNot(contains(sensitiveNote)));
      expect(fileContent, isNot(contains('Severe Pelvic Pain')));
      expect(fileContent, isNot(contains('p_secret_1')));
      expect(fileContent, isNot(contains('s_secret_1')));
      expect(fileContent, isNot(contains('2026-08-15')));
      expect(fileContent, isNot(contains(testPassword)));
    });

    test('3. Round-Trip: Vault A -> Export to File -> Import from File -> Vault B (semantic equivalence)', () async {
      const dbName = 'vault_test.db';
      await DatabaseHelper.instance.resetForTesting(databaseFactoryFfi, dbName);

      final repo = TrackingRepository.instance;
      final profileA = UserProfile(
        lastPeriodStart: DateTime(2026, 7, 10),
        initialLastPeriodStart: DateTime(2026, 6, 12),
        avgCycleLength: 31,
        avgPeriodLength: 6,
        preferredGoal: AppMode.ttc.name,
      );
      await repo.saveUserProfile(profileA);

      final periodA1 = PeriodEntry(
        id: 'p_rt_1',
        timestamp: DateTime(2026, 7, 10),
        flow: FlowLevel.heavy,
        notes: 'Round trip period 1',
      );
      final periodA2 = PeriodEntry(
        id: 'p_rt_2',
        timestamp: DateTime(2026, 7, 11),
        flow: FlowLevel.medium,
        notes: 'Round trip period 2',
      );
      await repo.addPeriodEntry(periodA1);
      await repo.addPeriodEntry(periodA2);

      final symptomA1 = SymptomEntry(
        id: 's_rt_1',
        timestamp: DateTime(2026, 7, 10),
        category: SymptomCategory.mood,
        type: 'Anxious',
        intensity: 4,
        notes: 'Work stress',
      );
      await repo.addSymptomEntry(symptomA1);

      // Capture Vault A state before export
      final profileBeforeExport = await repo.getUserProfile();
      final periodsBeforeExport = await repo.getPeriodEntries();
      final symptomsBeforeExport = await repo.getAllSymptoms();

      // Export to .safebloom file
      final vaultFile = await repo.exportEncryptedVaultFile(
        passphrase: testPassword,
        targetDir: tempTestDir,
      );

      // Clear DB / reset to fresh state
      await DatabaseHelper.instance.executeAtomicImport(
        profile: UserProfile(lastPeriodStart: DateTime(2025, 1, 1), avgCycleLength: 28, avgPeriodLength: 5),
        clearExisting: true,
      );

      // Import from .safebloom file
      final stats = await repo.importEncryptedVaultFile(
        file: vaultFile,
        passphrase: testPassword,
        clearExisting: true,
      );

      expect(stats['periods'], equals(periodsBeforeExport.length));
      expect(stats['symptoms'], equals(symptomsBeforeExport.length));

      // Verify Vault B is semantically equivalent to Vault A
      final profileB = await repo.getUserProfile();
      expect(profileB.avgCycleLength, equals(profileBeforeExport.avgCycleLength));
      expect(profileB.avgPeriodLength, equals(profileBeforeExport.avgPeriodLength));
      expect(profileB.preferredGoal, equals(profileBeforeExport.preferredGoal));
      expect(profileB.lastPeriodStart.year, equals(profileBeforeExport.lastPeriodStart.year));
      expect(profileB.lastPeriodStart.month, equals(profileBeforeExport.lastPeriodStart.month));
      expect(profileB.lastPeriodStart.day, equals(profileBeforeExport.lastPeriodStart.day));

      final periodsB = await repo.getPeriodEntries();
      expect(periodsB.length, equals(2));
      expect(periodsB.any((p) => p.id == 'p_rt_1' && p.flow == FlowLevel.heavy), isTrue);
      expect(periodsB.any((p) => p.id == 'p_rt_2' && p.flow == FlowLevel.medium), isTrue);

      final symptomsB = await repo.getAllSymptoms();
      expect(symptomsB.length, equals(1));
      expect(symptomsB.first.id, equals('s_rt_1'));
      expect(symptomsB.first.type, equals('Anxious'));
      expect(symptomsB.first.intensity, equals(4));
    });

    test('4. Wrong password fails with InvalidBackupPasswordException without decrypting or changing vault', () async {
      const dbName = 'vault_atomic_test.db';
      await DatabaseHelper.instance.resetForTesting(databaseFactoryFfi, dbName);

      final repo = TrackingRepository.instance;
      final initialProfile = UserProfile(
        lastPeriodStart: DateTime(2026, 8, 1),
        avgCycleLength: 28,
        avgPeriodLength: 5,
      );
      await repo.saveUserProfile(initialProfile);

      final vaultFile = await repo.exportEncryptedVaultFile(
        passphrase: testPassword,
        targetDir: tempTestDir,
      );

      // Attempt restore with wrong password
      await expectLater(
        () => repo.importEncryptedVaultFile(
          file: vaultFile,
          passphrase: 'IncorrectPassword123!',
          clearExisting: true,
        ),
        throwsA(isA<InvalidBackupPasswordException>()),
      );

      // Verify original vault remains intact
      final currentProfile = await repo.getUserProfile();
      expect(currentProfile.avgCycleLength, equals(28));
      expect(currentProfile.lastPeriodStart.month, equals(8));
    });

    test('5. Tampered ciphertext fails authentication without modifying database', () async {
      const dbName = 'vault_atomic_test.db';
      await DatabaseHelper.instance.resetForTesting(databaseFactoryFfi, dbName);

      final repo = TrackingRepository.instance;
      final initialProfile = UserProfile(
        lastPeriodStart: DateTime(2026, 8, 1),
        avgCycleLength: 28,
        avgPeriodLength: 5,
      );
      await repo.saveUserProfile(initialProfile);

      final vaultFile = await repo.exportEncryptedVaultFile(
        passphrase: testPassword,
        targetDir: tempTestDir,
      );

      // Tamper one byte in ciphertext
      final Map<String, dynamic> envelope = jsonDecode(await vaultFile.readAsString());
      final Uint8List rawCipher = base64Decode(envelope['ciphertext']);
      rawCipher[rawCipher.length ~/ 2] ^= 0xAA;
      envelope['ciphertext'] = base64Encode(rawCipher);

      final tamperedFile = File(p.join(tempTestDir.path, 'tampered.safebloom'));
      await tamperedFile.writeAsString(jsonEncode(envelope));

      await expectLater(
        () => repo.importEncryptedVaultFile(
          file: tamperedFile,
          passphrase: testPassword,
          clearExisting: true,
        ),
        throwsA(isA<InvalidBackupPasswordException>()),
      );

      // Verify original vault remains intact
      final currentProfile = await repo.getUserProfile();
      expect(currentProfile.avgCycleLength, equals(28));
    });

    test('6. Truncated file fails validation without modifying database', () async {
      const dbName = 'vault_atomic_test.db';
      await DatabaseHelper.instance.resetForTesting(databaseFactoryFfi, dbName);

      final repo = TrackingRepository.instance;
      final initialProfile = UserProfile(
        lastPeriodStart: DateTime(2026, 8, 1),
        avgCycleLength: 28,
        avgPeriodLength: 5,
      );
      await repo.saveUserProfile(initialProfile);

      final vaultFile = await repo.exportEncryptedVaultFile(
        passphrase: testPassword,
        targetDir: tempTestDir,
      );

      final content = await vaultFile.readAsString();
      final truncatedContent = content.substring(0, content.length ~/ 2);
      final truncatedFile = File(p.join(tempTestDir.path, 'truncated.safebloom'));
      await truncatedFile.writeAsString(truncatedContent);

      await expectLater(
        () => repo.importEncryptedVaultFile(
          file: truncatedFile,
          passphrase: testPassword,
          clearExisting: true,
        ),
        throwsA(isA<MalformedBackupPayloadException>()),
      );

      final currentProfile = await repo.getUserProfile();
      expect(currentProfile.avgCycleLength, equals(28));
    });

    test('7. Empty file (0 bytes) is rejected safely', () async {
      final emptyFile = File(p.join(tempTestDir.path, 'empty.safebloom'));
      await emptyFile.writeAsString('');

      await expectLater(
        () => TrackingRepository.instance.importEncryptedVaultFile(
          file: emptyFile,
          passphrase: testPassword,
        ),
        throwsA(isA<MalformedBackupPayloadException>()),
      );
    });

    test('8. Unsupported future version is rejected safely', () async {
      final validVault = BackupCryptoService.encryptVault(
        plaintextJson: jsonEncode({
          'profile': {'last_period_start': '2026-08-01T00:00:00.000Z', 'avg_cycle_length': 28, 'avg_period_length': 5}
        }),
        passphrase: testPassword,
      );

      final Map<String, dynamic> envelope = jsonDecode(validVault);
      envelope['version'] = 999;
      envelope['safe_bloom_backup_version'] = 999;

      final futureVersionFile = File(p.join(tempTestDir.path, 'future_version.safebloom'));
      await futureVersionFile.writeAsString(jsonEncode(envelope));

      await expectLater(
        () => TrackingRepository.instance.importEncryptedVaultFile(
          file: futureVersionFile,
          passphrase: testPassword,
        ),
        throwsA(isA<UnsupportedVaultVersionException>()),
      );
    });

    test('9. Atomic Restore: Corrupted/invalid schema aborts transaction leaving existing vault untouched', () async {
      const dbName = 'vault_atomic_test.db';
      await DatabaseHelper.instance.resetForTesting(databaseFactoryFfi, dbName);

      final repo = TrackingRepository.instance;
      final originalProfile = UserProfile(
        lastPeriodStart: DateTime(2026, 8, 1),
        avgCycleLength: 27,
        avgPeriodLength: 4,
        preferredGoal: AppMode.ttc.name,
      );
      await repo.saveUserProfile(originalProfile);
      await repo.addPeriodEntry(PeriodEntry(
        id: 'p_original',
        timestamp: DateTime(2026, 8, 1),
        flow: FlowLevel.medium,
        notes: 'Original period',
      ));

      // Create an encrypted vault that has a malformed schema inside the decrypted JSON
      final malformedPayloadJson = jsonEncode({
        'profile': {
          'last_period_start': '2026-08-01T00:00:00.000Z',
          'avg_cycle_length': 999, // Impossible schema value
          'avg_period_length': 5,
        },
      });

      final malformedVault = BackupCryptoService.encryptVault(
        plaintextJson: malformedPayloadJson,
        passphrase: testPassword,
      );
      final malformedFile = File(p.join(tempTestDir.path, 'malformed_schema.safebloom'));
      await malformedFile.writeAsString(malformedVault);

      // Attempt to import the malformed schema
      await expectLater(
        () => repo.importEncryptedVaultFile(
          file: malformedFile,
          passphrase: testPassword,
          clearExisting: true,
        ),
        throwsA(isA<MalformedBackupPayloadException>()),
      );

      // Verify original vault was completely untouched
      final afterProfile = await repo.getUserProfile();
      expect(afterProfile.avgCycleLength, equals(27));
      expect(afterProfile.preferredGoal, equals(AppMode.ttc.name));

      final afterPeriods = await repo.getPeriodEntries();
      expect(afterPeriods.length, equals(1));
      expect(afterPeriods.first.id, equals('p_original'));
    });

    test('10. VaultFileService generates correct filename and validates file envelope safely', () async {
      final customDate = DateTime(2026, 12, 25);
      final filename = VaultFileService.generateVaultFileName(customDate);
      expect(filename, equals('SafeBloom-Vault-2026-12-25.safebloom'));

      final validVault = BackupCryptoService.encryptVault(
        plaintextJson: jsonEncode({
          'profile': {'last_period_start': '2026-08-01T00:00:00.000Z', 'avg_cycle_length': 28, 'avg_period_length': 5}
        }),
        passphrase: testPassword,
      );

      final file = await VaultFileService.createVaultFile(
        vaultContent: validVault,
        directory: tempTestDir,
        customFileName: 'test_envelope.safebloom',
      );

      expect(file.existsSync(), isTrue);
      final content = await VaultFileService.readVaultFile(file);
      expect(content, equals(validVault));

      final bytes = Uint8List.fromList(utf8.encode(validVault));
      final contentFromBytes = VaultFileService.readVaultFileFromBytes(bytes);
      expect(contentFromBytes, equals(validVault));
    });
  });
}
