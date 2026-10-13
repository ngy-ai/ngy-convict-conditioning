import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/date_utils.dart';
import '../../data/models/move.dart';
import '../../data/models/workout_session.dart';
import '../../data/seed/big_six_seed.dart';
import '../../providers/app_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_tile.dart';
import '../train/train_page.dart';

/// 一次训练的明细，可编辑或删除。
class SessionDetailPage extends ConsumerWidget {
  const SessionDetailPage({super.key, this.sessionId});

  final int? sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final sessions = sessionsAsync.value ?? const <WorkoutSession>[];
    WorkoutSession? session;
    for (final item in sessions) {
      if (item.id == sessionId) {
        session = item;
        break;
      }
    }

    if (sessionsAsync.isLoading && session == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('训练详情')),
        body: const EmptyState(
          icon: Icons.search_off,
          title: '记录不存在',
          message: '这条记录可能已经被删除。',
        ),
      );
    }

    final current = session;
    return Scaffold(
      appBar: AppBar(
        title: const Text('训练详情'),
        actions: [
          IconButton(
            tooltip: '编辑',
            onPressed: () => context.push(
              '/train',
              extra: TrainIntent(session: current),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: () => _confirmDelete(context, ref, current),
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatFullDate(current.date),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (current.note != null && current.note!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    current.note!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        value: '${current.entries.length}',
                        unit: '个',
                        label: '动作',
                        compact: true,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value: '${current.totalSets}',
                        unit: '组',
                        label: '总组数',
                        compact: true,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value: '${current.totalVolume}',
                        unit: '次',
                        label: '总次数',
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final entry in current.entries) ...[
            _EntryCard(entry: entry),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WorkoutSession session,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确定删除 ${formatMonthDay(session.date)} 的这次训练记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || session.id == null) return;
    await ref.read(sessionsProvider.notifier).remove(session.id!);
    if (!context.mounted) return;
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('已删除记录')));
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final WorkoutEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final move = MoveCatalog.byIdOrNull(entry.moveId);
    final unit = move?.metric.unit ?? '次';

    return SectionCard(
      title: move == null ? '未知动作' : '${move.exercise.label} · ${move.name}',
      subtitle: move == null
          ? null
          : '第${move.level}式 · 高级标准 ${move.standard.advanced.describe(move.metric)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < entry.sets.length; i++)
                _SetChip(
                  index: i,
                  value: entry.sets[i],
                  unit: unit,
                  achieved: move == null
                      ? null
                      : _achievedLabel(move, entry.sets[i]),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${entry.setCount} 组 · 共 ${entry.volume} $unit · 单组最佳 ${entry.bestValue} $unit',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String? _achievedLabel(Move move, int value) {
    for (final level in [TargetLevel.advanced, TargetLevel.intermediate]) {
      if (value >= move.standard.of(level).value) return level.label;
    }
    return null;
  }
}

class _SetChip extends StatelessWidget {
  const _SetChip({
    required this.index,
    required this.value,
    required this.unit,
    this.achieved,
  });

  final int index;
  final int value;
  final String unit;
  final String? achieved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reached = achieved != null;
    final isAdvanced = achieved == '高级';

    final color = !reached
        ? theme.colorScheme.outline
        : isAdvanced
            ? theme.colorScheme.primary
            : theme.colorScheme.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: reached ? color.withValues(alpha: 0.12) : null,
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value $unit',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: reached ? color : theme.colorScheme.onSurface,
            ),
          ),
          Text(
            '第${index + 1}组',
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }
}
