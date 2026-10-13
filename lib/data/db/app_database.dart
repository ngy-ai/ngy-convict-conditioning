import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 本地 SQLite 数据库。全部数据保存在设备本地，无需网络。
class AppDatabase {
  AppDatabase._({String? fileName}) : _fileName = fileName ?? defaultFileName;

  /// 应用使用的单例，数据库文件为 [defaultFileName]。
  static final AppDatabase instance = AppDatabase._();

  /// 单独指定数据库文件（单元测试用，避免与其它用例互相清库）。
  factory AppDatabase.forTesting(String fileName) =>
      AppDatabase._(fileName: fileName);

  static const defaultFileName = 'convict_conditioning.db';
  static const _version = 1;

  final String _fileName;

  Database? _db;
  Future<Database>? _opening;

  /// 并发调用只会打开一次数据库。
  Future<Database> open() {
    final existing = _db;
    if (existing != null) return Future.value(existing);
    return _opening ??= _openInternal();
  }

  /// 桌面端（Windows / macOS / Linux）没有 sqflite 原生实现，改用 FFI 版本。
  static void _ensurePlatformFactory() {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<String> _databaseDirectory() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      try {
        // 桌面端放到系统应用数据目录：%APPDATA%\<app>（Windows）。
        final dir = await getApplicationSupportDirectory();
        return await dir.create(recursive: true).then((d) => d.path);
      } catch (_) {
        // 单元测试等没有插件/binding 的环境，退回 sqflite 默认目录。
      }
    }
    return getDatabasesPath();
  }

  Future<Database> _openInternal() async {
    _ensurePlatformFactory();
    final dir = await _databaseDirectory();
    final db = await openDatabase(
      p.join(dir, _fileName),
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
    _db = db;
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_sessions_date ON sessions(date)');

    await db.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        move_id INTEGER NOT NULL,
        order_index INTEGER NOT NULL DEFAULT 0,
        sets_json TEXT NOT NULL,
        note TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_entries_session ON entries(session_id)');
    await db.execute('CREATE INDEX idx_entries_move ON entries(move_id)');

    await db.execute('''
      CREATE TABLE progress (
        exercise TEXT PRIMARY KEY,
        level INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        template TEXT NOT NULL,
        target_level TEXT NOT NULL,
        sets_per_exercise INTEGER NOT NULL DEFAULT 3,
        start_date TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        days_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }
}
