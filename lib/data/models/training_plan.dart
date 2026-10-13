import 'dart:convert';

import 'big_six.dart';
import 'move.dart';

/// 计划模板：新血 / 好习惯 / 老手 / 自定义。
enum PlanTemplate {
  newBlood('新血', '每周 3 练，六艺全练，适合入门打基础'),
  goodBehavior('好习惯', '每周 6 练，推拉分组交替，适合稳定进阶'),
  veteran('老手', '每周 6 练，每日专攻一艺，冲击最高标准'),
  custom('自定义', '自由选择每周训练天数与动作');

  const PlanTemplate(this.label, this.description);

  final String label;
  final String description;
}

/// 计划中的一天日程：在哪些星期几练哪些艺。
class PlanDay {
  const PlanDay({
    required this.label,
    required this.weekdays,
    required this.exercises,
  });

  final String label;

  /// 星期，1 = 周一 ... 7 = 周日。
  final List<int> weekdays;
  final List<BigSix> exercises;

  Map<String, Object?> toJson() => {
        'label': label,
        'weekdays': weekdays,
        'exercises': exercises.map((e) => e.name).toList(),
      };

  factory PlanDay.fromJson(Map<String, Object?> json) => PlanDay(
        label: json['label'] as String,
        weekdays:
            (json['weekdays'] as List).map((e) => (e as num).toInt()).toList(),
        exercises: (json['exercises'] as List)
            .map((e) => BigSix.fromName(e as String))
            .toList(),
      );
}

/// 训练计划。
class TrainingPlan {
  const TrainingPlan({
    this.id,
    required this.name,
    required this.template,
    required this.targetLevel,
    required this.setsPerExercise,
    required this.startDate,
    this.active = true,
    required this.days,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final PlanTemplate template;
  final TargetLevel targetLevel;

  /// 每个动作做几组。
  final int setsPerExercise;
  final DateTime startDate;
  final bool active;
  final List<PlanDay> days;
  final DateTime createdAt;

  int get daysPerWeek => days.fold(0, (a, d) => a + d.weekdays.length);

  /// 返回今天的日程，若今天休息则返回 null。
  PlanDay? dayFor(DateTime date) {
    final weekday = date.weekday;
    for (final day in days) {
      if (day.weekdays.contains(weekday)) return day;
    }
    return null;
  }

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'name': name,
        'template': template.name,
        'target_level': targetLevel.name,
        'sets_per_exercise': setsPerExercise,
        'start_date': WorkoutSessionDate.format(startDate),
        'active': active ? 1 : 0,
        'days_json': jsonEncode(days.map((d) => d.toJson()).toList()),
        'created_at': createdAt.toIso8601String(),
      };

  factory TrainingPlan.fromRow(Map<String, Object?> row) => TrainingPlan(
        id: row['id'] as int,
        name: row['name'] as String,
        template: PlanTemplate.values.firstWhere(
            (e) => e.name == row['template'],
            orElse: () => PlanTemplate.custom),
        targetLevel: TargetLevel.values.firstWhere(
            (e) => e.name == row['target_level'],
            orElse: () => TargetLevel.intermediate),
        setsPerExercise: (row['sets_per_exercise'] as int?) ?? 3,
        startDate: DateTime.parse(row['start_date'] as String),
        active: ((row['active'] as int?) ?? 1) == 1,
        days: (jsonDecode(row['days_json'] as String) as List)
            .map((e) => PlanDay.fromJson((e as Map).cast<String, Object?>()))
            .toList(),
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}

/// 日期格式化工具，避免模型层依赖 intl。
class WorkoutSessionDate {
  static String format(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// 计划解析出的一个待完成动作：用用户当前所在式 + 目标组数/次数。
class PlanTask {
  const PlanTask({
    required this.exercise,
    required this.move,
    required this.sets,
    required this.targetValue,
  });

  final BigSix exercise;
  final Move move;
  final int sets;
  final int targetValue;

  MoveMetric get metric => move.metric;

  String get targetLabel =>
      '$sets 组 × $targetValue${metric.unit}';
}
