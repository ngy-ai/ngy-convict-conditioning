import '../db/app_database.dart';
import '../models/big_six.dart';
import '../models/training_plan.dart';
import '../models/workout_session.dart';
import 'backup_data.dart';

/// 备份的读写：把三张表拼成 [BackupData]，恢复时整库替换。
class BackupService {
  BackupService(this._database);

  final AppDatabase _database;

  /// 读出全部数据（训练记录按日期正序，计划按创建时间正序）。
  Future<BackupData> export() async {
    final db = await _database.open();
    final sessionRows = await db.query('sessions', orderBy: 'date ASC, id ASC');
    final entryRows = await db.query(
      'entries',
      orderBy: 'session_id ASC, order_index ASC, id ASC',
    );

    final entriesBySession = <int, List<WorkoutEntry>>{};
    for (final row in entryRows) {
      final entry = WorkoutEntry.fromRow(row);
      entriesBySession.putIfAbsent(entry.sessionId!, () => []).add(entry);
    }

    final progressRows = await db.query('progress');
    final levels = {for (final exercise in BigSix.values) exercise: 1};
    for (final row in progressRows) {
      final matches =
          BigSix.values.where((e) => e.name == row['exercise'] as String);
      if (matches.isEmpty) continue;
      levels[matches.first] = (row['level'] as int).clamp(1, 10);
    }

    final planRows = await db.query('plans', orderBy: 'created_at ASC, id ASC');

    return BackupData(
      exportedAt: DateTime.now(),
      sessions: [
        for (final row in sessionRows)
          WorkoutSession.fromRow(
            row,
            entries: entriesBySession[row['id'] as int] ?? const [],
          ),
      ],
      levels: levels,
      plans: [for (final row in planRows) TrainingPlan.fromRow(row)],
    );
  }

  /// 覆盖式恢复：先清空现有数据，再写入备份内容。
  ///
  /// 整个过程在一个事务里，任一步失败都会回滚，不会留下半份数据。
  Future<void> restore(BackupData data) async {
    final db = await _database.open();
    await db.transaction((txn) async {
      await txn.delete('entries');
      await txn.delete('sessions');
      await txn.delete('progress');
      await txn.delete('plans');

      for (final session in data.sessions) {
        final sessionId = await txn.insert('sessions', session.toRow());
        for (var i = 0; i < session.entries.length; i++) {
          await txn.insert(
            'entries',
            session.entries[i]
                .copyWith(sessionId: sessionId, orderIndex: i)
                .toRow(),
          );
        }
      }

      for (final entry in data.levels.entries) {
        await txn.insert('progress', {
          'exercise': entry.key.name,
          'level': entry.value.clamp(1, 10),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      for (final plan in data.plans) {
        await txn.insert('plans', plan.toRow());
      }
    });
  }
}
