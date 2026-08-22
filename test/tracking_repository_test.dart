import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safe_bloom/core/services/backup_crypto_service.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/symptom_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/user_profile.dart';
import 'package:safe_bloom/features/tracking/domain/services/cycle_calculator.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('TrackingRepository Integration Tests', () {
    late Database db;
    const dbPath = inMemoryDatabasePath;

    Future<void> createSchema(Database db) async {
      await db.execute('''
        CREATE TABLE user_profile (
          id INTEGER PRIMARY KEY,
          last_period_start TEXT NOT NULL,
          avg_cycle_length INTEGER NOT NULL,
          avg_period_length INTEGER NOT NULL,
          is_cloud_backup_enabled INTEGER NOT NULL,
          is_pregnancy_mode_enabled INTEGER NOT NULL DEFAULT 0,
          preferred_goal TEXT,
          initial_last_period_start TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE period_entries (
          id TEXT PRIMARY KEY,
          timestamp TEXT NOT NULL,
          flow TEXT NOT NULL,
          notes TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE symptom_entries (
          id TEXT PRIMARY KEY,
          timestamp TEXT NOT NULL,
          category TEXT NOT NULL,
          type TEXT NOT NULL,
          intensity INTEGER NOT NULL,
          notes TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE daily_logs (
          date TEXT PRIMARY KEY,
          water_ml INTEGER NOT NULL DEFAULT 0,
          updated_at TEXT NOT NULL
        )
      ''');
    }

    setUp(() async {
      db = await openDatabase(
        dbPath,
        version: 3,
        onCreate: (db, version) => createSchema(db),
      );
    });

    tearDown(() async {
      if (db.isOpen) {
        await db.close();
      }
    });

    test('Period insertion, editing, and deletion', () async {
      final entry = PeriodEntry(
        id: 'p-100',
        timestamp: DateTime(2026, 8, 1),
        flow: FlowLevel.heavy,
        notes: 'First day',
      );

      // Insert
      await db.insert('period_entries', entry.toMap());
      var query = await db.query('period_entries', where: 'id = ?', whereArgs: ['p-100']);
      expect(query.length, 1);

      // Edit
      final updated = PeriodEntry(
        id: 'p-100',
        timestamp: DateTime(2026, 8, 1),
        flow: FlowLevel.medium,
        notes: 'Edited flow',
      );
      await db.update('period_entries', updated.toMap(), where: 'id = ?', whereArgs: ['p-100']);
      query = await db.query('period_entries', where: 'id = ?', whereArgs: ['p-100']);
      expect(PeriodEntry.fromMap(query.first).flow, equals(FlowLevel.medium));

      // Delete
      await db.delete('period_entries', where: 'id = ?', whereArgs: ['p-100']);
      query = await db.query('period_entries', where: 'id = ?', whereArgs: ['p-100']);
      expect(query, isEmpty);
    });

    test('Symptom insertion, categorization, and deletion', () async {
      final symptom = SymptomEntry(
        id: 'sym-100',
        timestamp: DateTime(2026, 8, 1),
        category: SymptomCategory.pain,
        type: 'Headache',
        intensity: 3,
      );

      await db.insert('symptom_entries', symptom.toMap());
      var query = await db.query('symptom_entries', where: 'id = ?', whereArgs: ['sym-100']);
      expect(query.length, 1);
      expect(SymptomEntry.fromMap(query.first).type, equals('Headache'));

      await db.delete('symptom_entries', where: 'id = ?', whereArgs: ['sym-100']);
      query = await db.query('symptom_entries', where: 'id = ?', whereArgs: ['sym-100']);
      expect(query, isEmpty);
    });

    test('Moving-average dynamic recalculation when multiple cycles exist', () {
      final entries = [
        // Cycle 1: June 1 -> 4 active flow days + 1 trailing spotting (active days = 4)
        PeriodEntry(id: '1', timestamp: DateTime(2026, 6, 1), flow: FlowLevel.heavy),
        PeriodEntry(id: '2', timestamp: DateTime(2026, 6, 2), flow: FlowLevel.heavy),
        PeriodEntry(id: '3', timestamp: DateTime(2026, 6, 3), flow: FlowLevel.medium),
        PeriodEntry(id: '4', timestamp: DateTime(2026, 6, 4), flow: FlowLevel.light),
        PeriodEntry(id: '5', timestamp: DateTime(2026, 6, 5), flow: FlowLevel.spotting),

        // Cycle 2: June 30 (29-day cycle) -> 4 active flow days + 1 trailing spotting (active days = 4)
        PeriodEntry(id: '6', timestamp: DateTime(2026, 6, 30), flow: FlowLevel.heavy),
        PeriodEntry(id: '7', timestamp: DateTime(2026, 7, 1), flow: FlowLevel.heavy),
        PeriodEntry(id: '8', timestamp: DateTime(2026, 7, 2), flow: FlowLevel.medium),
        PeriodEntry(id: '9', timestamp: DateTime(2026, 7, 3), flow: FlowLevel.light),
        PeriodEntry(id: '10', timestamp: DateTime(2026, 7, 4), flow: FlowLevel.spotting),

        // Cycle 3: July 28 (28-day cycle) -> 4 active flow days
        PeriodEntry(id: '11', timestamp: DateTime(2026, 7, 28), flow: FlowLevel.heavy),
        PeriodEntry(id: '12', timestamp: DateTime(2026, 7, 29), flow: FlowLevel.heavy),
        PeriodEntry(id: '13', timestamp: DateTime(2026, 7, 30), flow: FlowLevel.medium),
        PeriodEntry(id: '14', timestamp: DateTime(2026, 7, 31), flow: FlowLevel.light),
      ];

      final averages = CycleCalculator.calculateAveragesFromEntries(entries);

      // Cycle lengths: (Jun1→Jun30 = 29 days) + (Jun30→Jul28 = 28 days) / 2 = 28.5 → 29
      // Active period days: (4 + 4 + 4) / 3 = 4 (trailing spotting is not an active bleeding day)
      expect(averages['avgCycleLength'], equals(29));
      expect(averages['avgPeriodLength'], equals(4));
    });

    test('Encrypted backup vault encryption and authenticated decryption', () {
      final profile = UserProfile(
        lastPeriodStart: DateTime(2026, 8, 1),
        avgCycleLength: 28,
        avgPeriodLength: 5,
        preferredGoal: 'ttc',
      );

      final payload = {
        'version': 1,
        'profile': profile.toMap(),
        'period_entries': [],
        'symptom_entries': [],
        'exported_at': DateTime.now().toUtc().toIso8601String(),
      };

      const password = 'SuperSecretVaultKey2026!';
      final encryptedVault = BackupCryptoService.encryptVault(
        plaintextJson: payload.toString(),
        passphrase: password,
      );

      final decrypted = BackupCryptoService.decryptVault(
        vaultJsonString: encryptedVault,
        passphrase: password,
      );

      expect(decrypted, equals(payload.toString()));
    });

    test('Data wipe cleans all tables completely', () async {
      await db.insert('user_profile', {
        'id': 1,
        'last_period_start': '2026-08-01T00:00:00.000',
        'avg_cycle_length': 28,
        'avg_period_length': 5,
        'is_cloud_backup_enabled': 1,
        'created_at': '2026-08-01T00:00:00.000',
      });

      await db.insert('period_entries', {
        'id': 'p-1',
        'timestamp': '2026-08-01T00:00:00.000',
        'flow': 'heavy',
      });

      // Wipe tables
      await db.delete('user_profile');
      await db.delete('period_entries');
      await db.delete('symptom_entries');
      await db.delete('daily_logs');

      expect(await db.query('user_profile'), isEmpty);
      expect(await db.query('period_entries'), isEmpty);
      expect(await db.query('symptom_entries'), isEmpty);
      expect(await db.query('daily_logs'), isEmpty);
    });
  });
}
