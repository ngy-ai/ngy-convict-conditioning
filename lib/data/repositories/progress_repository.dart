import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/big_six.dart';

/// 记录用户六艺分别练到第几式。
class ProgressRepository {
  ProgressRepository(this._database);

  final AppDatabase _database;

  /// 未记录的六艺默认从第 1 式开始。
  Future<Map<BigSix, int>> levels() async {
    final db = await _database.open();
    final rows = await db.query('progress');
    final result = {for (final e in BigSix.values) e: 1};
    for (final row in rows) {
      result[BigSix.fromName(row['exercise'] as String)] =
          (row['level'] as int).clamp(1, 10);
    }
    return result;
  }

  Future<void> setLevel(BigSix exercise, int level) async {
    final db = await _database.open();
    await db.insert(
      'progress',
      {
        'exercise': exercise.name,
        'level': level.clamp(1, 10),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
