import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'memory_events.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE memory_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        app_name TEXT,
        activity TEXT,
        timestamp TEXT
      )
    ''');
  }

  Future<int> insertEvent(Map<String, dynamic> event) async {
    Database db = await database;
    return await db.insert('memory_events', event);
  }

  Future<List<Map<String, dynamic>>> getEvents() async {
    Database db = await database;
    return await db.query('memory_events', orderBy: 'id DESC');
  }
}
