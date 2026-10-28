import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/big_six.dart';
import '../../data/models/move.dart';
import '../../domain/progression.dart';
import '../../providers/app_providers.dart';
import '../../widgets/section_card.dart';

/// 六艺总览：每一艺的当前式与达成情况。
class MovesPage extends ConsumerWidget {
  const MovesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(moveProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('六艺')),
      body: progressAsync.when(
        data: (progress) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const SectionCard(
              child: Text(
                '六艺共 60 式，每艺十式。从第 1 式开始训练，达到当前式的高级标准后即可进阶到下一式。',
              ),
            ),
            const SizedBox(height: 14),
            for (final exercise in BigSix.values) ...[
              _ExerciseCard(
                progress: progress[exercise]!,
                onTap: () => context.push('/moves/${exercise.name}'),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.progress, required this.onTap});

  final MoveProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final move = progress.move;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          move.exercise.label,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          move.exercise.labelEn,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '第${move.level}式 · ${move.name}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _AchievementBadges(achieved: progress.achieved),
                        const Spacer(),
                        Text(
                          '累计 ${progress.totalSets} 组',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementBadges extends StatelessWidget {
  const _AchievementBadges({required this.achieved});

  final TargetLevel? achieved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final level in TargetLevel.values) ...[
          _Badge(
            label: level.label,
            done: achieved != null && achieved!.index >= level.index,
            theme: theme,
          ),
          const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.done, required this.theme});

  final String label;
  final bool done;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = done ? theme.colorScheme.primary : theme.colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: done ? theme.colorScheme.primary.withValues(alpha: 0.14) : null,
        border: Border.all(color: color.withValues(alpha: done ? 0.6 : 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
