import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_convict_conditioning/data/backup/backup_data.dart';
import 'package:ngy_convict_conditioning/data/backup/backup_service.dart';
import 'package:ngy_convict_conditioning/data/db/app_database.dart';
import 'package:ngy_convict_conditioning/data/models/big_six.dart';
import 'package:ngy_convict_conditioning/data/models/move.dart';
import 'package:ngy_convict_conditioning/data/models/training_plan.dart';
import 'package:ngy_convict_conditioning/data/models/workout_session.dart';
import 'package:ngy_convict_conditioning/data/repositories/plan_repository.dart';
import 'package:ngy_convict_conditioning/data/repositories/progress_repository.dart';
import 'package:ngy_convict_conditioning/data/repositories/session_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late BackupService backup;
  late SessionRepository sessions;
  late ProgressRepository progress;
  late PlanRepository plans;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // 单独的库文件，避免和其它测试互相清库。
    database = AppDatabase.forTesting('backup_test.db');
    final db = await database.open();
    for (final table in ['entries', 'sessions', 'progress', 'plans']) {
      await db.delete(table);
    }
    backup = BackupService(database);
    sessions = SessionRepository(database);
    progress = ProgressRepository(database);
    plans = PlanRepository(database);
  });

  /// 造一份有记录、有进度、有计划的数据。
  Future<void> seed() async {
    await sessions.save(WorkoutSession(
      date: DateTime(2026, 10, 11),
      note: '状态一般',
      entries: [
        WorkoutEntry(moveId: 1, sets: const [10, 8]),
        WorkoutEntry(moveId: 21, sets: const [30, 30, 28], note: '腿有点酸'),
      ],
    ));
    await sessions.save(WorkoutSession(
      date: DateTime(2026, 10, 12),
      entries: [WorkoutEntry(moveId: 5, sets: const [20, 18, 15])],
    ));
    await progress.setLevel(BigSix.pushup, 3);
    await progress.setLevel(BigSix.squat, 2);
    await plans.save(TrainingPlan(
      name: '好习惯',
      template: PlanTemplate.goodBehavior,
      targetLevel: TargetLevel.intermediate,
      setsPerExercise: 4,
      startDate: DateTime(2026, 10, 12),
      days: const [
        PlanDay(label: '推类日', weekdays: [1, 4], exercises: [
          BigSix.pushup,
          BigSix.handstandPushup,
        ]),
        PlanDay(label: '拉类日', weekdays: [2, 5], exercises: [
          BigSix.pullup,
          BigSix.squat,
        ]),
      ],
      createdAt: DateTime(2026, 10, 12, 9, 30),
    ));
  }

  test('导出会带上全部记录、进度与计划', () async {
    await seed();

    final data = await backup.export();

    expect(data.sessionCount, 2);
    expect(data.entryCount, 3);
    expect(data.setCount, 2 + 3 + 3);
    expect(data.planCount, 1);
    expect(data.levels[BigSix.pushup], 3);
    expect(data.levels[BigSix.pullup], 1, reason: '没记录的六艺是第 1 式');

    final json = data.toJson();
    expect(json['app'], backupAppId);
    expect(json['version'], backupFormatVersion);
  });

  test('导出 → 编码 → 解码 → 恢复，数据完全一致', () async {
    await seed();
    final original = await backup.export();
    final json = original.encode();

    // 清空后从 JSON 恢复。
    final db = await database.open();
    for (final table in ['entries', 'sessions', 'progress', 'plans']) {
      await db.delete(table);
    }
    expect((await backup.export()).sessionCount, 0);

    await backup.restore(BackupData.decode(json));
    final restored = await backup.export();

    expect(restored.sessionCount, original.sessionCount);
    expect(restored.planCount, original.planCount);
    expect(restored.setCount, original.setCount);
    expect(restored.levels, original.levels);
    expect(restored.plans.single.days.length, original.plans.single.days.length);
    expect(restored.plans.single.setsPerExercise, 4);

    final before = original.sessions.first;
    final after = restored.sessions.first;
    expect(after.date, before.date);
    expect(after.note, before.note);
    expect(after.entries.map((e) => e.moveId), before.entries.map((e) => e.moveId));
    expect(after.entries.map((e) => e.sets), before.entries.map((e) => e.sets));
    expect(after.entries.last.note, '腿有点酸');
  });

  test('恢复是覆盖式的：原有数据会被替换', () async {
    await seed();
    final json = (await backup.export()).encode();

    // 之后又练了别的：清空后写入新数据，再恢复旧备份。
    final db = await database.open();
    for (final table in ['entries', 'sessions', 'progress', 'plans']) {
      await db.delete(table);
    }
    await sessions.save(WorkoutSession(
      date: DateTime(2026, 10, 13),
      entries: [WorkoutEntry(moveId: 55, sets: const [5])],
    ));
    await progress.setLevel(BigSix.bridge, 7);

    await backup.restore(BackupData.decode(json));
    final restored = await backup.export();

    expect(restored.sessionCount, 2, reason: '临时写入的那条应被覆盖掉');
    expect(restored.levels[BigSix.bridge], 1);
    expect(restored.levels[BigSix.pushup], 3);
  });

  test('备份文件里不含数据库自增号', () async {
    await seed();
    final json = (await backup.export()).toJson();

    final session = (json['sessions']! as List).first as Map;
    expect(session.containsKey('id'), isFalse);
    final entry = (session['entries']! as List).first as Map;
    expect(entry.containsKey('id'), isFalse);
    expect(entry.containsKey('sessionId'), isFalse);
    final plan = (json['plans']! as List).first as Map;
    expect(plan.containsKey('id'), isFalse);
  });

  test('恢复后明细挂在新的记录上', () async {
    await seed();
    final json = (await backup.export()).encode();
    final db = await database.open();
    for (final table in ['entries', 'sessions', 'progress', 'plans']) {
      await db.delete(table);
    }

    await backup.restore(BackupData.decode(json));

    final rows = await db.query('entries');
    final sessionIds = (await db.query('sessions')).map((r) => r['id']).toSet();
    expect(rows, hasLength(3));
    for (final row in rows) {
      expect(sessionIds, contains(row['session_id']), reason: '明细不能挂空');
    }
  });

  test('损坏或版本过高的备份文件会被拒绝', () {
    expect(
      () => BackupData.decode('这不是 json'),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      () => BackupData.decode('[1, 2, 3]'),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      () => BackupData.decode('{"sessions": []}'),
      throwsA(isA<BackupFormatException>()),
      reason: '缺少版本号',
    );
    expect(
      () => BackupData.decode(
          '{"version": ${backupFormatVersion + 1}, "sessions": []}'),
      throwsA(isA<BackupFormatException>()),
      reason: '版本高于当前应用',
    );
    expect(
      () => BackupData.decode('{"app": "other_app", "version": 1}'),
      throwsA(isA<BackupFormatException>()),
      reason: '不是本应用的文件',
    );
    expect(
      () => BackupData.decode('{"version": 1, "sessions": [{"date": "昨天"}]}'),
      throwsA(isA<BackupFormatException>()),
      reason: '日期格式不对',
    );
  });

  test('最简备份也能解析，未知六艺被忽略', () {
    final data = BackupData.decode('''
      {
        "version": 1,
        "sessions": [],
        "progress": [
          {"exercise": "pushup", "level": 5},
          {"exercise": "kungfu", "level": 9}
        ],
        "plans": []
      }
    ''');

    expect(data.levels[BigSix.pushup], 5);
    expect(data.levels.length, BigSix.values.length, reason: '未知六艺不进结果');
    expect(data.levels[BigSix.squat], 1);
    expect(data.exportedAt, isNotNull);
  });

  test('文件名带日期', () {
    expect(
      BackupData.fileNameFor(DateTime(2026, 10, 13)),
      'convict-conditioning-2026-10-13.json',
    );
  });
}
