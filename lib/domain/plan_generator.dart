import '../data/models/big_six.dart';
import '../data/models/move.dart';
import '../data/models/training_plan.dart';
import '../data/seed/big_six_seed.dart';

/// 训练计划生成器。
///
/// 计划只保存「每周哪几天练哪几艺 + 目标等级」，
/// 具体动作在运行时按用户当前所在式解析，升级后计划会自动跟随。
class PlanGenerator {
  PlanGenerator._();

  static const _pushDay = [
    BigSix.pushup,
    BigSix.handstandPushup,
    BigSix.legRaise,
  ];
  static const _pullDay = [
    BigSix.pullup,
    BigSix.squat,
    BigSix.bridge,
  ];

  static TrainingPlan build({
    required PlanTemplate template,
    required int daysPerWeek,
    TargetLevel? targetLevel,
    int? setsPerExercise,
    DateTime? startDate,
    List<PlanDay>? customDays,
    String? name,
  }) {
    final days = switch (template) {
      PlanTemplate.newBlood => _newBloodDays(daysPerWeek),
      PlanTemplate.goodBehavior => _goodBehaviorDays(daysPerWeek),
      PlanTemplate.veteran => _veteranDays(daysPerWeek),
      PlanTemplate.custom => customDays ?? _newBloodDays(daysPerWeek),
    };

    final isVeteran = template == PlanTemplate.veteran;
    final sets = setsPerExercise ?? (isVeteran ? 4 : 3);
    return TrainingPlan(
      name: name ?? '${template.label}计划',
      template: template,
      targetLevel: targetLevel ??
          (isVeteran ? TargetLevel.advanced : TargetLevel.intermediate),
      setsPerExercise: isVeteran && sets < 4 ? 4 : sets,
      startDate: startDate ?? DateTime.now(),
      days: days,
      createdAt: DateTime.now(),
    );
  }

  /// 新血：每次训练六艺全练。
  static List<PlanDay> _newBloodDays(int daysPerWeek) => [
        PlanDay(
          label: '全身 · 六艺',
          weekdays: weekdaysFor(daysPerWeek),
          exercises: BigSix.values,
        ),
      ];

  /// 好习惯：推类与拉类交替。
  static List<PlanDay> _goodBehaviorDays(int daysPerWeek) {
    final weekdays = weekdaysFor(daysPerWeek);
    final pushDays = <int>[];
    final pullDays = <int>[];
    for (var i = 0; i < weekdays.length; i++) {
      if (i.isEven) {
        pushDays.add(weekdays[i]);
      } else {
        pullDays.add(weekdays[i]);
      }
    }
    return [
      PlanDay(
        label: 'A · 推与核心',
        weekdays: pushDays,
        exercises: _pushDay,
      ),
      PlanDay(
        label: 'B · 拉与腿',
        weekdays: pullDays,
        exercises: _pullDay,
      ),
    ];
  }

  /// 老手：每天专攻一艺。
  static List<PlanDay> _veteranDays(int daysPerWeek) {
    final weekdays = weekdaysFor(daysPerWeek);
    return [
      for (var i = 0; i < weekdays.length; i++)
        PlanDay(
          label: '${BigSix.values[i % BigSix.values.length].label}专项',
          weekdays: [weekdays[i]],
          exercises: [BigSix.values[i % BigSix.values.length]],
        ),
    ];
  }

  /// 把「每周练几天」翻译成星期几，尽量让训练日均匀分布。
  static List<int> weekdaysFor(int daysPerWeek) => switch (daysPerWeek) {
        1 => const [1],
        2 => const [2, 5],
        3 => const [1, 3, 5],
        4 => const [1, 2, 4, 5],
        5 => const [1, 2, 3, 4, 5],
        7 => const [1, 2, 3, 4, 5, 6, 7],
        _ => const [1, 2, 3, 4, 5, 6],
      };

  /// 把计划日程解析成具体任务：用户当前所在式 + 目标组数/次数。
  static List<PlanTask> resolveTasks({
    required List<BigSix> exercises,
    required TrainingPlan plan,
    required Map<BigSix, int> levels,
  }) =>
      [
        for (final exercise in exercises)
          () {
            final move =
                MoveCatalog.of(exercise, levels[exercise] ?? 1);
            return PlanTask(
              exercise: exercise,
              move: move,
              sets: plan.setsPerExercise,
              targetValue: move.standard.of(plan.targetLevel).value,
            );
          }(),
      ];
}
