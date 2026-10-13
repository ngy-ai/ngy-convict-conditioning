import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

/// 《囚徒健身》电子书：在 pubspec.yaml 里声明的资产路径。
const _assetKey = 'assets/book/convict_conditioning.epub';

/// 按 zip 解开 EPUB。资产能读出来才说明它真的打进了应用包，
/// 后面两步又顺带验证了 archive 确实可用。
Future<Archive> _loadEpub() async {
  final data = await rootBundle.load(_assetKey);
  return ZipDecoder()
      .decodeBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
}

String _readText(Archive archive, String path) {
  final file = archive.findFile(path);
  expect(file, isNotNull, reason: 'EPUB 里缺少 $path');
  return utf8.decode(file!.content);
}

/// 读 container.xml 找到 OPF（书档清单）的路径，再解析出来。
XmlDocument _readOpf(Archive archive) {
  final container = XmlDocument.parse(_readText(archive, 'META-INF/container.xml'));
  final opfPath = container.findAllElements('rootfile').first.getAttribute('full-path')!;
  return XmlDocument.parse(_readText(archive, opfPath));
}

void main() {
  // 读 rootBundle 需要有绑定，测试跑起来时资产目录也才就绪。
  TestWidgetsFlutterBinding.ensureInitialized();

  test('EPUB 资产可用，且能解出书名与作者', () async {
    final archive = await _loadEpub();

    // zip 的第一项必须是未压缩的 mimetype，这是 EPUB 的识别标志。
    expect(_readText(archive, 'mimetype').trim(), 'application/epub+zip');

    final opf = _readOpf(archive);
    expect(opf.findAllElements('title', namespaceUri: '*').first.innerText, '囚徒健身');
    expect(opf.findAllElements('creator', namespaceUri: '*').first.innerText, '保罗•威德');

    // 六艺的正文与插图都在这一份书档里。
    expect(archive.files.length, greaterThan(100));
  });

  test('章节正文能用 html 解析成纯文本，插图也在包里', () async {
    final archive = await _loadEpub();

    final document = html_parser.parse(_readText(archive, 'EPUB/index_split_002.html'));
    final text = document.body?.text ?? '';

    expect(text, contains('第一章力量之旅'));
    expect(text.length, greaterThan(100));

    expect(archive.findFile('EPUB/images/calibre_cover.jpg'), isNotNull);
  });
}
