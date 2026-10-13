import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_utils.dart';
import '../../data/models/big_six.dart';
import '../../data/models/move.dart';
import '../../data/models/training_plan.dart';
import '../../domain/plan_generator.dart';
import '../../providers/app_providers.dart';
import '../../widgets/section_card.dart';

/// 生成训练计划：选模板、频率、目标标准，实时预览。
class PlanEditorPage extends ConsumerStatefulWidget {
  const PlanEditorPage({super.key});

  @override
  ConsumerState<PlanEditorPage> createState() => _PlanEditorPageState();
}

class _PlanEditorPageState extends ConsumerState<PlanEditorPage> {
  PlanTemplate _template = PlanTemplate.newBlood;
  int _daysPerWeek = 3;
  TargetLevel _targetLevel = TargetLevel.intermediate;
  int _sets = 3;
  DateTime _startDate = DateTime.now();
  final Set<BigSix> _customExercises = {...BigSix.values};
  bool _saving = false;

  void _selectTemplate(PlanTemplate template) {
    setState(() {
      _template = template;
      switch (template) {
        case PlanTemplate.newBlood:
          _daysPerWeek = 3;
          _sets = 3;
          _targetLevel = TargetLevel.intermediate;
        case PlanTemplate.goodBehavior:
          _daysPerWeek = 6;
          _sets = 3;
          _targetLevel = TargetLevel.intermediate;
        case PlanTemplate.veteran:
          _daysPerWeek = 6;
          _sets = 4;
          _targetLevel = TargetLevel.advanced;
        case PlanTemplate.custom:
          _daysPerWeek = 3;
          _sets = 3;
          _targetLevel = TargetLevel.intermediate;
      }
    });
  }

  TrainingPlan _buildPlan() => PlanGenerator.build(
        template: _template,
        daysPerWeek: _daysPerWeek,
        targetLevel: _targetLevel,
        setsPerExercise: _sets,
        startDate: _startDate,
        customDays:
            _template == PlanTemplate.custom ? _customDays() : null,
      );

  /// 自定义计划：把选中的六艺均匀分配到每周训练日。
  List<PlanDay> _customDays() {
    final exercises = _customExercises.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final selected =
        exercises.isEmpty ? [...BigSix.values] : exercises;
    final weekdays = PlanGenerator.weekdaysFor(_daysPerWeek);

    return [
      for (var i = 0; i < weekdays.length; i++)
        PlanDay(
          label: '训练日 ${i + 1}',
          weekdays: [weekdays[i]],
          exercises: [
            for (var j = i; j < selected.length; j += weekdays.length) selected[j],
          ],
        ),
    ];
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final plan = _buildPlan();
      await ref.read(activePlanProvider.notifier).save(plan);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('已生成「${plan.name}」，每周 ${plan.daysPerWeek} 练')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _buildPlan();
    final levels = ref.watch(levelsProvider).value ?? const <BigSix, int>{};

    return Scaffold(
      appBar: AppBar(title: const Text('生成训练计划')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          SectionCard(
            title: '选择模板',
            child: Column(
              children: [
                for (final template in PlanTemplate.values) ...[
                  _TemplateOption(
                    template: template,
                    selected: _template == template,
                    onTap: () => _selectTemplate(template),
                  ),
                  if (template != PlanTemplate.values.last)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: '每周训练天数',
            subtitle: _daysHint,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var days = 1; days <= 7; days++)
                  ChoiceChip(
                    label: Text('$days 天'),
                    selected: _daysPerWeek == days,
                    onSelected: (_) => setState(() => _daysPerWeek = days),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: '目标标准',
            subtitle: '按该标准给出每个动作的目标次数',
            child: SegmentedButton<TargetLevel>(
              segments: [
                for (final level in TargetLevel.values)
                  ButtonSegment(value: level, label: Text(level.label)),
              ],
              selected: {_targetLevel},
              onSelectionChanged: (selection) =>
                  setState(() => _targetLevel = selection.first),
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: '每个动作组数',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var sets = 1; sets <= 6; sets++)
                  ChoiceChip(
                    label: Text('$sets 组'),
                    selected: _sets == sets,
                    onSelected: (_) => setState(() => _sets = sets),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_template == PlanTemplate.custom) ...[
            SectionCard(
              title: '选择要练的六艺',
              subtitle: '系统会把这些动作均匀分配到每周训练日',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final exercise in BigSix.values)
                    FilterChip(
                      // 选中时 chip 底色是主色，图标要用 onPrimary 才看得见。
                      avatar: Icon(exercise.icon,
                          size: 16,
                          color: _customExercises.contains(exercise)
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.outline),
                      label: Text(exercise.label),
                      selected: _customExercises.contains(exercise),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _customExercises.add(exercise);
                        } else if (_customExercises.length > 1) {
                          _customExercises.remove(exercise);
                        }
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          SectionCard(
            title: '开始日期',
            trailing: TextButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
              icon: const Icon(Icons.event, size: 16),
              label: const Text('选择'),
            ),
            child: Text(
              formatFullDate(_startDate),
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: '计划预览',
            subtitle: '按你当前所在式自动解析出具体动作',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final day in plan.days) ...[
                  _PreviewDay(day: day, plan: plan, levels: levels),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_saving ? '生成中…' : '生成计划'),
          ),
        ],
      ),
    );
  }

  String get _daysHint => switch (_template) {
        PlanTemplate.newBlood => '建议 3 天，隔天训练',
        PlanTemplate.goodBehavior => '建议 6 天，推、拉两组交替',
        PlanTemplate.veteran => '建议 6 天，每天专攻一艺',
        PlanTemplate.custom => '选择你每周能坚持的天数',
      };
}

class _TemplateOption extends StatelessWidget {
  const _TemplateOption({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final PlanTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
            width: selected ? 1.6 : 1,
          ),
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    template.label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    template.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewDay extends StatelessWidget {
  const _PreviewDay({
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                day.label,
                style: theme.textTheme.bodyLarge
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
        const SizedBox(height: 4),
        for (final task in tasks)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Row(
              children: [
                Icon(task.exercise.icon,
                    size: 14, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${task.move.name}（第${task.move.level}式）',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Text(
                  task.targetLabel,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
