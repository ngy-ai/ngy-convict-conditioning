import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 备份文件的落盘与选取。
///
/// 优先用系统文件对话框（Windows / macOS / Linux / iOS）；
/// 平台没有保存对话框时（如 Android），退回到应用文档目录下的 backups/，
/// 并把真实路径返回给调用方提示用户。
class BackupFiles {
  BackupFiles._();

  static const _jsonGroup = XTypeGroup(
    label: 'JSON 备份',
    extensions: ['json'],
    mimeTypes: ['application/json'],
  );

  /// 写入备份内容，返回落盘的文件；用户取消选择时返回 null。
  static Future<File?> save(String content, String suggestedName) async {
    String? chosenPath;
    try {
      final location = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: const [_jsonGroup],
      );
      if (location == null) return null; // 用户取消
      chosenPath = location.path;
    } on UnimplementedError {
      // 该平台没有保存对话框，走下面的兜底目录。
    } on MissingPluginException {
      // 插件没注册（正常构建不会发生），同样兜底。
    }

    final file = chosenPath != null
        ? File(chosenPath)
        : File(p.join(
            (await getApplicationDocumentsDirectory()).path,
            'backups',
            suggestedName,
          ));
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
    return file;
  }

  /// 让用户挑一个备份文件并读出内容；取消时返回 null。
  static Future<String?> open() async {
    final file = await openFile(acceptedTypeGroups: const [_jsonGroup]);
    if (file == null) return null;
    final text = await file.readAsString();
    // 记事本等 Windows 工具存 UTF-8 时会带 BOM，解析前去掉。
    return text.startsWith('\uFEFF') ? text.substring(1) : text;
  }
}
