import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';

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
      version: 1,
      onCreate: _createDB,
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
  }
}
