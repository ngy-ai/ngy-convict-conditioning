import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_utils.dart';
import '../../data/models/big_six.dart';
import '../../domain/workout_stats.dart';
import '../../providers/app_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_tile.dart';

/// 训练统计：总览、趋势、六艺分布。
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: statsAsync.when(
        data: (stats) {
          if (stats.sessionCount == 0) {
            return const EmptyState(
              icon: Icons.insights,
              title: '还没有可以统计的数据',
              message: '完成几次训练后，这里会显示训练量趋势和六艺分布。',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _OverviewCard(stats: stats),
              const SizedBox(height: 14),
              _TrendCard(stats: stats),
              const SizedBox(height: 14),
              _DistributionCard(stats: stats),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.stats});

  final WorkoutStats stats;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '总览',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${stats.sessionCount}',
                  unit: '次',
                  label: '训练次数',
                  compact: true,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: '${stats.trainedDays}',
                  unit: '天',
                  label: '训练天数',
                  compact: true,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: '${stats.streak}',
                  unit: '天',
                  label: '连续训练',
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${stats.totalSets}',
                  unit: '组',
                  label: '总组数',
                  compact: true,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: '${stats.totalVolume}',
                  unit: '次',
                  label: '总次数',
                  compact: true,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: '${stats.sessionsThisWeek}',
                  unit: '次',
                  label: '本周训练',
                  compact: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.stats});

  final WorkoutStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = stats.setsPerDay(days: 28).entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final maxSets = data.fold<int>(0, (a, e) => e.value > a ? e.value : a);
    final maxY = maxSets == 0 ? 10.0 : maxSets * 1.25;

    return SectionCard(
      title: '近 4 周训练量',
      subtitle: '每天完成的组数',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            barGroups: [
              for (var i = 0; i < data.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[i].value.toDouble(),
                      width: 6,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                      color: data[i].value == 0
                          ? theme.colorScheme.outline.withValues(alpha: 0.3)
                          : theme.colorScheme.primary,
                    ),
                  ],
                ),
            ],
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (value) => FlLine(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 7,
                  getTitlesWidget: (value, meta) {
                    final index = value.round();
                    if (index < 0 || index >= data.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        formatShortDate(data[index].key),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.stats});

  final WorkoutStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = {
      for (final exercise in BigSix.values) exercise: stats.setsOf(exercise),
    };
    final maxSets = values.values.fold<int>(0, (a, b) => a > b ? a : b);

    return SectionCard(
      title: '六艺训练分布',
      subtitle: '各艺累计完成的组数',
      child: Column(
        children: [
          for (final exercise in BigSix.values) ...[
            Row(
              children: [
                Icon(exercise.icon,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: Text(
                    exercise.label,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxSets == 0 ? 0 : values[exercise]! / maxSets,
                      minHeight: 8,
                      backgroundColor:
                          theme.colorScheme.outline.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 46,
                  child: Text(
                    '${values[exercise]} 组',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (exercise != BigSix.values.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
