import '../db/app_database.dart';
import '../models/training_plan.dart';

/// 训练计划的读写。同一时刻只保留一个生效计划。
class PlanRepository {
  PlanRepository(this._database);

  final AppDatabase _database;

  Future<List<TrainingPlan>> all() async {
    final db = await _database.open();
    final rows = await db.query('plans', orderBy: 'created_at DESC, id DESC');
    return rows.map(TrainingPlan.fromRow).toList();
  }

  Future<TrainingPlan?> activePlan() async {
    final db = await _database.open();
    final rows = await db.query(
      'plans',
      where: 'active = 1',
      orderBy: 'created_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TrainingPlan.fromRow(rows.first);
  }

  /// 保存计划；若计划为生效状态，则把其余计划置为停用。
  Future<int> save(TrainingPlan plan) async {
    final db = await _database.open();
    return db.transaction((txn) async {
      if (plan.active) {
        await txn.update('plans', {'active': 0});
      }
      final row = plan.toRow();
      if (plan.id == null) {
        return txn.insert('plans', row);
      }
      await txn.update('plans', row, where: 'id = ?', whereArgs: [plan.id]);
      return plan.id!;
    });
  }

  Future<void> delete(int id) async {
    final db = await _database.open();
    await db.delete('plans', where: 'id = ?', whereArgs: [id]);
  }
}
