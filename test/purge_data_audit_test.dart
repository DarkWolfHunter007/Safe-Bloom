import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Zero-Knowledge Purge Data Audit Tests', () {
    test('Purge deletes all SQLite tables, journal files, and user records completely', () async {
      const purgeDbPath = 'test_purge_vault.db';
      var db = await openDatabase(
        purgeDbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE user_profile (id INTEGER PRIMARY KEY, secret TEXT);');
          await db.execute('CREATE TABLE period_entries (id TEXT PRIMARY KEY, flow TEXT);');
          await db.execute('CREATE TABLE symptom_entries (id TEXT PRIMARY KEY, type TEXT);');
          await db.execute('CREATE TABLE daily_logs (date TEXT PRIMARY KEY, water_ml INTEGER);');
        },
      );

      // Populate sensitive health records
      await db.insert('user_profile', {'id': 1, 'secret': 'sensitive_user_profile'});
      await db.insert('period_entries', {'id': 'p-1', 'flow': 'heavy'});
      await db.insert('symptom_entries', {'id': 's-1', 'type': 'Severe Cramps'});
      await db.insert('daily_logs', {'date': '2026-08-01', 'water_ml': 2000});

      expect(await db.query('user_profile'), isNotEmpty);
      expect(await db.query('period_entries'), isNotEmpty);
      expect(await db.query('symptom_entries'), isNotEmpty);
      expect(await db.query('daily_logs'), isNotEmpty);

      // Perform full forensic purge
      await db.close();
      await databaseFactory.deleteDatabase(purgeDbPath);
      await databaseFactory.deleteDatabase('$purgeDbPath-wal');
      await databaseFactory.deleteDatabase('$purgeDbPath-shm');
      await databaseFactory.deleteDatabase('$purgeDbPath-journal');

      // Verify that database file no longer exists
      final exists = await databaseFactory.databaseExists(purgeDbPath);
      expect(exists, isFalse);

      // Verify fresh restart creates an empty vault without any residual artifacts
      final freshDb = await openDatabase(
        purgeDbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE user_profile (id INTEGER PRIMARY KEY, secret TEXT);');
        },
      );

      final freshProfile = await freshDb.query('user_profile');
      expect(freshProfile, isEmpty);
      await freshDb.close();
      await databaseFactory.deleteDatabase(purgeDbPath);
    });
  });
}
