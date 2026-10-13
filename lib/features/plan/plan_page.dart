import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/date_utils.dart';
import '../../data/models/big_six.dart';
import '../../data/models/training_plan.dart';
import '../../domain/plan_generator.dart';
import '../../providers/app_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';

/// 当前训练计划。
class PlanPage extends ConsumerWidget {
  const PlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(activePlanProvider);
    final levels = ref.watch(levelsProvider).value ?? const <BigSix, int>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('训练计划'),
        actions: [
          IconButton(
            tooltip: '生成新计划',
            onPressed: () => context.push('/plan/editor'),
            icon: const Icon(Icons.auto_awesome),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: planAsync.when(
        data: (plan) {
          if (plan == null) {
            return EmptyState(
              icon: Icons.assignment_outlined,
              title: '还没有训练计划',
              message: '选择「新血」「好习惯」或「老手」模板，'
                  '按你的六艺进度自动生成每日安排。',
              action: FilledButton.icon(
                onPressed: () => context.push('/plan/editor'),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('生成训练计划'),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _PlanHeader(plan: plan),
              const SizedBox(height: 14),
              for (final day in plan.days) ...[
                _PlanDayCard(day: day, plan: plan, levels: levels),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/plan/editor'),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新生成'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('停用计划'),
                            content: const Text('停用后首页将不再显示每日安排，'
                                '已有的训练记录不会受到影响。'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('停用'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref
                              .read(activePlanProvider.notifier)
                              .deactivate();
                        }
                      },
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('停用'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.plan});

  final TrainingPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan.name,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Chip(label: Text(plan.template.label)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            plan.template.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.calendar_today,
                label: '每周 ${plan.daysPerWeek} 练',
              ),
              _InfoChip(
                icon: Icons.flag_outlined,
                label: '目标${plan.targetLevel.label}标准',
              ),
              _InfoChip(
                icon: Icons.repeat,
                label: '每动作 ${plan.setsPerExercise} 组',
              ),
              _InfoChip(
                icon: Icons.play_circle_outline,
                label: '${formatMonthDay(plan.startDate)} 开始',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PlanDayCard extends StatelessWidget {
  const _PlanDayCard({
    required this.day,
    required this.plan,
    required this.levels,
  });

  final PlanDay day;
  final TrainingPlan plan;
  final Map<BigSix, int> levels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = PlanGenerator.resolveTasks(
      exercises: day.exercises,
      plan: plan,
      levels: levels,
    );

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day.label,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                day.weekdays.map(weekdayLabel).join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(task.exercise.icon,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          task.exercise.label,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '第${task.move.level}式 · ${task.move.name}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    task.targetLabel,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
