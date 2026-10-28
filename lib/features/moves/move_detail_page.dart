import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/big_six.dart';
import '../../data/models/move.dart';
import '../../data/models/training_plan.dart';
import '../../domain/progression.dart';
import '../../providers/app_providers.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_tile.dart';
import '../train/train_page.dart';

/// 某一艺的十式阶梯详情。
class MoveDetailPage extends ConsumerWidget {
  const MoveDetailPage({super.key, required this.exercise});

  final BigSix exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(exerciseDetailProvider(exercise));

    return Scaffold(
      appBar: AppBar(title: Text('${exercise.label} · 十式')),
      body: detailAsync.when(
        data: (detail) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _CurrentCard(
              detail: detail,
              onAdvance: () => ref
                  .read(levelsProvider.notifier)
                  .setLevel(exercise, detail.currentLevel + 1),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                '十式阶梯',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final achievement in detail.achievements) ...[
              _MoveTile(
                detail: detail,
                achievement: achievement,
                onSetCurrent: () => ref
                    .read(levelsProvider.notifier)
                    .setLevel(exercise, achievement.move.level),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
      ),
    );
  }
}

class _CurrentCard extends StatelessWidget {
  const _CurrentCard({required this.detail, required this.onAdvance});

  final ExerciseDetail detail;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = detail.current;
    final move = current.move;
    final canAdvance = current.achieved == TargetLevel.advanced && !move.isLast;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(move.exercise.icon,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '当前 · 第${move.level}式',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            move.name,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            move.nameEn,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 10),
          Text(move.cue, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          _GuideBlock(move: move),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${current.totalSets}',
                  unit: '组',
                  label: '累计组数',
                  compact: true,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: '${current.totalVolume}',
                  unit: move.metric.unit,
                  label: '累计总量',
                  compact: true,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: '${current.bestSet}',
                  unit: move.metric.unit,
                  label: '单组最佳',
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StandardRow(move: move, achieved: current.achieved),
          if (canAdvance) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.trending_up,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '已达到高级标准，可以进阶到第${move.level + 1}式',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  FilledButton(
                    onPressed: onAdvance,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('进阶'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 「训练指导」入口：点进去是该式的完整指导页（动作、解析、训练目标、稳扎稳打）。
class _GuideBlock extends StatelessWidget {
  const _GuideBlock({required this.move, this.compact = false});

  final Move move;

  /// 紧凑模式去掉卡片底色，用在十式阶梯的展开项里。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final route = '/moves/${move.exercise.name}/guide/${move.level}';

    final label = Text(
      '训练指导',
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
    final summary = Text(
      move.guide.action,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.55,
      ),
    );
    final more = Text(
      '查看动作、解析与稳扎稳打',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.primary,
      ),
    );

    if (compact) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [label, const SizedBox(height: 2), summary],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.tips_and_updates_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  label,
                  const SizedBox(height: 3),
                  summary,
                  const SizedBox(height: 6),
                  more,
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

class _StandardRow extends StatelessWidget {
  const _StandardRow({required this.move, required this.achieved});

  final Move move;
  final TargetLevel? achieved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final level in TargetLevel.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  achieved != null && achieved!.index >= level.index
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: achieved != null && achieved!.index >= level.index
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(level.label, style: theme.textTheme.bodySmall),
                ),
                Text(
                  move.standard.of(level).describe(move.metric),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MoveTile extends StatelessWidget {
  const _MoveTile({
    required this.detail,
    required this.achievement,
    required this.onSetCurrent,
  });

  final ExerciseDetail detail;
  final MoveAchievement achievement;
  final VoidCallback onSetCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final move = achievement.move;
    final isCurrent = move.level == detail.currentLevel;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 56,
          height: 56,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrent
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: isCurrent ? 2 : 1,
            ),
          ),
          child: Image.asset(
            'assets/move_figures/${move.exercise.name}-${move.level}.png',
            fit: BoxFit.contain,
            cacheWidth: 168,
            errorBuilder: (context, error, stackTrace) => Icon(
              move.exercise.icon,
              size: 22,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              '第${move.level}式',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                move.name,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (isCurrent) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '当前',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '初 ${move.standard.beginner} · '
          '中 ${move.standard.intermediate} · '
          '高 ${move.standard.advanced} ${move.metric.unit}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(move.cue, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(
            achievement.trained
                ? '累计 ${achievement.totalSets} 组 · '
                    '总量 ${achievement.totalVolume}${move.metric.unit} · '
                    '单组最佳 ${achievement.bestSet}${move.metric.unit}'
                    '${achievement.achieved != null ? ' · 已达${achievement.achieved!.label}标准' : ''}'
                : '还没有练过这一式',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _GuideBlock(move: move, compact: true),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                onPressed: isCurrent ? null : onSetCurrent,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: Text(isCurrent ? '当前式' : '设为当前式'),
              ),
              const SizedBox(width: 10),
              FilledButton.tonal(
                onPressed: () => context.push(
                  '/train',
                  extra: TrainIntent(
                    label: '${move.exercise.label} · ${move.name}',
                    tasks: [
                      PlanTask(
                        exercise: move.exercise,
                        move: move,
                        sets: move.standard.intermediate.sets,
                        targetValue: move.standard.intermediate.value,
                      ),
                    ],
                  ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('练这一式'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
