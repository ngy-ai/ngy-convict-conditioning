import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_convict_conditioning/core/theme.dart';
import 'package:ngy_convict_conditioning/data/backup/backup_data.dart';
import 'package:ngy_convict_conditioning/data/backup/backup_service.dart';
import 'package:ngy_convict_conditioning/data/db/app_database.dart';
import 'package:ngy_convict_conditioning/data/models/big_six.dart';
import 'package:ngy_convict_conditioning/data/models/workout_session.dart';
import 'package:ngy_convict_conditioning/domain/workout_stats.dart';
import 'package:ngy_convict_conditioning/features/backup/backup_page.dart';
import 'package:ngy_convict_conditioning/providers/app_providers.dart';

/// 假的文件对话框：一律当作“用户取消”，只记录弹了几次。
class _FakeFileSelector extends FileSelectorPlatform {
  int saveRequests = 0;
  int openRequests = 0;

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    saveRequests++;
    return null;
  }

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    openRequests++;
    return null;
  }
}

/// 假的备份服务：不碰数据库，只记录被调用次数。
class _FakeBackupService extends BackupService {
  _FakeBackupService() : super(AppDatabase.forTesting('unused_in_page_test.db'));

  int exportCalls = 0;
  int restoreCalls = 0;

  @override
  Future<BackupData> export() async {
    exportCalls++;
    return BackupData(
      exportedAt: DateTime(2026, 10, 13),
      sessions: const [],
      levels: {for (final exercise in BigSix.values) exercise: 1},
      plans: const [],
    );
  }

  @override
  Future<void> restore(BackupData backup) async {
    restoreCalls++;
  }
}

class _EmptySessions extends SessionsNotifier {
  @override
  Future<List<WorkoutSession>> build() async => const [];
}

class _DefaultLevels extends LevelsNotifier {
  @override
  Future<Map<BigSix, int>> build() async =>
      {for (final exercise in BigSix.values) exercise: 1};
}

void main() {
  late _FakeBackupService backup;

  setUp(() {
    backup = _FakeBackupService();
    FileSelectorPlatform.instance = _FakeFileSelector();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupServiceProvider.overrideWithValue(backup),
          sessionsProvider.overrideWith(_EmptySessions.new),
          levelsProvider.overrideWith(_DefaultLevels.new),
          statsProvider.overrideWith((ref) async => WorkoutStats(const [])),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const BackupPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('页面渲染出概况、导出、导入与说明四块', (tester) async {
    await pumpPage(tester);

    expect(find.text('数据备份'), findsOneWidget);
    expect(find.text('数据概况'), findsOneWidget);
    expect(find.text('导出备份文件'), findsOneWidget);
    expect(find.text('选择备份文件并恢复'), findsOneWidget);
    expect(find.text('备份文件说明'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('没有数据时点导出只给提示，不弹保存对话框', (tester) async {
    await pumpPage(tester);
    final dialogs = FileSelectorPlatform.instance as _FakeFileSelector;

    await tester.tap(find.text('导出备份文件'));
    await tester.pumpAndSettle();

    expect(backup.exportCalls, 1);
    expect(find.text('还没有可备份的数据'), findsOneWidget);
    expect(dialogs.saveRequests, 0);
  });

  testWidgets('选文件时取消，不会弹确认框也不会动数据', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('选择备份文件并恢复'));
    await tester.pumpAndSettle();

    expect(find.text('导入并恢复'), findsNothing);
    expect(backup.restoreCalls, 0);
  });
}
