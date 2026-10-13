import '../db/app_database.dart';
import '../models/workout_session.dart';

/// 训练记录的读写。统计类计算见 domain/workout_stats.dart。
class SessionRepository {
  SessionRepository(this._database);

  final AppDatabase _database;

  /// 全部训练记录，按日期倒序（同一天按录入顺序倒序）。
  Future<List<WorkoutSession>> all() => query();

  Future<List<WorkoutSession>> query({DateTime? from, DateTime? to}) async {
    final db = await _database.open();
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('date >= ?');
      args.add(WorkoutSession.formatDate(from));
    }
    if (to != null) {
      where.add('date <= ?');
      args.add(WorkoutSession.formatDate(to));
    }

    final rows = await db.query(
      'sessions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC, id DESC',
    );
    if (rows.isEmpty) return const [];

    final ids = rows.map((r) => r['id'] as int).toList();
    final entryRows = await db.query(
      'entries',
      where: 'session_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
      orderBy: 'order_index ASC, id ASC',
    );
    final grouped = <int, List<WorkoutEntry>>{};
    for (final row in entryRows) {
      final entry = WorkoutEntry.fromRow(row);
      grouped.putIfAbsent(entry.sessionId!, () => []).add(entry);
    }

    return rows
        .map((row) => WorkoutSession.fromRow(
              row,
              entries: grouped[row['id'] as int] ?? const [],
            ))
        .toList();
  }

  /// 新增或更新一次训练（含所有明细）。
  Future<int> save(WorkoutSession session) async {
    final db = await _database.open();
    return db.transaction((txn) async {
      int sessionId;
      if (session.id == null) {
        sessionId = await txn.insert('sessions', session.toRow());
      } else {
        sessionId = session.id!;
        await txn.update('sessions', session.toRow(),
            where: 'id = ?', whereArgs: [sessionId]);
        await txn
            .delete('entries', where: 'session_id = ?', whereArgs: [sessionId]);
      }

      for (var i = 0; i < session.entries.length; i++) {
        final entry = session.entries[i];
        await txn.insert(
          'entries',
          entry.copyWith(sessionId: sessionId, orderIndex: i).toRow(),
        );
      }
      return sessionId;
    });
  }

  Future<void> delete(int sessionId) async {
    final db = await _database.open();
    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  }
}
