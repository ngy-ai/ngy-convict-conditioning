import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_convict_conditioning/data/db/app_database.dart';
import 'package:ngy_convict_conditioning/data/models/big_six.dart';
import 'package:ngy_convict_conditioning/data/models/move.dart';
import 'package:ngy_convict_conditioning/data/models/training_plan.dart';
import 'package:ngy_convict_conditioning/data/models/workout_session.dart';
import 'package:ngy_convict_conditioning/data/repositories/plan_repository.dart';
import 'package:ngy_convict_conditioning/data/repositories/progress_repository.dart';
import 'package:ngy_convict_conditioning/data/repositories/session_repository.dart';
import 'package:ngy_convict_conditioning/domain/plan_generator.dart';
import 'package:ngy_convict_conditioning/domain/workout_stats.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late SessionRepository sessions;
  late ProgressRepository progress;
  late PlanRepository plans;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await AppDatabase.instance.open();
    for (final table in ['entries', 'sessions', 'progress', 'plans']) {
      await db.delete(table);
    }
    sessions = SessionRepository(AppDatabase.instance);
    progress = ProgressRepository(AppDatabase.instance);
    plans = PlanRepository(AppDatabase.instance);
  });

  test('保存并读回训练记录（含每组次数）', () async {
    final id = await sessions.save(WorkoutSession(
      date: DateTime(2026, 10, 12),
      note: '状态不错',
      entries: [
        WorkoutEntry(moveId: 5, sets: const [20, 18, 15]),
        WorkoutEntry(moveId: 55, sets: const [8, 8]),
      ],
    ));

    final all = await sessions.all();
    expect(all.length, 1);
    expect(all.first.id, id);
    expect(all.first.note, '状态不错');
    expect(all.first.totalSets, 5);
    expect(all.first.entries.first.sets, const [20, 18, 15]);
    expect(all.first.entries.last.moveId, 55);

    final stats = WorkoutStats(all);
    expect(stats.totalVolume, 69);
    expect(stats.totalsByMove[5]!.bestSet, 20);
  });

  test('再次保存同一条记录会替换原有组数据', () async {
    final id = await sessions.save(WorkoutSession(
      date: DateTime(2026, 10, 12),
      entries: [WorkoutEntry(moveId: 5, sets: const [20, 18, 15])],
    ));

    await sessions.save(WorkoutSession(
      id: id,
      date: DateTime(2026, 10, 12),
      entries: [WorkoutEntry(moveId: 5, sets: const [30])],
    ));

    final all = await sessions.all();
    expect(all.length, 1);
    expect(all.first.totalSets, 1);
    expect(all.first.entries.single.sets, const [30]);
  });

  test('按日期区间查询与删除', () async {
    await sessions.save(WorkoutSession(
      date: DateTime(2026, 9, 30),
      entries: [WorkoutEntry(moveId: 5, sets: const [10])],
    ));
    final recent = await sessions.save(WorkoutSession(
      date: DateTime(2026, 10, 12),
      entries: [WorkoutEntry(moveId: 5, sets: const [12])],
    ));

    final range = await sessions.query(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
    );
    expect(range.length, 1);
    expect(range.first.date.day, 12);

    await sessions.delete(recent);
    expect((await sessions.all()).length, 1);
  });

  test('六艺进度读写，默认从第 1 式开始', () async {
    final initial = await progress.levels();
    expect(initial.length, BigSix.values.length);
    expect(initial[BigSix.pushup], 1);

    await progress.setLevel(BigSix.pushup, 6);
    await progress.setLevel(BigSix.bridge, 3);

    final updated = await progress.levels();
    expect(updated[BigSix.pushup], 6);
    expect(updated[BigSix.bridge], 3);
    expect(updated[BigSix.squat], 1);
  });

  test('进度写入越界值会被限制在 1~10', () async {
    await progress.setLevel(BigSix.squat, 99);
    expect((await progress.levels())[BigSix.squat], 10);
  });

  test('计划保存后同一时间只有一个是生效的', () async {
    await plans.save(PlanGenerator.build(
      template: PlanTemplate.newBlood,
      daysPerWeek: 3,
    ));
    expect((await plans.activePlan())!.name, '新血计划');

    await plans.save(PlanGenerator.build(
      template: PlanTemplate.goodBehavior,
      daysPerWeek: 6,
    ));
    expect((await plans.activePlan())!.name, '好习惯计划');
    expect((await plans.all()).length, 2);
  });

  test('计划日程可以完整往返存取', () async {
    await plans.save(PlanGenerator.build(
      template: PlanTemplate.veteran,
      daysPerWeek: 6,
    ));

    final loaded = (await plans.activePlan())!;
    expect(loaded.days.length, 6);
    expect(loaded.daysPerWeek, 6);
    expect(loaded.targetLevel, TargetLevel.advanced);
    expect(loaded.setsPerExercise, 4);
    expect(loaded.days[1].exercises, const [BigSix.squat]);
    expect(loaded.dayFor(DateTime(2026, 10, 13)), isNotNull);
    expect(loaded.dayFor(DateTime(2026, 10, 18)), isNull);
  });

  test('停用计划后不再返回生效计划', () async {
    await plans.save(PlanGenerator.build(
      template: PlanTemplate.newBlood,
      daysPerWeek: 2,
    ));
    final active = (await plans.activePlan())!;

    await plans.save(TrainingPlan(
      id: active.id,
      name: active.name,
      template: active.template,
      targetLevel: active.targetLevel,
      setsPerExercise: active.setsPerExercise,
      startDate: active.startDate,
      active: false,
      days: active.days,
      createdAt: active.createdAt,
    ));

    expect(await plans.activePlan(), isNull);
    expect((await plans.all()).length, 1);
  });
}
