import 'dart:convert';

import '../models/big_six.dart';
import '../models/move.dart';
import '../models/training_plan.dart';
import '../models/workout_session.dart';

/// 备份文件标识与格式版本。格式不兼容地变化时递增 [backupFormatVersion]。
const String backupAppId = 'ngy_convict_conditioning';
const int backupFormatVersion = 1;

/// 备份文件无法解析时抛出，[message] 直接展示给用户。
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 一次备份的全部内容：训练记录、六艺进度、训练计划。
///
/// 只存业务字段，不含数据库自增 id —— 恢复时重新分配，避免与现有数据撞号。
class BackupData {
  BackupData({
    required this.exportedAt,
    required this.sessions,
    required this.levels,
    required this.plans,
  });

  final DateTime exportedAt;
  final List<WorkoutSession> sessions;

  /// 六艺当前所在式（未记录的为第 1 式）。
  final Map<BigSix, int> levels;
  final List<TrainingPlan> plans;

  int get sessionCount => sessions.length;
  int get entryCount => sessions.fold(0, (sum, s) => sum + s.entries.length);
  int get setCount => sessions.fold(0, (sum, s) => sum + s.totalSets);
  int get planCount => plans.length;

  /// 六艺里已经练到第 2 式及以上的数量。
  int get progressedCount => levels.values.where((level) => level > 1).length;

  bool get isEmpty =>
      sessions.isEmpty && plans.isEmpty && progressedCount == 0;

  Map<String, Object?> toJson() => {
        'app': backupAppId,
        'version': backupFormatVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'sessions': [
          for (final session in sessions) _sessionToJson(session),
        ],
        'progress': [
          for (final entry in levels.entries)
            {'exercise': entry.key.name, 'level': entry.value},
        ],
        'plans': [
          for (final plan in plans) _planToJson(plan),
        ],
      };

  /// 带缩进的 JSON 文本，方便用户直接看/改。
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// 解析备份文本，格式不对时抛 [BackupFormatException]。
  static BackupData decode(String source) {
    final Object? raw;
    try {
      raw = jsonDecode(source);
    } on FormatException catch (error) {
      throw BackupFormatException('不是有效的 JSON 文件：${error.message}');
    }

    final json = _asMap(raw, '备份内容');
    final app = json['app'];
    if (app is String && app != backupAppId) {
      throw BackupFormatException('这不是本应用的备份文件（app = $app）');
    }

    final version = json['version'];
    if (version is! int) {
      throw BackupFormatException('备份文件缺少版本号（version）');
    }
    if (version > backupFormatVersion) {
      throw BackupFormatException(
        '备份文件版本为 $version，高于当前应用支持的 $backupFormatVersion，'
        '请升级应用后再导入',
      );
    }

    final rawSessions = json['sessions'];
    final rawProgress = json['progress'];
    final rawPlans = json['plans'];
    if (rawSessions is! List && rawProgress is! List && rawPlans is! List) {
      throw const BackupFormatException('备份文件里没有 sessions / progress / plans');
    }

    final sessionList = rawSessions is List ? rawSessions : const <Object?>[];
    final planList = rawPlans is List ? rawPlans : const <Object?>[];

    return BackupData(
      exportedAt: _asDateOrNull(json['exportedAt']) ?? DateTime.now(),
      sessions: [
        for (var i = 0; i < sessionList.length; i++)
          _sessionFromJson(
            _asMap(sessionList[i], '第 ${i + 1} 条训练记录'),
            i + 1,
          ),
      ],
      levels: _levelsFromJson(rawProgress),
      plans: [
        for (var i = 0; i < planList.length; i++)
          _planFromJson(_asMap(planList[i], '第 ${i + 1} 个计划'), i + 1),
      ],
    );
  }

  /// 备份文件名，例如 `convict-conditioning-2026-10-13.json`。
  static String fileNameFor(DateTime date) =>
      'convict-conditioning-${WorkoutSession.formatDate(date)}.json';
}

// ───────────────────────── 序列化 ─────────────────────────

Map<String, Object?> _sessionToJson(WorkoutSession session) => {
      'date': WorkoutSession.formatDate(session.date),
      'note': session.note,
      'createdAt': session.createdAt.toIso8601String(),
      'entries': [
        for (final entry in session.entries)
          {
            'moveId': entry.moveId,
            'sets': entry.sets,
            'note': entry.note,
          },
      ],
    };

Map<String, Object?> _planToJson(TrainingPlan plan) => {
      'name': plan.name,
      'template': plan.template.name,
      'targetLevel': plan.targetLevel.name,
      'setsPerExercise': plan.setsPerExercise,
      'startDate': WorkoutSession.formatDate(plan.startDate),
      'active': plan.active,
      'createdAt': plan.createdAt.toIso8601String(),
      'days': [for (final day in plan.days) day.toJson()],
    };

WorkoutSession _sessionFromJson(Map<String, Object?> json, int index) {
  final where = '第 $index 条训练记录';
  final rawEntries = json['entries'] ?? const [];
  final entries = _asList(rawEntries, '$where的 entries');
  return WorkoutSession(
    date: _asDate(json['date'], '$where的 date'),
    note: _asStringOrNull(json['note']),
    createdAt: _asDateOrNull(json['createdAt']) ?? DateTime.now(),
    entries: [
      for (var i = 0; i < entries.length; i++)
        _entryFromJson(
          _asMap(entries[i], '$where第 ${i + 1} 个动作'),
          '$where第 ${i + 1} 个动作',
        ),
    ],
  );
}

WorkoutEntry _entryFromJson(Map<String, Object?> json, String where) {
  final rawSets = _asList(json['sets'], '$where的 sets');
  final sets = [for (final value in rawSets) _asInt(value, '$where的 sets')];
  if (sets.isEmpty) {
    throw BackupFormatException('$where没有记录任何组数');
  }
  return WorkoutEntry(
    moveId: _asInt(json['moveId'], '$where的 moveId'),
    sets: sets,
    note: _asStringOrNull(json['note']),
  );
}

Map<BigSix, int> _levelsFromJson(Object? raw) {
  final levels = {for (final exercise in BigSix.values) exercise: 1};
  for (final value in _asList(raw ?? const [], 'progress')) {
    final json = _asMap(value, 'progress 中的一条进度');
    final name = _asString(json['exercise'], 'progress.exercise');
    final matches = BigSix.values.where((e) => e.name == name);
    if (matches.isEmpty) continue; // 未知六艺（手改的文件）忽略
    levels[matches.first] = _asInt(json['level'], 'progress.level').clamp(1, 10);
  }
  return levels;
}

TrainingPlan _planFromJson(Map<String, Object?> json, int index) {
  final where = '第 $index 个计划';
  final name = _asString(json['name'], '$where的 name');
  final templateName = _asStringOrNull(json['template']);
  final levelName = _asStringOrNull(json['targetLevel']);
  final days = _asList(json['days'] ?? const [], '$where的 days');

  return TrainingPlan(
    name: name,
    template: PlanTemplate.values.firstWhere(
      (e) => e.name == templateName,
      orElse: () => PlanTemplate.custom,
    ),
    targetLevel: TargetLevel.values.firstWhere(
      (e) => e.name == levelName,
      orElse: () => TargetLevel.intermediate,
    ),
    setsPerExercise:
        (_asIntOrNull(json['setsPerExercise']) ?? 3).clamp(1, 20),
    startDate: _asDate(json['startDate'], '$where的 startDate'),
    active: json['active'] is bool ? json['active']! as bool : true,
    createdAt: _asDateOrNull(json['createdAt']) ?? DateTime.now(),
    days: [
      for (var i = 0; i < days.length; i++)
        PlanDay.fromJson(_asMap(days[i], '$where第 ${i + 1} 天日程')),
    ],
  );
}

// ───────────────────────── 取值校验 ─────────────────────────

Map<String, Object?> _asMap(Object? value, String where) {
  if (value is Map) return value.cast<String, Object?>();
  throw BackupFormatException('$where 应该是对象，实际是 ${_typeName(value)}');
}

List<Object?> _asList(Object? value, String where) {
  if (value is List) return value;
  throw BackupFormatException('$where 应该是数组，实际是 ${_typeName(value)}');
}

int _asInt(Object? value, String where) {
  final result = _asIntOrNull(value);
  if (result == null) {
    throw BackupFormatException('$where 应该是整数，实际是 ${_typeName(value)}');
  }
  return result;
}

int? _asIntOrNull(Object? value) => value is num ? value.toInt() : null;

String _asString(Object? value, String where) {
  if (value is String && value.isNotEmpty) return value;
  throw BackupFormatException('$where 应该是文本，实际是 ${_typeName(value)}');
}

String? _asStringOrNull(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

DateTime _asDate(Object? value, String where) {
  final result = _asDateOrNull(value);
  if (result == null) {
    throw BackupFormatException('$where 不是合法日期：${_typeName(value)}');
  }
  return result;
}

DateTime? _asDateOrNull(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

String _typeName(Object? value) => value == null ? '空值' : '${value.runtimeType}';
