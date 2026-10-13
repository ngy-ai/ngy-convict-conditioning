import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/big_six.dart';
import '../../data/models/move.dart';
import '../../data/models/training_plan.dart';
import '../../data/models/workout_session.dart';
import '../../data/seed/big_six_seed.dart';
import '../../domain/progression.dart';
import '../../domain/workout_stats.dart';
import '../../providers/app_providers.dart';
import '../../widgets/empty_state.dart';

/// 进入训练页时携带的意图：来自今日计划，或编辑既有记录。
class TrainIntent {
  const TrainIntent({this.label, this.session, this.tasks = const []});

  final String? label;
  final WorkoutSession? session;
  final List<PlanTask> tasks;
}

class TrainPage extends ConsumerStatefulWidget {
  const TrainPage({super.key, this.intent});

  final TrainIntent? intent;

  @override
  ConsumerState<TrainPage> createState() => _TrainPageState();
}

/// 正在录入的一个动作。
class _Draft {
  _Draft({required this.move, required this.sets});

  final Move move;
  final List<int> sets;
}

class _TrainPageState extends ConsumerState<TrainPage> {
  final List<_Draft> _drafts = [];
  final TextEditingController _note = TextEditingController();
  late DateTime _date;
  int? _editingId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final intent = widget.intent;
    final session = intent?.session;
    if (session != null) {
      _editingId = session.id;
      _date = session.date;
      _note.text = session.note ?? '';
      for (final entry in session.entries) {
        final move = MoveCatalog.byIdOrNull(entry.moveId);
        if (move != null) {
          _drafts.add(_Draft(move: move, sets: [...entry.sets]));
        }
      }
    } else {
      _date = DateTime.now();
      for (final task in intent?.tasks ?? const <PlanTask>[]) {
        _drafts.add(
          _Draft(move: task.move, sets: List.filled(task.sets, task.targetValue)),
        );
      }
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.intent?.session != null
        ? '编辑训练记录'
        : (widget.intent?.label ?? '自由训练');

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingId != null ? '编辑记录' : '记录训练'),
        actions: [
          TextButton.icon(
            onPressed: _drafts.isEmpty || _saving ? null : _save,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('保存'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _DateBar(
            date: _date,
            label: label,
            onPick: _pickDate,
          ),
          const SizedBox(height: 16),
          if (_drafts.isEmpty)
            EmptyState(
              icon: Icons.fitness_center,
              title: '还没有动作',
              message: '从今日计划进入会自动带出动作，也可以手动添加。',
              action: FilledButton.icon(
                onPressed: _addMove,
                icon: const Icon(Icons.add),
                label: const Text('添加动作'),
              ),
            )
          else ...[
            for (var i = 0; i < _drafts.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DraftCard(
                  draft: _drafts[i],
                  onRemoveMove: () => setState(() => _drafts.removeAt(i)),
                  onAddSet: () => setState(() {
                    final last = _drafts[i].sets.isEmpty
                        ? 1
                        : _drafts[i].sets.last;
                    _drafts[i].sets.add(last);
                  }),
                  onRemoveSet: (index) => setState(() {
                    if (_drafts[i].sets.length > 1) {
                      _drafts[i].sets.removeAt(index);
                    }
                  }),
                  onAdjust: (index, delta) => setState(() {
                    final next = _drafts[i].sets[index] + delta;
                    _drafts[i].sets[index] = next < 1 ? 1 : next;
                  }),
                  onEditValue: (index) async {
                    final value = await _promptNumber(
                      _drafts[i].sets[index],
                      _drafts[i].move.metric.unit,
                    );
                    if (value != null) {
                      setState(() => _drafts[i].sets[index] = value);
                    }
                  },
                ),
              ),
            OutlinedButton.icon(
              onPressed: _addMove,
              icon: const Icon(Icons.add),
              label: const Text('添加动作'),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '备注（可选），例如：状态、感受',
              prefixIcon: Icon(Icons.edit_note),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _drafts.isEmpty || _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? '保存中…' : '保存记录'),
          ),
          if (_drafts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                '共 ${_drafts.length} 个动作 · '
                '${_drafts.fold<int>(0, (a, d) => a + d.sets.length)} 组 · '
                '${_drafts.fold<int>(0, (a, d) => a + d.sets.fold(0, (x, y) => x + y))} 次',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<int?> _promptNumber(int current, String unit) async {
    final controller = TextEditingController(text: '$current');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('输入$unit数'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(suffixText: unit),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return result == null ? null : (result < 1 ? 1 : result);
  }

  Future<void> _addMove() async {
    final levels = ref.read(levelsProvider).value ?? {};
    final move = await showModalBottomSheet<Move>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _MovePickerSheet(levels: levels),
    );
    if (move == null) return;
    setState(() {
      _drafts.add(_Draft(
        move: move,
        sets: [move.standard.of(TargetLevel.intermediate).value],
      ));
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final statsBefore = ref.read(statsProvider).value;
      final session = WorkoutSession(
        id: _editingId,
        date: _date,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        entries: [
          for (final draft in _drafts)
            WorkoutEntry(moveId: draft.move.id, sets: draft.sets),
        ],
      );
      await ref.read(sessionsProvider.notifier).save(session);

      if (!mounted) return;
      final promoted = _promotions(statsBefore);
      if (promoted.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      await _showPromotionDialog(promoted);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 本次记录后达到当前式高级标准的动作。
  List<Move> _promotions(WorkoutStats? statsBefore) {
    final levels = ref.read(levelsProvider).value ?? {};
    final result = <Move>[];
    for (final draft in _drafts) {
      final move = draft.move;
      if (move.isLast || levels[move.exercise] != move.level) continue;
      final entries = [
        ...(statsBefore?.entriesByMove[move.id] ?? const <WorkoutEntry>[]),
        WorkoutEntry(moveId: move.id, sets: draft.sets),
      ];
      if (Progression.meets(move, TargetLevel.advanced, entries)) {
        result.add(move);
      }
    }
    return result;
  }

  Future<void> _showPromotionDialog(List<Move> moves) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('达成进阶标准'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('以下动作已达到当前式的高级标准，可以进入下一式：'),
            const SizedBox(height: 12),
            for (final move in moves)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(move.exercise.icon, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${move.exercise.label} → 第${move.level + 1}式')),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('立即升级'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    for (final move in moves) {
      await ref
          .read(levelsProvider.notifier)
          .setLevel(move.exercise, move.level + 1);
    }
  }
}

class _DateBar extends StatelessWidget {
  const _DateBar({required this.date, required this.label, required this.onPick});

  final DateTime date;
  final String label;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.event, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy年M月d日 EEEE', 'zh').format(date),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.expand_more,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
        Chip(
          label: Text(label),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

/// 单个动作的录入卡片：每个组一行，可调整次数。
class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.onRemoveMove,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onAdjust,
    required this.onEditValue,
  });

  final _Draft draft;
  final VoidCallback onRemoveMove;
  final VoidCallback onAddSet;
  final void Function(int index) onRemoveSet;
  final void Function(int index, int delta) onAdjust;
  final void Function(int index) onEditValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final move = draft.move;
    final unit = move.metric.unit;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(move.exercise.icon,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${move.exercise.label} · 第${move.level}式',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        move.name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRemoveMove,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: '移除',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 2, bottom: 8),
              child: Text(
                '标准参考：初 ${move.standard.beginner.describe(move.metric)} · '
                '中 ${move.standard.intermediate.describe(move.metric)} · '
                '高 ${move.standard.advanced.describe(move.metric)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (var i = 0; i < draft.sets.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 54,
                      child: Text(
                        '第${i + 1}组',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    _StepButton(
                      icon: Icons.remove,
                      onTap: () => onAdjust(i, -1),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => onEditValue(i),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '${draft.sets[i]} $unit',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _StepButton(
                      icon: Icons.add,
                      onTap: () => onAdjust(i, 1),
                    ),
                    SizedBox(
                      width: 36,
                      child: draft.sets.length > 1
                          ? IconButton(
                              onPressed: () => onRemoveSet(i),
                              icon: const Icon(Icons.backspace_outlined,
                                  size: 16),
                              visualDensity: VisualDensity.compact,
                              tooltip: '删除该组',
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: onAddSet,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('加一组'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// 动作选择：先选六艺，再选具体式。
class _MovePickerSheet extends StatefulWidget {
  const _MovePickerSheet({required this.levels});

  final Map<BigSix, int> levels;

  @override
  State<_MovePickerSheet> createState() => _MovePickerSheetState();
}

class _MovePickerSheetState extends State<_MovePickerSheet> {
  BigSix? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selected;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              selected == null ? '选择六艺' : '${selected.label} · 选择式',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: selected == null
                ? ListView(
                    children: [
                      for (final exercise in BigSix.values)
                        ListTile(
                          leading: Icon(exercise.icon,
                              color: theme.colorScheme.primary),
                          title: Text(exercise.label),
                          subtitle: Text(
                            '当前：第${widget.levels[exercise] ?? 1}式',
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => setState(() => _selected = exercise),
                        ),
                    ],
                  )
                : ListView(
                    children: [
                      for (final move in MoveCatalog.ladder(selected))
                        ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                theme.colorScheme.primary.withValues(alpha: 0.15),
                            child: Text(
                              '${move.level}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          title: Text(move.name),
                          subtitle: Text(
                            '${move.standard.intermediate.describe(move.metric)}（中级标准）',
                            style: theme.textTheme.bodySmall,
                          ),
                          onTap: () => Navigator.pop(context, move),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
