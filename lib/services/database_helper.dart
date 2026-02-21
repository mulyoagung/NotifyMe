import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
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
    if (Platform.isWindows || Platform.isLinux) {
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
        version: 1,
        onCreate: _createDB,
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
  lastSnapshot $textTypeNull
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
        'lastSnapshot'
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
