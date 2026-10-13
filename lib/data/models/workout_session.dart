import 'dart:convert';

/// 一次训练中针对某一式所做的若干组。
class WorkoutEntry {
  WorkoutEntry({
    this.id,
    this.sessionId,
    required this.moveId,
    required List<int> sets,
    this.note,
    this.orderIndex = 0,
  }) : sets = List.unmodifiable(sets);

  final int? id;
  final int? sessionId;
  final int moveId;

  /// 每组完成的次数（计时动作为秒数）。
  final List<int> sets;
  final String? note;
  final int orderIndex;

  int get setCount => sets.length;
  int get volume => sets.fold(0, (a, b) => a + b);
  int get bestValue => sets.isEmpty ? 0 : sets.reduce((a, b) => a > b ? a : b);

  WorkoutEntry copyWith({int? id, int? sessionId, int? orderIndex}) =>
      WorkoutEntry(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        moveId: moveId,
        sets: sets,
        note: note,
        orderIndex: orderIndex ?? this.orderIndex,
      );

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        if (sessionId != null) 'session_id': sessionId,
        'move_id': moveId,
        'order_index': orderIndex,
        'sets_json': jsonEncode(sets),
        'note': note,
      };

  factory WorkoutEntry.fromRow(Map<String, Object?> row) => WorkoutEntry(
        id: row['id'] as int,
        sessionId: row['session_id'] as int,
        moveId: row['move_id'] as int,
        sets: (jsonDecode(row['sets_json'] as String) as List)
            .map((e) => (e as num).toInt())
            .toList(),
        note: row['note'] as String?,
        orderIndex: (row['order_index'] as int?) ?? 0,
      );
}

/// 一次训练记录，可包含多个动作（式）。
class WorkoutSession {
  WorkoutSession({
    this.id,
    required DateTime date,
    this.note,
    DateTime? createdAt,
    List<WorkoutEntry> entries = const [],
  })  : date = DateTime(date.year, date.month, date.day),
        createdAt = createdAt ?? DateTime.now(),
        entries = List.unmodifiable(entries);

  final int? id;

  /// 训练日期（仅日期有意义）。
  final DateTime date;
  final String? note;
  final DateTime createdAt;
  final List<WorkoutEntry> entries;

  int get totalSets => entries.fold(0, (a, e) => a + e.setCount);
  int get totalVolume => entries.fold(0, (a, e) => a + e.volume);

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'date': formatDate(date),
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory WorkoutSession.fromRow(
    Map<String, Object?> row, {
    List<WorkoutEntry> entries = const [],
  }) =>
      WorkoutSession(
        id: row['id'] as int,
        date: DateTime.parse(row['date'] as String),
        note: row['note'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        entries: entries,
      );

  static String formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
