import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';

/// 弹出皮肤选择面板。
Future<void> showThemePicker(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => const _ThemePickerDialog(),
  );
}

class _ThemePickerDialog extends ConsumerWidget {
  const _ThemePickerDialog();

  static const _options =
      <({ThemeMode mode, IconData icon, String label, String hint})>[
    (
      mode: ThemeMode.system,
      icon: Icons.brightness_auto_outlined,
      label: '跟随系统',
      hint: '随系统的深浅色设置切换',
    ),
    (
      mode: ThemeMode.light,
      icon: Icons.light_mode_outlined,
      label: '浅色「纸感」',
      hint: '牛皮纸底 · 铁锈红',
    ),
    (
      mode: ThemeMode.dark,
      icon: Icons.dark_mode_outlined,
      label: '深色「夜铁」',
      hint: '暖黑底 · 亮铁锈橙',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(themeModeProvider);

    return AlertDialog(
      // 内容多时对话框内部可滚动，窗口再矮也不会被截断。
      scrollable: true,
      title: const Text('外观'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择应用使用的皮肤',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          for (final option in _options) ...[
            _ModeOption(
              icon: option.icon,
              label: option.label,
              hint: option.hint,
              selected: current == option.mode,
              onTap: () {
                ref.read(themeModeProvider.notifier).select(option.mode);
                Navigator.of(context).pop();
              },
            ),
            if (option != _options.last) const SizedBox(height: 10),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
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
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
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
                    label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
