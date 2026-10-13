import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/backup/backup_service.dart';
import '../data/db/app_database.dart';
import '../data/models/big_six.dart';
import '../data/models/training_plan.dart';
import '../data/models/workout_session.dart';
import '../data/repositories/plan_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../data/repositories/session_repository.dart';
import '../data/seed/big_six_seed.dart';
import '../domain/plan_generator.dart';
import '../domain/progression.dart';
import '../domain/workout_stats.dart';

// ───────────────────────── 基础设施 ─────────────────────────

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

final sessionRepositoryProvider =
    Provider((ref) => SessionRepository(ref.watch(databaseProvider)));

final progressRepositoryProvider =
    Provider((ref) => ProgressRepository(ref.watch(databaseProvider)));

final planRepositoryProvider =
    Provider((ref) => PlanRepository(ref.watch(databaseProvider)));

/// 备份的导出与恢复。
final backupServiceProvider =
    Provider((ref) => BackupService(ref.watch(databaseProvider)));

// ───────────────────────── 六艺进度 ─────────────────────────

class LevelsNotifier extends AsyncNotifier<Map<BigSix, int>> {
  @override
  Future<Map<BigSix, int>> build() =>
      ref.watch(progressRepositoryProvider).levels();

  Future<void> setLevel(BigSix exercise, int level) async {
    await ref.read(progressRepositoryProvider).setLevel(exercise, level);
    final current = state.value ?? {for (final e in BigSix.values) e: 1};
    state = AsyncData({...current, exercise: level.clamp(1, 10)});
  }
}

/// 六艺分别练到第几式。
final levelsProvider =
    AsyncNotifierProvider<LevelsNotifier, Map<BigSix, int>>(
        LevelsNotifier.new);

// ───────────────────────── 训练记录 ─────────────────────────

class SessionsNotifier extends AsyncNotifier<List<WorkoutSession>> {
  @override
  Future<List<WorkoutSession>> build() =>
      ref.watch(sessionRepositoryProvider).all();

  Future<void> save(WorkoutSession session) async {
    await ref.read(sessionRepositoryProvider).save(session);
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(int sessionId) async {
    await ref.read(sessionRepositoryProvider).delete(sessionId);
    ref.invalidateSelf();
    await future;
  }
}

/// 全部训练记录（日期倒序）。
final sessionsProvider =
    AsyncNotifierProvider<SessionsNotifier, List<WorkoutSession>>(
        SessionsNotifier.new);

/// 训练统计，随记录变更自动重算。
final statsProvider = FutureProvider<WorkoutStats>((ref) async {
  final sessions = await ref.watch(sessionsProvider.future);
  return WorkoutStats(sessions);
});

// ───────────────────────── 训练计划 ─────────────────────────

class ActivePlanNotifier extends AsyncNotifier<TrainingPlan?> {
  @override
  Future<TrainingPlan?> build() =>
      ref.watch(planRepositoryProvider).activePlan();

  Future<void> save(TrainingPlan plan) async {
    await ref.read(planRepositoryProvider).save(plan);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deactivate() async {
    final current = state.value;
    if (current == null || current.id == null) return;
    await ref.read(planRepositoryProvider).save(TrainingPlan(
          id: current.id,
          name: current.name,
          template: current.template,
          targetLevel: current.targetLevel,
          setsPerExercise: current.setsPerExercise,
          startDate: current.startDate,
          active: false,
          days: current.days,
          createdAt: current.createdAt,
        ));
    ref.invalidateSelf();
    await future;
  }
}

/// 当前生效的训练计划，未设置时为 null。
final activePlanProvider =
    AsyncNotifierProvider<ActivePlanNotifier, TrainingPlan?>(
        ActivePlanNotifier.new);

/// 今天要练的内容（已按用户当前所在式解析）。
final todayPlanProvider = FutureProvider<TodayPlan>((ref) async {
  final plan = await ref.watch(activePlanProvider.future);
  final levels = await ref.watch(levelsProvider.future);
  if (plan == null) return const TodayPlan.noPlan();

  final today = DateTime.now();
  final start = DateTime(plan.startDate.year, plan.startDate.month, plan.startDate.day);
  if (today.isBefore(start)) {
    return TodayPlan(label: '计划尚未开始', exercises: const []);
  }

  final day = plan.dayFor(today);
  if (day == null) {
    return TodayPlan(label: '今天休息', exercises: const [], isRest: true);
  }

  return TodayPlan(
    label: day.label,
    exercises: day.exercises,
    tasks: PlanGenerator.resolveTasks(
      exercises: day.exercises,
      plan: plan,
      levels: levels,
    ),
  );
});

/// 今天的训练安排。
class TodayPlan {
  const TodayPlan({
    required this.label,
    required this.exercises,
    this.tasks = const [],
    this.isRest = false,
    this.hasPlan = true,
  });

  const TodayPlan.noPlan()
      : label = '',
        exercises = const [],
        tasks = const [],
        isRest = false,
        hasPlan = false;

  final String label;
  final List<BigSix> exercises;
  final List<PlanTask> tasks;
  final bool isRest;
  final bool hasPlan;
}

// ───────────────────────── 六艺进度评估 ─────────────────────────

/// 某一艺的十式阶梯详情。
final exerciseDetailProvider =
    FutureProvider.family<ExerciseDetail, BigSix>((ref, exercise) async {
  final levels = await ref.watch(levelsProvider.future);
  final stats = await ref.watch(statsProvider.future);
  final currentLevel = levels[exercise] ?? 1;

  return ExerciseDetail(
    exercise: exercise,
    currentLevel: currentLevel,
    achievements: [
      for (final move in MoveCatalog.ladder(exercise))
        MoveAchievement(
          move: move,
          achieved: Progression.achievedLevel(
            move,
            stats.entriesByMove[move.id] ?? const [],
          ),
          totals: stats.totalsByMove[move.id],
        ),
    ],
  );
});

/// 六艺各自的训练进度（当前式、已达标准、建议目标）。
final moveProgressProvider =
    FutureProvider<Map<BigSix, MoveProgress>>((ref) async {
  final levels = await ref.watch(levelsProvider.future);
  final stats = await ref.watch(statsProvider.future);

  final result = <BigSix, MoveProgress>{};
  for (final exercise in BigSix.values) {
    final move = MoveCatalog.of(exercise, levels[exercise] ?? 1);
    result[exercise] = Progression.evaluate(
      move: move,
      recentEntries: stats.recentEntries(move.id),
      totals: stats.totalsByMove[move.id],
    );
  }
  return result;
});
