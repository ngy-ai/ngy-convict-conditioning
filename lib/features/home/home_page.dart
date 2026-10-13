import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/date_utils.dart';
import '../../data/models/workout_session.dart';
import '../../data/seed/big_six_seed.dart';
import '../../domain/workout_stats.dart';
import '../../providers/app_providers.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/theme_picker.dart';
import '../train/train_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider).value;
    final todayPlan = ref.watch(todayPlanProvider);
    final sessions = ref.watch(sessionsProvider).value ?? const [];
    final themeMode = ref.watch(themeModeProvider);
    final todaySessions =
        sessions.where((s) => isToday(s.date)).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日训练'),
        actions: [
          IconButton(
            tooltip: '原书阅读',
            onPressed: () => context.push('/book'),
            icon: const Icon(Icons.menu_book_outlined),
          ),
          IconButton(
            tooltip: '数据备份',
            onPressed: () => context.push('/backup'),
            icon: const Icon(Icons.backup_outlined),
          ),
          IconButton(
            tooltip: '切换皮肤',
            onPressed: () => showThemePicker(context),
            icon: Icon(switch (themeMode) {
              ThemeMode.system => Icons.brightness_auto_outlined,
              ThemeMode.light => Icons.light_mode_outlined,
              ThemeMode.dark => Icons.dark_mode_outlined,
            }),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: () {
              ref.invalidate(sessionsProvider);
              ref.invalidate(levelsProvider);
              ref.invalidate(activePlanProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _HeaderCard(stats: stats),
          const SizedBox(height: 14),
          todayPlan.when(
            data: (plan) => _TodayPlanCard(plan: plan),
            loading: () => const _LoadingCard(),
            error: (error, _) => _ErrorCard(message: '$error'),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: '今日记录',
            trailing: TextButton(
              onPressed: () => context.go('/history'),
              child: const Text('全部记录'),
            ),
            child: todaySessions.isEmpty
                ? Text(
                    '今天还没有训练记录。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  )
                : Column(
                    children: [
                      for (final session in todaySessions)
                        _SessionRow(session: session),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/train'),
                  icon: const Icon(Icons.add),
                  label: const Text('自由训练'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/moves'),
                  icon: const Icon(Icons.grid_view),
                  label: const Text('六艺进度'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({this.stats});

  final WorkoutStats? stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trainedToday = stats?.sessionOn(DateTime.now()) != null;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatFullDate(DateTime.now()),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trainedToday ? '今天已完成训练，很棒' : '保持节奏，随时可以开始',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${stats?.streak ?? 0}',
                  unit: '天',
                  label: '连续训练',
                  compact: true,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: '${stats?.sessionsThisWeek ?? 0}',
                  unit: '次',
                  label: '本周训练',
                  compact: true,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: '${stats?.totalSets ?? 0}',
                  unit: '组',
                  label: '累计组数',
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

class _TodayPlanCard extends StatelessWidget {
  const _TodayPlanCard({required this.plan});

  final TodayPlan plan;

  @override
  Widget build(BuildContext context) {
    if (!plan.hasPlan) {
      return SectionCard(
        title: '还没有训练计划',
        subtitle: '选一个模板，每天打开就知道该练什么',
        child: FilledButton.icon(
          onPressed: () => context.go('/plan'),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('生成训练计划'),
        ),
      );
    }

    if (plan.isRest) {
      return SectionCard(
        title: plan.label,
        subtitle: '好好恢复，明天继续',
        child: OutlinedButton.icon(
          onPressed: () => context.push('/train'),
          icon: const Icon(Icons.self_improvement),
          label: const Text('今天还想练一会儿'),
        ),
      );
    }

    return SectionCard(
      title: '今日安排 · ${plan.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final task in plan.tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(task.exercise.icon,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${task.exercise.label} · 第${task.move.level}式',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        Text(
                          task.move.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    task.targetLabel,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: () => context.push(
              '/train',
              extra: TrainIntent(label: plan.label, tasks: plan.tasks),
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始训练'),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = session.entries.isEmpty
        ? null
        : MoveCatalog.byIdOrNull(session.entries.first.moveId);
    final summary = first == null
        ? '训练记录'
        : session.entries.length > 1
            ? '${first.name} 等 ${session.entries.length} 个动作'
            : first.name;

    return InkWell(
      onTap: () => context.push('/sessions/${session.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(summary,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${session.totalSets} 组 · ${session.totalVolume} 次',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      child: SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '数据加载失败',
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
