import '../data/models/big_six.dart';
import '../data/models/workout_session.dart';

/// 单个动作（式）的累计统计。
class MoveTotals {
  const MoveTotals({
    required this.sets,
    required this.volume,
    required this.bestSet,
  });

  final int sets;
  final int volume;
  final int bestSet;
}

/// 基于训练记录在内存中计算各类统计。
///
/// 个人训练数据量很小，直接遍历即可，也让 UI 能随记录变更自动刷新。
class WorkoutStats {
  WorkoutStats(List<WorkoutSession> sessions)
      : sessions = List.unmodifiable(sessions);

  /// 已按日期倒序排列。
  final List<WorkoutSession> sessions;

  int get sessionCount => sessions.length;

  /// 有训练记录的天数。
  int get trainedDays => sessions
      .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
      .toSet()
      .length;

  int get totalSets => sessions.fold(0, (a, s) => a + s.totalSets);

  int get totalVolume => sessions.fold(0, (a, s) => a + s.totalVolume);

  /// 每个式的累计组数 / 总次数 / 单组最佳。
  Map<int, MoveTotals> get totalsByMove {
    final result = <int, MoveTotals>{};
    for (final session in sessions) {
      for (final entry in session.entries) {
        final current = result[entry.moveId];
        result[entry.moveId] = MoveTotals(
          sets: (current?.sets ?? 0) + entry.setCount,
          volume: (current?.volume ?? 0) + entry.volume,
          bestSet: _max(current?.bestSet ?? 0, entry.bestValue),
        );
      }
    }
    return result;
  }

  /// 每个式的训练明细，按时间倒序（sessions 已倒序）。
  Map<int, List<WorkoutEntry>> get entriesByMove {
    final result = <int, List<WorkoutEntry>>{};
    for (final session in sessions) {
      for (final entry in session.entries) {
        result.putIfAbsent(entry.moveId, () => []).add(entry);
      }
    }
    return result;
  }

  List<WorkoutEntry> recentEntries(int moveId, {int limit = 5}) {
    final list = entriesByMove[moveId] ?? const <WorkoutEntry>[];
    return list.take(limit).toList();
  }

  /// 某个日期（仅日期）的训练记录。
  WorkoutSession? sessionOn(DateTime date) {
    for (final session in sessions) {
      if (_isSameDay(session.date, date)) return session;
    }
    return null;
  }

  /// 最近 [days] 天每天完成的组数（没有训练的日子为 0）。
  Map<DateTime, int> setsPerDay({int days = 28}) {
    final today = _today();
    final start = today.subtract(Duration(days: days - 1));
    final result = {
      for (var i = 0; i < days; i++)
        start.add(Duration(days: i)): 0,
    };
    for (final session in sessions) {
      final key = DateTime(session.date.year, session.date.month, session.date.day);
      if (result.containsKey(key)) {
        result[key] = result[key]! + session.totalSets;
      }
    }
    return result;
  }

  /// 每周训练次数（本周从周一开始）。
  int get sessionsThisWeek {
    final today = _today();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return sessions
        .where((s) => !s.date.isBefore(monday) && !s.date.isAfter(today))
        .length;
  }

  /// 连续训练天数（含今天；今天没练则从昨天往前算）。
  int get streak {
    if (sessions.isEmpty) return 0;
    final days = sessions
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet();
    var cursor = _today();
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// 某一艺的累计组数。
  int setsOf(BigSix exercise) {
    var total = 0;
    for (var level = 1; level <= 10; level++) {
      final id = exercise.index * 10 + level;
      total += totalsByMove[id]?.sets ?? 0;
    }
    return total;
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _max(int a, int b) => a > b ? a : b;
}
