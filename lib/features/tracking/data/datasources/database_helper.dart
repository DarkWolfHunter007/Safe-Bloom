import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/utils/safe_bloom_date_utils.dart';
import '../../domain/entities/period_entry.dart';
import '../../domain/entities/symptom_entry.dart';
import '../../domain/entities/user_profile.dart';

/// Exception thrown when the database exists on disk but is corrupt or the key cannot decrypt it.
class DatabaseCorruptedOrInvalidKeyException implements Exception {
  final dynamic originalError;
  final String message;

  const DatabaseCorruptedOrInvalidKeyException([
    this.originalError,
    this.message = 'The local encrypted database could not be opened due to file corruption or cryptographic key mismatch.',
  ]);

  @override
  String toString() => 'DatabaseCorruptedOrInvalidKeyException: $message (${originalError ?? 'Unknown'})';
}

/// Exception thrown when the encrypted database file exists on disk, but the Keystore master key is missing.
class DatabaseKeyMissingException implements Exception {
  final String message;

  const DatabaseKeyMissingException([
    this.message = 'Database file exists on disk, but the required cryptographic key is missing from Android Keystore.',
  ]);

  @override
  String toString() => 'DatabaseKeyMissingException: $message';
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  final FlutterSecureStorage _secureStorage = SafeBloomSecureStorage.instance;
  DatabaseFactory? _customFactory;
  String? _customDbName;

  DatabaseHelper._init();

  DatabaseFactory get _factory => _customFactory ?? databaseFactory;
  String get _dbName => _customDbName ?? 'safebloom_encrypted.db';

  /// Used in test suites to inject SQLite FFI factory
  void setDatabaseFactoryForTesting(DatabaseFactory? factory) {
    _customFactory = factory;
    _database = null;
  }

  void setDatabaseNameForTesting(String? dbName) {
    _customDbName = dbName;
    _database = null;
  }

  /// Explicitly closes any active connection and resets state for tests
  Future<void> resetForTesting([DatabaseFactory? factory, String? dbName]) async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    _database = null;
    if (factory != null) {
      _customFactory = factory;
    }
    _customDbName = dbName;
  }

  /// Checks if the encrypted database file physically exists on the device filesystem.
  Future<bool> databaseFileExists() async {
    final dbPath = await _factory.getDatabasesPath();
    final path = join(dbPath, _dbName);
    return await _factory.databaseExists(path);
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;

    final dbPath = await _factory.getDatabasesPath();
    final path = join(dbPath, _dbName);
    final password = await _getOrCreateEncryptionPassword();

    Database? db;
    try {
      if (_customFactory != null) {
        db = await _customFactory!.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 4,
            onCreate: _createDB,
            onUpgrade: _onUpgrade,
            singleInstance: false,
          ),
        );
      } else {
        db = await openDatabase(
          path,
          password: password,
          version: 4,
          onCreate: _createDB,
          onUpgrade: _onUpgrade,
          singleInstance: false,
        );
      }

      // Perform a lightweight health check query to ensure the key decrypted the header and DB is readable
      await db.rawQuery('SELECT count(*) FROM sqlite_master');

      _database = db;
      return _database!;
    } catch (e) {
      if (db != null && db.isOpen) {
        try {
          await db.close();
        } catch (_) {}
      }
      if (_database != null && _database!.isOpen) {
        try {
          await _database!.close();
        } catch (_) {}
      }
      _database = null;
      if (e is DatabaseKeyMissingException) {
        rethrow;
      }
      // Never delete or overwrite the database file on open failure
      throw DatabaseCorruptedOrInvalidKeyException(e);
    }
  }

  /// Retrieve or generate AES-256 encryption password saved in hardware keychains.
  /// If the database already exists on disk, a missing key MUST NOT be regenerated
  /// over the existing database to avoid permanent data orphaning.
  Future<String> _getOrCreateEncryptionPassword() async {
    const key = 'safebloom_db_key';
    final dbExists = await databaseFileExists();

    // flutter_secure_storage can throw on Android when the EncryptedSharedPreferences
    // file has been wiped (e.g. pm clear / reinstall) while the Android Keystore alias
    // still exists. Treat any read error as a missing key so a clean install always works.
    String? dbKey;
    try {
      dbKey = await _secureStorage.read(key: key);
    } catch (_) {
      dbKey = null;
    }

    if (dbKey == null || dbKey.trim().isEmpty) {
      if (dbExists) {
        // DB file is present but key is gone — cannot safely open without key
        throw const DatabaseKeyMissingException();
      }
      // Fresh install: generate a new key and persist it
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      dbKey = base64UrlEncode(values);
      try {
        await _secureStorage.write(key: key, value: dbKey);
      } catch (_) {
        // If write also fails (rare Keystore issue), continue in-memory.
        // The key will be regenerated on next launch; acceptable for a first run.
      }
    }
    return dbKey;
  }

  Future<void> _createDB(Database db, int version) async {
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
        date_str TEXT PRIMARY KEY,
        water_ml INTEGER NOT NULL DEFAULT 0,
        mood TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY DEFAULT 1,
        last_period_start TEXT NOT NULL,
        initial_last_period_start TEXT,
        avg_cycle_length INTEGER NOT NULL DEFAULT 28,
        avg_period_length INTEGER NOT NULL DEFAULT 5,
        is_cloud_backup_enabled INTEGER NOT NULL DEFAULT 1,
        is_pregnancy_mode_enabled INTEGER NOT NULL DEFAULT 0,
        preferred_goal TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN preferred_goal TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN initial_last_period_start TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN is_pregnancy_mode_enabled INTEGER NOT NULL DEFAULT 0');
    }
  }

  // --- Period Entries ---

  Future<void> insertPeriodEntry(PeriodEntry entry) async {
    final db = await instance.database;
    await db.insert(
      'period_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertPeriodEntriesBatch(List<PeriodEntry> entries) async {
    if (entries.isEmpty) return;
    final db = await instance.database;
    final batch = db.batch();
    for (final entry in entries) {
      batch.insert(
        'period_entries',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updatePeriodEntry(PeriodEntry entry) async {
    final db = await instance.database;
    await db.update(
      'period_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<List<PeriodEntry>> getAllPeriodEntries() async {
    final db = await instance.database;
    final maps = await db.query('period_entries', orderBy: 'timestamp DESC');
    return maps.map((m) => PeriodEntry.fromMap(m)).toList();
  }

  Future<void> deletePeriodEntry(String id) async {
    final db = await instance.database;
    await db.delete('period_entries', where: 'id = ?', whereArgs: [id]);
  }

  // --- Symptom Entries ---

  Future<void> insertSymptomEntry(SymptomEntry entry) async {
    final db = await instance.database;
    await db.insert(
      'symptom_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertSymptomEntriesBatch(List<SymptomEntry> entries) async {
    if (entries.isEmpty) return;
    final db = await instance.database;
    final batch = db.batch();
    for (final entry in entries) {
      batch.insert(
        'symptom_entries',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateSymptomEntry(SymptomEntry entry) async {
    final db = await instance.database;
    await db.update(
      'symptom_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteSymptomEntry(String id) async {
    final db = await instance.database;
    await db.delete('symptom_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SymptomEntry>> getSymptomEntriesByDate(DateTime date) async {
    final db = await instance.database;
    final startStr = DateTime(date.year, date.month, date.day).toIso8601String();
    final endStr = DateTime(date.year, date.month, date.day + 1).toIso8601String();

    final maps = await db.query(
      'symptom_entries',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [startStr, endStr],
    );
    return maps.map((m) => SymptomEntry.fromMap(m)).toList();
  }

  Future<List<SymptomEntry>> getAllSymptomEntries() async {
    final db = await instance.database;
    final maps = await db.query('symptom_entries', orderBy: 'timestamp DESC');
    return maps.map((m) => SymptomEntry.fromMap(m)).toList();
  }

  // --- Daily Water Logs ---

  Future<int> getWaterIntakeForDate(DateTime date) async {
    final db = await instance.database;
    final dateStr = SafeBloomDateUtils.dateKey(date);
    final result = await db.query('daily_logs', where: 'date_str = ?', whereArgs: [dateStr]);
    if (result.isNotEmpty) {
      return result.first['water_ml'] as int? ?? 0;
    }
    return 0;
  }

  Future<void> setWaterIntakeForDate(DateTime date, int waterMl) async {
    final db = await instance.database;
    final dateStr = SafeBloomDateUtils.dateKey(date);
    await db.insert(
      'daily_logs',
      {'date_str': dateStr, 'water_ml': waterMl},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- User Profile ---

  Future<UserProfile?> getUserProfile() async {
    final db = await instance.database;
    final result = await db.query('user_profile', where: 'id = 1');
    if (result.isNotEmpty) {
      return UserProfile.fromMap(result.first);
    }
    return null;
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await instance.database;
    final map = profile.toMap();
    map['id'] = 1;
    await db.insert('user_profile', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Atomically imports user profile and entries in a single ACID transaction.
  /// If any entry fails or is invalid, the entire transaction rolls back cleanly.
  Future<void> executeAtomicImport({
    UserProfile? profile,
    List<PeriodEntry>? periodEntries,
    List<SymptomEntry>? symptomEntries,
  }) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      if (profile != null) {
        final map = profile.toMap();
        map['id'] = 1;
        await txn.insert(
          'user_profile',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (periodEntries != null && periodEntries.isNotEmpty) {
        for (final entry in periodEntries) {
          await txn.insert(
            'period_entries',
            entry.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      if (symptomEntries != null && symptomEntries.isNotEmpty) {
        for (final entry in symptomEntries) {
          await txn.insert(
            'symptom_entries',
            entry.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  /// Safely replaces a corrupted database file with a fresh database and imports
  /// validated backup data in an atomic transaction. Only called upon explicit recovery action.
  Future<void> resetAndRecreateDatabase({
    UserProfile? profile,
    List<PeriodEntry>? periodEntries,
    List<SymptomEntry>? symptomEntries,
  }) async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    _database = null;

    final dbPath = await _factory.getDatabasesPath();
    final path = join(dbPath, _dbName);

    try {
      await _factory.deleteDatabase(path);
    } catch (_) {}
    try {
      await _factory.deleteDatabase('$path-wal');
      await _factory.deleteDatabase('$path-shm');
      await _factory.deleteDatabase('$path-journal');
    } catch (_) {}
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
      for (final ext in ['-wal', '-shm', '-journal']) {
        final jf = File('$path$ext');
        if (jf.existsSync()) jf.deleteSync();
      }
    } catch (_) {}

    const key = 'safebloom_db_key';
    String? dbKey = await _secureStorage.read(key: key);
    if (dbKey == null || dbKey.trim().isEmpty) {
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      dbKey = base64UrlEncode(values);
      await _secureStorage.write(key: key, value: dbKey);
    }

    final Database db;
    if (_customFactory != null) {
      db = await _customFactory!.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: _createDB,
          onUpgrade: _onUpgrade,
          singleInstance: false,
        ),
      );
    } else {
      db = await openDatabase(
        path,
        password: dbKey,
        version: 3,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
        singleInstance: false,
      );
    }
    _database = db;

    if (profile != null ||
        (periodEntries != null && periodEntries.isNotEmpty) ||
        (symptomEntries != null && symptomEntries.isNotEmpty)) {
      await executeAtomicImport(
        profile: profile,
        periodEntries: periodEntries,
        symptomEntries: symptomEntries,
      );
    }
  }

  // --- Zero-Knowledge Full Data Wipe ---

  Future<void> wipeAllData() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
    final dbPath = await _factory.getDatabasesPath();
    final path = join(dbPath, _dbName);
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
      for (final ext in ['-wal', '-shm', '-journal']) {
        final jf = File('$path$ext');
        if (jf.existsSync()) jf.deleteSync();
      }
    } catch (_) {}
    try {
      await _factory.deleteDatabase(path);
    } catch (_) {}
    try {
      await _factory.deleteDatabase('$path-wal');
      await _factory.deleteDatabase('$path-shm');
      await _factory.deleteDatabase('$path-journal');
    } catch (_) {}
    await _secureStorage.delete(key: 'safebloom_db_key');
  }
}

