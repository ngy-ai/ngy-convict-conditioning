import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_convict_conditioning/data/backup/backup_files.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// 假的文件对话框：按需给出保存路径 / 打开的文件，或模拟平台没有该对话框。
class _FakeFileSelector extends FileSelectorPlatform {
  _FakeFileSelector({this.savePath, this.openPath, this.unsupported = false});

  final String? savePath;
  final String? openPath;
  final bool unsupported;

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    if (unsupported) throw UnimplementedError('本平台没有保存对话框');
    final path = savePath;
    return path == null ? null : FileSaveLocation(path);
  }

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    final path = openPath;
    return path == null ? null : XFile(path);
  }
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cc-backup-files');
    PathProviderPlatform.instance = _FakePathProvider(temp.path);
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('写到用户选择的位置，并自动建好目录', () async {
    final target = p.join(temp.path, 'nested', 'backup.json');
    FileSelectorPlatform.instance = _FakeFileSelector(savePath: target);

    final file = await BackupFiles.save('{"version":1}', 'backup.json');

    expect(file!.path, target);
    expect(file.readAsStringSync(), '{"version":1}');
  });

  test('用户取消保存时返回 null，不落任何文件', () async {
    FileSelectorPlatform.instance = _FakeFileSelector(savePath: null);

    expect(await BackupFiles.save('{}', 'backup.json'), isNull);
    expect(Directory(p.join(temp.path, 'backups')).existsSync(), isFalse);
  });

  test('平台没有保存对话框时退回到应用文档目录', () async {
    FileSelectorPlatform.instance = _FakeFileSelector(unsupported: true);

    final file = await BackupFiles.save('{}', 'backup.json');

    expect(file!.path, p.join(temp.path, 'backups', 'backup.json'));
    expect(file.readAsStringSync(), '{}');
  });

  test('读到备份内容，并去掉 UTF-8 BOM', () async {
    final source = File(p.join(temp.path, 'in.json'))
      ..writeAsStringSync('\uFEFF{"version":1}');
    FileSelectorPlatform.instance = _FakeFileSelector(openPath: source.path);

    expect(await BackupFiles.open(), '{"version":1}');
  });

  test('取消选择文件时返回 null', () async {
    FileSelectorPlatform.instance = _FakeFileSelector(openPath: null);

    expect(await BackupFiles.open(), isNull);
  });
}
