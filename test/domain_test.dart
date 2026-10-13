import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_convict_conditioning/data/models/big_six.dart';
import 'package:ngy_convict_conditioning/data/models/move.dart';
import 'package:ngy_convict_conditioning/data/models/training_plan.dart';
import 'package:ngy_convict_conditioning/data/models/workout_session.dart';
import 'package:ngy_convict_conditioning/data/seed/big_six_seed.dart';
import 'package:ngy_convict_conditioning/domain/plan_generator.dart';
import 'package:ngy_convict_conditioning/domain/progression.dart';
import 'package:ngy_convict_conditioning/domain/workout_stats.dart';

void main() {
  group('动作库', () {
    test('六艺各十式，共 60 式', () {
      expect(kAllMoves.length, 60);
      for (final exercise in BigSix.values) {
        expect(MoveCatalog.ladder(exercise).length, 10);
      }
    });

    test('按六艺与式可查询动作', () {
      final move = MoveCatalog.of(BigSix.pullup, 5);
      expect(move.name, '标准引体');
      expect(move.id, BigSix.pullup.index * 10 + 5);
      expect(MoveCatalog.byIdOrNull(move.id), same(move));
    });

    test('倒立撑前两式为计时动作', () {
      expect(MoveCatalog.of(BigSix.handstandPushup, 2).metric,
          MoveMetric.seconds);
      expect(MoveCatalog.of(BigSix.handstandPushup, 5).metric,
          MoveMetric.reps);
    });
  });

  group('进阶判定', () {
    final move = MoveCatalog.of(BigSix.pushup, 5);

    test('满足高级标准', () {
      final entries = [WorkoutEntry(moveId: move.id, sets: const [20, 20])];
      expect(Progression.meets(move, TargetLevel.advanced, entries), isTrue);
      expect(Progression.achievedLevel(move, entries), TargetLevel.advanced);
    });

    test('组数不足不算达标', () {
      final entries = [WorkoutEntry(moveId: move.id, sets: const [20])];
      expect(Progression.meets(move, TargetLevel.advanced, entries), isFalse);
    });

    test('单组未达高级标准时只算中级', () {
      final entries = [
        WorkoutEntry(moveId: move.id, sets: const [20, 12]),
      ];
      expect(Progression.meets(move, TargetLevel.advanced, entries), isFalse);
      expect(Progression.achievedLevel(move, entries), TargetLevel.intermediate);
    });

    test('未达标准时建议冲击初级标准', () {
      final progress = Progression.evaluate(
        move: move,
        recentEntries: [WorkoutEntry(moveId: move.id, sets: const [3, 3])],
      );
      expect(progress.achieved, isNull);
      expect(progress.suggested, TargetLevel.beginner);
      expect(progress.canAdvance, isFalse);
    });

    test('达成高级标准且非最终式时可进阶', () {
      final progress = Progression.evaluate(
        move: move,
        recentEntries: [
          WorkoutEntry(moveId: move.id, sets: const [20, 20, 20]),
        ],
      );
      expect(progress.canAdvance, isTrue);
      expect(progress.suggested, TargetLevel.advanced);
    });
  });

  group('训练统计', () {
    test('汇总组数、总量与单组最佳', () {
      final stats = WorkoutStats([
        WorkoutSession(
          date: DateTime(2026, 10, 1),
          entries: [
            WorkoutEntry(moveId: 5, sets: const [20, 18, 15]),
            WorkoutEntry(moveId: 55, sets: const [8, 6]),
          ],
        ),
      ]);

      expect(stats.sessionCount, 1);
      expect(stats.trainedDays, 1);
      expect(stats.totalSets, 5);
      expect(stats.totalVolume, 67);
      expect(stats.totalsByMove[5]!.bestSet, 20);
      expect(stats.setsOf(BigSix.pushup), 3);
      expect(stats.setsOf(BigSix.handstandPushup), 2);
    });

    test('按日期取当天记录', () {
      final stats = WorkoutStats([
        WorkoutSession(date: DateTime(2026, 10, 1), entries: const []),
        WorkoutSession(date: DateTime(2026, 9, 30), entries: const []),
      ]);
      expect(stats.sessionOn(DateTime(2026, 10, 1))?.date.day, 1);
      expect(stats.sessionOn(DateTime(2026, 9, 29)), isNull);
    });
  });

  group('计划生成', () {
    test('新血计划每周 3 练，六艺全练', () {
      final plan = PlanGenerator.build(
        template: PlanTemplate.newBlood,
        daysPerWeek: 3,
      );
      expect(plan.daysPerWeek, 3);
      expect(plan.days.length, 1);
      expect(plan.days.first.exercises.length, 6);
    });

    test('好习惯计划推拉交替', () {
      final plan = PlanGenerator.build(
        template: PlanTemplate.goodBehavior,
        daysPerWeek: 6,
      );
      expect(plan.daysPerWeek, 6);
      expect(plan.days.length, 2);
      expect(plan.days[0].exercises.contains(BigSix.pullup), isFalse);
      expect(plan.days[1].exercises.contains(BigSix.pullup), isTrue);
    });

    test('老手计划每天专攻一艺', () {
      final plan = PlanGenerator.build(
        template: PlanTemplate.veteran,
        daysPerWeek: 6,
      );
      expect(plan.days.length, 6);
      for (final day in plan.days) {
        expect(day.exercises.length, 1);
      }
    });

    test('任务按用户当前所在式解析', () {
      final plan = PlanGenerator.build(
        template: PlanTemplate.newBlood,
        daysPerWeek: 3,
      );
      final tasks = PlanGenerator.resolveTasks(
        exercises: plan.days.first.exercises,
        plan: plan,
        levels: {for (final e in BigSix.values) e: 3},
      );
      expect(tasks.first.move.level, 3);
      expect(tasks.first.sets, plan.setsPerExercise);
      expect(tasks.first.targetValue,
          tasks.first.move.standard.of(plan.targetLevel).value);
    });

    test('今天属于哪个训练日', () {
      final plan = PlanGenerator.build(
        template: PlanTemplate.newBlood,
        daysPerWeek: 3,
      );
      // 周一、周三、周五训练
      expect(plan.dayFor(DateTime(2026, 10, 12))?.label, '全身 · 六艺');
      expect(plan.dayFor(DateTime(2026, 10, 13)), isNull);
    });
  });
}
