import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/date_utils.dart';
import '../../data/models/workout_session.dart';
import '../../data/seed/big_six_seed.dart';
import '../../providers/app_providers.dart';
import '../../widgets/empty_state.dart';

/// 训练记录列表，按日期分组。
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('训练记录'),
        actions: [
          IconButton(
            tooltip: '补录训练',
            onPressed: () => context.push('/train'),
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: sessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return EmptyState(
              icon: Icons.history,
              title: '还没有训练记录',
              message: '完成一次训练后，这里会按日期记录你的每一组。',
              action: FilledButton.icon(
                onPressed: () => context.push('/train'),
                icon: const Icon(Icons.add),
                label: const Text('记录一次训练'),
              ),
            );
          }

          final grouped = <DateTime, List<WorkoutSession>>{};
          for (final session in sessions) {
            final key = DateTime(
              session.date.year,
              session.date.month,
              session.date.day,
            );
            grouped.putIfAbsent(key, () => []).add(session);
          }
          final days = grouped.entries.toList()
            ..sort((a, b) => b.key.compareTo(a.key));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              for (final day in days) ...[
                _DayHeader(date: day.key, sessions: day.value),
                const SizedBox(height: 8),
                for (final session in day.value) ...[
                  _SessionCard(session: session),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date, required this.sessions});

  final DateTime date;
  final List<WorkoutSession> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sets = sessions.fold<int>(0, (a, s) => a + s.totalSets);

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 2, right: 2),
      child: Row(
        children: [
          Text(
            formatRelativeDay(date),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          Text(
            '$sets 组',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/sessions/${session.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < session.entries.length; i++) ...[
                Builder(
                  builder: (context) {
                    final entry = session.entries[i];
                    final move = MoveCatalog.byIdOrNull(entry.moveId);
                    return Row(
                      children: [
                        Icon(
                          move?.exercise.icon ?? Icons.fitness_center,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                move == null
                                    ? '未知动作'
                                    : '${move.exercise.label} · ${move.name}',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${entry.setCount} 组 · ${entry.sets.join(' / ')}'
                                '${move?.metric.unit ?? ''}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (i != session.entries.length - 1) const SizedBox(height: 10),
              ],
              if (session.note != null && session.note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes,
                        size: 14, color: theme.colorScheme.outline),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        session.note!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
