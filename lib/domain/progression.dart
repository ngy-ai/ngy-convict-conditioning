import '../data/models/big_six.dart';
import '../data/models/move.dart';
import '../data/models/workout_session.dart';
import 'workout_stats.dart';

/// 某一式的训练进度评估结果。
class MoveProgress {
  const MoveProgress({
    required this.move,
    required this.achieved,
    required this.suggested,
    required this.totalSets,
    required this.totalVolume,
    required this.bestSet,
  });

  final Move move;

  /// 最近训练中已达到的最高标准，未达到初级标准时为 null。
  final TargetLevel? achieved;

  /// 建议下次冲击的标准。
  final TargetLevel suggested;

  final int totalSets;
  final int totalVolume;

  /// 单组最好成绩。
  final int bestSet;

  SetTarget get suggestedTarget => move.standard.of(suggested);

  /// 是否已经满足进阶条件（达到当前式的高级标准且还有下一式）。
  bool get canAdvance => achieved == TargetLevel.advanced && !move.isLast;

  /// 距离建议目标还差多少（次数），用于训练页提示。
  String get targetLabel =>
      '${suggested.label}标准 ${suggestedTarget.describe(move.metric)}';
}

/// 进阶判定：把训练记录与动作标准比对。
class Progression {
  Progression._();

  /// 达到某个标准的判定：训练中至少有一组记录同时满足组数与每组次数。
  static bool meets(Move move, TargetLevel level, List<WorkoutEntry> entries) {
    final target = move.standard.of(level);
    return entries.any((entry) =>
        entry.setCount >= target.sets &&
        entry.sets.every((value) => value >= target.value));
  }

  /// 已达到的最高标准等级，未达到初级标准时为 null。
  static TargetLevel? achievedLevel(Move move, List<WorkoutEntry> entries) {
    for (final level in [
      TargetLevel.advanced,
      TargetLevel.intermediate,
      TargetLevel.beginner,
    ]) {
      if (meets(move, level, entries)) return level;
    }
    return null;
  }

  static MoveProgress evaluate({
    required Move move,
    required List<WorkoutEntry> recentEntries,
    MoveTotals? totals,
  }) {
    final achieved = achievedLevel(move, recentEntries);

    final suggested = switch (achieved) {
      null => TargetLevel.beginner,
      TargetLevel.beginner => TargetLevel.intermediate,
      TargetLevel.intermediate => TargetLevel.advanced,
      TargetLevel.advanced => TargetLevel.advanced,
    };

    return MoveProgress(
      move: move,
      achieved: achieved,
      suggested: suggested,
      totalSets: totals?.sets ?? 0,
      totalVolume: totals?.volume ?? 0,
      bestSet: totals?.bestSet ?? 0,
    );
  }
}

/// 某一式的历史达成情况（十式阶梯展示用）。
class MoveAchievement {
  const MoveAchievement({
    required this.move,
    required this.achieved,
    this.totals,
  });

  final Move move;
  final TargetLevel? achieved;
  final MoveTotals? totals;

  int get totalSets => totals?.sets ?? 0;
  int get totalVolume => totals?.volume ?? 0;
  int get bestSet => totals?.bestSet ?? 0;

  bool get trained => totalSets > 0;
}

/// 某一艺的完整进度：当前所在式 + 十式各自的达成情况。
class ExerciseDetail {
  const ExerciseDetail({
    required this.exercise,
    required this.currentLevel,
    required this.achievements,
  });

  final BigSix exercise;
  final int currentLevel;
  final List<MoveAchievement> achievements;

  MoveAchievement get current => achievements.firstWhere(
        (a) => a.move.level == currentLevel,
        orElse: () => achievements.first,
      );
}
