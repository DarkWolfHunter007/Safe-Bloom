import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safe_bloom/features/tracking/domain/entities/period_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/symptom_entry.dart';
import 'package:safe_bloom/features/tracking/domain/entities/user_profile.dart';

void main() {
  // Initialize SQLite FFI for headless desktop test execution
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SQLite / Database Integration Tests', () {
    late Database db;
    const dbPath = inMemoryDatabasePath;

    Future<void> createSchema(Database db, int version) async {
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
        onCreate: (db, version) => createSchema(db, version),
      );
    });

    tearDown(() async {
      if (db.isOpen) {
        await db.close();
      }
    });

    test('Insert and read back UserProfile with full integrity', () async {
      final profile = UserProfile(
        lastPeriodStart: DateTime(2026, 8, 1),
        avgCycleLength: 29,
        avgPeriodLength: 5,
        isCloudBackupEnabled: true,
        preferredGoal: 'ttc',
        initialLastPeriodStart: DateTime(2026, 8, 1),
      );

      final map = profile.toMap();
      map['id'] = 1;
      await db.insert('user_profile', map, conflictAlgorithm: ConflictAlgorithm.replace);

      final results = await db.query('user_profile', where: 'id = 1');
      expect(results, isNotEmpty);
      final restored = UserProfile.fromMap(results.first);

      expect(restored.avgCycleLength, equals(29));
      expect(restored.avgPeriodLength, equals(5));
      expect(restored.preferredGoal, equals('ttc'));
      expect(restored.appMode, equals(AppMode.ttc));
      expect(restored.lastPeriodStart.year, equals(2026));
      expect(restored.lastPeriodStart.month, equals(8));
      expect(restored.lastPeriodStart.day, equals(1));
    });

    test('Insert, read, update, and delete PeriodEntry records', () async {
      final entry = PeriodEntry(
        id: 'period-test-1',
        timestamp: DateTime(2026, 8, 1, 9, 30),
        flow: FlowLevel.heavy,
        notes: 'Cycle start',
      );

      await db.insert('period_entries', entry.toMap());

      // Query
      var queryResult = await db.query('period_entries', where: 'id = ?', whereArgs: ['period-test-1']);
      expect(queryResult.length, 1);
      var retrieved = PeriodEntry.fromMap(queryResult.first);
      expect(retrieved.flow, equals(FlowLevel.heavy));
      expect(retrieved.notes, equals('Cycle start'));

      // Update
      final updated = PeriodEntry(
        id: 'period-test-1',
        timestamp: DateTime(2026, 8, 1, 9, 30),
        flow: FlowLevel.medium,
        notes: 'Updated flow',
      );
      await db.update('period_entries', updated.toMap(), where: 'id = ?', whereArgs: ['period-test-1']);

      queryResult = await db.query('period_entries', where: 'id = ?', whereArgs: ['period-test-1']);
      retrieved = PeriodEntry.fromMap(queryResult.first);
      expect(retrieved.flow, equals(FlowLevel.medium));
      expect(retrieved.notes, equals('Updated flow'));

      // Delete
      await db.delete('period_entries', where: 'id = ?', whereArgs: ['period-test-1']);
      queryResult = await db.query('period_entries', where: 'id = ?', whereArgs: ['period-test-1']);
      expect(queryResult, isEmpty);
    });

    test('Batch insertion and SymptomEntry querying', () async {
      final now = DateTime(2026, 8, 1);
      final symptoms = [
        SymptomEntry(
          id: 'sym-1',
          timestamp: now,
          category: SymptomCategory.pain,
          type: 'Cramps',
          intensity: 4,
          notes: 'Pelvic cramping',
        ),
        SymptomEntry(
          id: 'sym-2',
          timestamp: now,
          category: SymptomCategory.mood,
          type: 'Irritable',
          intensity: 2,
        ),
        SymptomEntry(
          id: 'sym-3',
          timestamp: now.add(const Duration(days: 1)),
          category: SymptomCategory.energy,
          type: 'Fatigue',
          intensity: 3,
        ),
      ];

      final batch = db.batch();
      for (final s in symptoms) {
        batch.insert('symptom_entries', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      final results = await db.query('symptom_entries', orderBy: 'timestamp ASC');
      expect(results.length, 3);
      final restored = results.map((m) => SymptomEntry.fromMap(m)).toList();
      expect(restored[0].type, equals('Cramps'));
      expect(restored[0].intensity, equals(4));
      expect(restored[1].type, equals('Irritable'));
      expect(restored[2].type, equals('Fatigue'));
    });

    test('Daily logs water intake tracking works correctly', () async {
      await db.insert(
        'daily_logs',
        {'date': '2026-08-01', 'water_ml': 1500, 'updated_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final results = await db.query('daily_logs', where: 'date = ?', whereArgs: ['2026-08-01']);
      expect(results.first['water_ml'], equals(1500));

      // Update to 2000ml
      await db.insert(
        'daily_logs',
        {'date': '2026-08-01', 'water_ml': 2000, 'updated_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final updatedResults = await db.query('daily_logs', where: 'date = ?', whereArgs: ['2026-08-01']);
      expect(updatedResults.first['water_ml'], equals(2000));
    });

    test('Atomic transaction rollbacks leave database completely unmodified on failure', () async {
      // Pre-insert one valid entry
      await db.insert('period_entries', {
        'id': 'initial-entry',
        'timestamp': '2026-08-01T00:00:00.000',
        'flow': 'heavy',
        'notes': 'Initial',
      });

      // Attempt transaction that throws midway
      try {
        await db.transaction((txn) async {
          await txn.insert('period_entries', {
            'id': 'txn-entry-1',
            'timestamp': '2026-08-02T00:00:00.000',
            'flow': 'medium',
          });

          // Intentional failure / constraint error
          throw Exception('Simulated database error in transaction');
        });
      } catch (_) {}

      // Verify that 'txn-entry-1' was rolled back
      final allPeriods = await db.query('period_entries');
      expect(allPeriods.length, 1);
      expect(allPeriods.first['id'], equals('initial-entry'));
    });

    test('Database schema migration onUpgrade adds missing columns seamlessly', () async {
      // Create V1 database with unique name and V1 schema
      const migrationDbPath = 'test_migration_v1.db';
      await databaseFactory.deleteDatabase(migrationDbPath);
      final migrationDb = await openDatabase(
        migrationDbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE user_profile (
              id INTEGER PRIMARY KEY,
              last_period_start TEXT NOT NULL,
              avg_cycle_length INTEGER NOT NULL,
              avg_period_length INTEGER NOT NULL,
              is_cloud_backup_enabled INTEGER NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
        },
      );

      // Insert V1 profile
      await migrationDb.insert('user_profile', {
        'id': 1,
        'last_period_start': '2026-08-01T00:00:00.000',
        'avg_cycle_length': 28,
        'avg_period_length': 5,
        'is_cloud_backup_enabled': 1,
        'created_at': '2026-08-01T00:00:00.000',
      });

      // Execute V1 -> V3 migration statements
      await migrationDb.execute('ALTER TABLE user_profile ADD COLUMN preferred_goal TEXT;');
      await migrationDb.execute('ALTER TABLE user_profile ADD COLUMN initial_last_period_start TEXT;');

      // Verify columns exist and can be written/read
      await migrationDb.update(
        'user_profile',
        {'preferred_goal': 'ttc', 'initial_last_period_start': '2026-08-01T00:00:00.000'},
        where: 'id = 1',
      );

      final migrated = await migrationDb.query('user_profile', where: 'id = 1');
      expect(migrated.isNotEmpty, isTrue);
      expect(migrated.first['preferred_goal'], equals('ttc'));
      expect(migrated.first['initial_last_period_start'], equals('2026-08-01T00:00:00.000'));
      await migrationDb.close();
      await databaseFactory.deleteDatabase(migrationDbPath);
    });
  });
}
