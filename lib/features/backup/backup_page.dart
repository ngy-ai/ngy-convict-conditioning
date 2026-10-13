import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_utils.dart';
import '../../data/backup/backup_data.dart';
import '../../data/backup/backup_files.dart';
import '../../data/models/big_six.dart';
import '../../providers/app_providers.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_tile.dart';

/// 数据备份：导出全部数据为 JSON 文件，或从文件覆盖式恢复。
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;
  String? _lastExportPath;

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final data = await ref.read(backupServiceProvider).export();
      if (data.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('还没有可备份的数据')));
        return;
      }
      final file = await BackupFiles.save(
        data.encode(),
        BackupData.fileNameFor(DateTime.now()),
      );
      if (file == null) return; // 用户取消
      if (!mounted) return;
      setState(() => _lastExportPath = file.path);
      messenger.showSnackBar(SnackBar(
        content: Text('已导出 ${data.sessionCount} 条训练记录、'
            '${data.planCount} 个计划'),
      ));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final source = await BackupFiles.open();
      if (source == null) return; // 用户取消
      final data = BackupData.decode(source);
      if (!mounted) return;

      final currentCount = ref.read(sessionsProvider).value?.length ?? 0;
      final confirmed = await _confirmRestore(data, currentCount);
      if (confirmed != true) return;

      await ref.read(backupServiceProvider).restore(data);
      ref.invalidate(sessionsProvider);
      ref.invalidate(levelsProvider);
      ref.invalidate(activePlanProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('已恢复 ${data.sessionCount} 条训练记录、'
            '${data.planCount} 个计划'),
      ));
    } on BackupFormatException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('备份文件无法解析：${error.message}')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('导入失败：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmRestore(BackupData data, int currentCount) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入并恢复'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('备份时间：${formatFullDate(data.exportedAt)}'),
            const SizedBox(height: 8),
            Text('包含 ${data.sessionCount} 条训练记录'
                '（共 ${data.setCount} 组）、$_progressedCountLabel、'
                '${data.planCount} 个训练计划。'),
            const SizedBox(height: 12),
            Text(
              currentCount == 0
                  ? '当前设备上还没有训练记录，可以直接恢复。'
                  : '当前设备上的 $currentCount 条训练记录、六艺进度与计划'
                      '都会被清空并替换成备份内容，此操作不可撤销。',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('覆盖恢复'),
          ),
        ],
      ),
    );
  }

  String get _progressedCountLabel {
    final levels = ref.read(levelsProvider).value ?? const <BigSix, int>{};
    final count = levels.values.where((level) => level > 1).length;
    return count == 0 ? '六艺都还在第 1 式' : '六艺中 $count 艺已进阶';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionCount = ref.watch(sessionsProvider).value?.length ?? 0;
    final totalSets = ref.watch(statsProvider).value?.totalSets ?? 0;
    final levels = ref.watch(levelsProvider).value ?? const <BigSix, int>{};
    final progressed = levels.values.where((level) => level > 1).length;

    return Scaffold(
      appBar: AppBar(title: const Text('数据备份')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          SectionCard(
            title: '数据概况',
            subtitle: '全部数据都保存在本机',
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: '$sessionCount',
                    unit: '次',
                    label: '训练记录',
                    compact: true,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    value: '$totalSets',
                    unit: '组',
                    label: '累计组数',
                    compact: true,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    value: '$progressed',
                    unit: '艺',
                    label: '已进阶',
                    compact: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: '导出备份',
            subtitle: '训练记录、六艺进度与训练计划，导出为一个 JSON 文件',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('导出备份文件'),
                ),
                if (_lastExportPath != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '最近导出',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    _lastExportPath!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: '导入恢复',
            subtitle: '从备份文件恢复，当前数据会被备份内容替换',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.settings_backup_restore),
                  label: const Text('选择备份文件并恢复'),
                ),
                const SizedBox(height: 10),
                Text(
                  '恢复前会列出备份内容并二次确认；覆盖操作在一个事务里完成，'
                  '中途失败不会留下半份数据。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: '备份文件说明',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in const [
                  '格式为 UTF-8 的 JSON，包含 sessions（训练记录）、'
                      'progress（六艺进度）、plans（训练计划）三部分。',
                  '不含数据库自增号，恢复时会重新编号，不影响日期与组数。',
                  '导入时校验版本号：备份文件版本高于应用支持版本会拒绝导入，'
                      '避免读出错的数据。',
                  '文件不加密，请注意存放位置，避免夹杂个人训练备注外泄。',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 8),
                          child: Icon(
                            Icons.circle,
                            size: 5,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            line,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
