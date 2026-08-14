import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/period_entry.dart';
import '../../domain/entities/symptom_entry.dart';
import '../../domain/entities/user_profile.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  final _secureStorage = const FlutterSecureStorage();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'safebloom_encrypted.db');
    final password = await _getOrCreateEncryptionPassword();

    _database = await openDatabase(
      path,
      password: password,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  /// Retrieve or generate AES-256 encryption password saved in hardware keychains.
  Future<String> _getOrCreateEncryptionPassword() async {
    const key = 'safebloom_db_key';
    String? dbKey = await _secureStorage.read(key: key);
    if (dbKey == null) {
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      dbKey = base64UrlEncode(values);
      await _secureStorage.write(key: key, value: dbKey);
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
    final endStr = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

    final maps = await db.query(
      'symptom_entries',
      where: 'timestamp >= ? AND timestamp <= ?',
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
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final result = await db.query('daily_logs', where: 'date_str = ?', whereArgs: [dateStr]);
    if (result.isNotEmpty) {
      return result.first['water_ml'] as int? ?? 0;
    }
    return 0;
  }

  Future<void> setWaterIntakeForDate(DateTime date, int waterMl) async {
    final db = await instance.database;
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

  // --- Zero-Knowledge Full Data Wipe ---

  Future<void> wipeAllData() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'safebloom_encrypted.db');
    final file = databaseFactory.deleteDatabase(path);
    await file;
    await _secureStorage.delete(key: 'safebloom_db_key');
  }
}
