import 'big_six.dart';

/// 计量方式：计次或计时。
enum MoveMetric {
  reps('次'),
  seconds('秒');

  const MoveMetric(this.unit);

  final String unit;
}

/// 进阶目标等级。
enum TargetLevel {
  beginner('初级'),
  intermediate('中级'),
  advanced('高级');

  const TargetLevel(this.label);

  final String label;
}

/// 单一标准：组数 × 每组次数（或秒数）。
class SetTarget {
  const SetTarget(this.sets, this.value);

  final int sets;
  final int value;

  String describe(MoveMetric metric) => '$sets 组 × $value${metric.unit}';

  @override
  String toString() => '$sets×$value';
}

/// 一式的三级标准（参考《囚徒健身》给出的晋级标准）。
class ProgressionStandard {
  const ProgressionStandard({
    required this.beginner,
    required this.intermediate,
    required this.advanced,
  });

  final SetTarget beginner;
  final SetTarget intermediate;
  final SetTarget advanced;

  SetTarget of(TargetLevel level) => switch (level) {
        TargetLevel.beginner => beginner,
        TargetLevel.intermediate => intermediate,
        TargetLevel.advanced => advanced,
      };
}

/// 一式：六艺中某一门的某一个进阶动作（1~10 式）。
class Move {
  const Move({
    required this.id,
    required this.exercise,
    required this.level,
    required this.name,
    required this.nameEn,
    required this.cue,
    required this.guide,
    required this.metric,
    required this.standard,
  });

  /// 全局唯一 ID，规则：exercise.index * 10 + level。
  final int id;
  final BigSix exercise;

  /// 第几式，1~10。
  final int level;
  final String name;
  final String nameEn;

  /// 动作要领提示（一句话）。
  final String cue;

  /// 训练指导：起始姿势、关键细节与进阶提示。
  final String guide;
  final MoveMetric metric;
  final ProgressionStandard standard;

  bool get isLast => level >= 10;

  String get displayName => '第$level式 · $name';
}
