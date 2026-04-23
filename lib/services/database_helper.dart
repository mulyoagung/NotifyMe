import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/monitored_link.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('notifyme.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // kIsWeb = true means we are running inside Tauri (desktop), which is Windows
    // Platform.isWindows would crash on kIsWeb since dart:io Platform is unavailable.
    // Use sqfliteFfiInit for both kIsWeb (Tauri/Windows) and native Windows.
    final bool needsFfi =
        kIsWeb || (!kIsWeb && (Platform.isWindows || Platform.isLinux));
    if (needsFfi) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, 'NotifyMe', filePath);

    // Create directory if it doesn't exist
    final dir = Directory(join(dbPath.path, 'NotifyMe'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: _createDB,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
                "ALTER TABLE links ADD COLUMN previousSnapshot TEXT DEFAULT ''");
          }
          if (oldVersion < 3) {
            await db.execute(
                "ALTER TABLE links ADD COLUMN preNavigationScript TEXT DEFAULT ''");
          }
        },
      ),
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textTypeNull = 'TEXT';
    const boolType = 'BOOLEAN NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE links (
  id $idType,
  name $textType,
  url $textType,
  cssSelector $textTypeNull,
  intervalMinutes $intType,
  isActive $boolType,
  lastCheckedAt $textType,
  hasUpdate $boolType,
  lastSnapshot $textTypeNull,
  previousSnapshot $textTypeNull,
  preNavigationScript $textTypeNull
  )
''');
  }

  Future<MonitoredLink> create(MonitoredLink link) async {
    final db = await instance.database;
    final id = await db.insert('links', link.toMap());
    link.id = id;
    return link;
  }

  Future<MonitoredLink?> readLink(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'links',
      columns: [
        'id',
        'name',
        'url',
        'cssSelector',
        'intervalMinutes',
        'isActive',
        'lastCheckedAt',
        'hasUpdate',
        'lastSnapshot',
        'previousSnapshot',
        'preNavigationScript'
      ],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return MonitoredLink.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<MonitoredLink>> readAllLinks() async {
    final db = await instance.database;
    const orderBy = 'lastCheckedAt DESC';
    final result = await db.query('links', orderBy: orderBy);
    return result.map((json) => MonitoredLink.fromMap(json)).toList();
  }

  Future<int> update(MonitoredLink link) async {
    final db = await instance.database;
    return db.update(
      'links',
      link.toMap(),
      where: 'id = ?',
      whereArgs: [link.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'links',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
