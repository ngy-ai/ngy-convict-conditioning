import 'package:flutter/material.dart';

import '../../data/models/move.dart';
import '../../widgets/section_card.dart';

/// 一式的完整训练指导：动作、解析、训练目标与稳扎稳打。
///
/// 页面顶部保留一个示意图位，不复制原书插图。
class MoveGuidePage extends StatelessWidget {
  const MoveGuidePage({super.key, required this.move});

  final Move move;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guide = move.guide;

    return Scaffold(
      appBar: AppBar(
        title: Text('${move.exercise.label} · 第 ${move.level} 式'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _Header(move: move),
          const SizedBox(height: 16),
          _FigurePlaceholder(move: move),
          const SizedBox(height: 16),
          SectionCard(
            title: '动作',
            child: Text(guide.action, style: _bodyStyle(theme)),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '解析',
            child: Text(guide.analysis, style: _bodyStyle(theme)),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '训练目标',
            child: Column(
              children: [
                for (final level in TargetLevel.values)
                  _TargetLine(
                    level: level,
                    target: move.standard.of(level),
                    metric: move.metric,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '稳扎稳打',
            child: Text(guide.progression, style: _bodyStyle(theme)),
          ),
        ],
      ),
    );
  }

  static TextStyle? _bodyStyle(ThemeData theme) =>
      theme.textTheme.bodyMedium?.copyWith(height: 1.7);
}

class _Header extends StatelessWidget {
  const _Header({required this.move});

  final Move move;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '第 ${move.level} 式',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              move.exercise.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          move.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          move.nameEn,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

/// 示意图位：用六艺图标占位，不复制原书插图。
class _FigurePlaceholder extends StatelessWidget {
  const _FigurePlaceholder({required this.move});

  final Move move;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              move.exercise.icon,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 10),
            Text(
              '动作示意',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '按下方「动作」要点完成',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetLine extends StatelessWidget {
  const _TargetLine({
    required this.level,
    required this.target,
    required this.metric,
  });

  final TargetLevel level;
  final SetTarget target;
  final MoveMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              level.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              target.describe(metric),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
