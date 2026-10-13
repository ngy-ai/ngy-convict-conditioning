import 'package:intl/intl.dart';

const _weekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isToday(DateTime date) => isSameDay(date, DateTime.now());

/// 10月12日
String formatMonthDay(DateTime date) => '${date.month}月${date.day}日';

/// 10月12日 周一
String formatMonthDayWeekday(DateTime date) =>
    '${formatMonthDay(date)} ${weekdayLabel(date.weekday)}';

/// 2026年10月12日 周一
String formatFullDate(DateTime date) =>
    '${date.year}年${date.month}月${date.day}日 ${weekdayLabel(date.weekday)}';

String weekdayLabel(int weekday) => _weekdayLabels[(weekday - 1) % 7];

/// 相对日期：今天 / 昨天 / 10月12日 周一
String formatRelativeDay(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (diff == 2) return '前天';
  return formatMonthDayWeekday(date);
}

/// 用于图表坐标轴：M/d
String formatShortDate(DateTime date) =>
    DateFormat('M/d').format(date);
