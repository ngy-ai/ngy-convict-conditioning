import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'book_models.dart';

/// 应用资产里的书档路径（见 pubspec.yaml 的 assets 段）。
const String kBookAssetKey = 'assets/book/convict_conditioning.epub';

/// 读取应用资产里的电子书并解析。
///
/// 解析会把书档整个解压进内存（约 8 MB），调用方（provider）应当缓存结果。
Future<BookDocument> loadBookAsset([String assetKey = kBookAssetKey]) async {
  final data = await rootBundle.load(assetKey);
  return parseEpub(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
}

/// 解析 EPUB：元数据、目录（toc.ncx）、按正文顺序的章、章内小节与插图。
///
/// 只依赖传入的字节流，方便测试里直接跑真实书档。
///
/// calibre 生成的这本书结构如下：
/// - `META-INF/container.xml` 指出 OPF（`EPUB/content.opf`）；
/// - OPF 的 `manifest` 给出文件清单，`spine` 给出正文顺序，`toc.ncx` 给出目录；
/// - 正文是若干 XHTML 文档：`<p>` 是段落、`<img>` 是插图、
///   带 `id` 的块级元素与「第 X 式」标题是小节起点。
BookDocument parseEpub(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final opfPath = _opfPath(archive);
  final bookDir = p.posix.dirname(opfPath);
  final opf = XmlDocument.parse(_readText(archive, opfPath));

  final items = <String, _ManifestItem>{};
  for (final item in opf.findAllElements('item')) {
    final id = item.getAttribute('id');
    final href = item.getAttribute('href');
    if (id == null || href == null) continue;
    items[id] = _ManifestItem(
      path: _resolve(bookDir, href),
      mediaType: item.getAttribute('media-type') ?? '',
      properties: item.getAttribute('properties') ?? '',
    );
  }

  final toc = _parseToc(archive, opf, items, bookDir);
  final tocTitles = <String, String>{};
  void collectTitles(List<BookTocEntry> entries) {
    for (final entry in entries) {
      tocTitles.putIfAbsent(entry.href, () => entry.title);
      collectTitles(entry.children);
    }
  }

  collectTitles(toc);

  final chapters = <BookChapter>[];
  for (final itemref in opf.findAllElements('itemref')) {
    final item = items[itemref.getAttribute('idref')];
    if (item == null || !item.isDocument) continue;
    if (_skippedFiles.contains(p.posix.basename(item.path))) continue;
    chapters.add(_parseChapter(archive, item.path, tocTitles[item.path]));
  }

  return BookDocument(
    meta: _parseMeta(opf, items),
    chapters: chapters,
    toc: toc,
    images: _collectImages(archive),
  );
}

// ───────────────────────── 元数据 ─────────────────────────

BookMeta _parseMeta(XmlDocument opf, Map<String, _ManifestItem> items) {
  String metaText(String name) {
    final elements = opf.findAllElements(name, namespaceUri: '*');
    return elements.isEmpty ? '' : elements.first.innerText.trim();
  }

  String? coverPath;
  for (final element in opf.findAllElements('meta')) {
    if (element.getAttribute('name') != 'cover') continue;
    coverPath = items[element.getAttribute('content')]?.path;
  }
  coverPath ??= _firstWhere(
    items.values,
    (item) => item.properties.split(' ').contains('cover-image'),
  )?.path;

  return BookMeta(
    title: metaText('title'),
    author: metaText('creator'),
    language: metaText('language'),
    coverImagePath: coverPath,
  );
}

// ───────────────────────── 目录 ─────────────────────────

List<BookTocEntry> _parseToc(
  Archive archive,
  XmlDocument opf,
  Map<String, _ManifestItem> items,
  String bookDir,
) {
  final ncx = _firstWhere(items.values, (item) => item.mediaType == _ncxMediaType) ??
      items[_spineTocId(opf) ?? ''];
  final source = ncx == null ? null : _readTextOrNull(archive, ncx.path);
  if (source == null) return const [];

  final navMap = _firstWhere(XmlDocument.parse(source).findAllElements('navMap'), (e) => true);
  return navMap == null ? const [] : _tocEntries(navMap, bookDir);
}

List<BookTocEntry> _tocEntries(XmlElement parent, String bookDir) {
  final entries = <BookTocEntry>[];
  for (final point in parent.findElements('navPoint')) {
    final label = _firstWhere(point.findElements('navLabel'), (e) => true)?.innerText.trim() ?? '';
    final src = _firstWhere(point.findElements('content'), (e) => true)?.getAttribute('src') ?? '';
    if (src.isEmpty) continue;
    final hash = src.indexOf('#');
    final path = hash < 0 ? src : src.substring(0, hash);
    entries.add(BookTocEntry(
      title: label,
      href: _resolve(bookDir, path),
      fragment: hash < 0 ? null : src.substring(hash + 1),
      children: _tocEntries(point, bookDir),
    ));
  }
  return entries;
}

String? _spineTocId(XmlDocument opf) =>
    _firstWhere(opf.findAllElements('spine'), (e) => true)?.getAttribute('toc');

// ───────────────────────── 正文 ─────────────────────────

BookChapter _parseChapter(Archive archive, String href, String? tocTitle) {
  final source = _readTextOrNull(archive, href) ?? '';
  final body = html_parser.parse(source).body;
  final sections = body == null ? <BookSection>[] : _parseSections(body, href);
  final firstTitled = _firstWhere(sections, (section) => section.title.isNotEmpty);

  // 目录里没有的章（封面页、版权页）没有标题可言，留空让页面用书名兜底，
  // 免得界面上出现 titlepage.xhtml 这种文件名。
  return BookChapter(
    href: href,
    title: tocTitle ?? firstTitled?.title ?? '',
    sections: sections,
  );
}

/// 把一章的 `<body>` 拆成小节：遇到锚点或「第 X 式」标题就另起一节。
List<BookSection> _parseSections(dom.Element body, String chapterHref) {
  final chapterDir = p.posix.dirname(chapterHref);
  final sections = <BookSection>[];
  final blocks = <BookBlock>[];
  var anchor = '';
  var title = '';

  void flush() {
    if (blocks.isEmpty && title.isEmpty) return;
    sections.add(BookSection(
      index: sections.length,
      anchor: anchor,
      title: title,
      blocks: List.unmodifiable(_mergeFigures(blocks)),
    ));
    blocks.clear();
  }

  for (final element in body.children) {
    final text = _textOf(element);
    if (!_startsSection(element, text)) {
      blocks.addAll(_blocksOf(element, chapterDir));
      continue;
    }

    flush();
    anchor = element.attributes['id'] ?? '';
    final heading = _isHeading(element);
    title = heading || text.length <= _titleLimit ? text : '${text.substring(0, _titleLimit)}…';
    // 标题本身当作小节名，不再重复排一遍正文。
    blocks.addAll(_blocksOf(element, chapterDir, includeText: !heading));
  }
  flush();

  return sections;
}

/// 同一式的起止插图，书里有时放在一个 `<blockquote>` 里、有时分成两个，
/// 合到一起好让阅读页并排显示。
List<BookBlock> _mergeFigures(List<BookBlock> blocks) {
  final merged = <BookBlock>[];
  for (final block in blocks) {
    final last = merged.isEmpty ? null : merged.last;
    if (block is BookFigure && last is BookFigure) {
      merged[merged.length - 1] = BookFigure([...last.imagePaths, ...block.imagePaths]);
    } else {
      merged.add(block);
    }
  }
  return merged;
}

List<BookBlock> _blocksOf(dom.Element element, String chapterDir, {bool includeText = true}) {
  final blocks = <BookBlock>[];
  final text = _textOf(element);
  if (includeText && text.isNotEmpty) blocks.add(BookText(text, _styleOf(element)));

  final images = _imagePathsOf(element, chapterDir);
  if (images.isNotEmpty) blocks.add(BookFigure(images));

  return blocks;
}

BookTextStyle _styleOf(dom.Element element) {
  if (_isHeading(element)) return BookTextStyle.heading;
  if (element.localName == 'blockquote') return BookTextStyle.quote;
  return BookTextStyle.body;
}

/// 小节起点：带 `id` 的块级元素，或「第 X 式 / 第 X 章 / 最终式」这类标题。
///
/// 书里的式标题本该都带锚点，但「第二式上斜俯卧撑」漏了 `id`，所以还要按文字认。
bool _startsSection(dom.Element element, String text) {
  final id = element.attributes['id'];
  if (id != null && id.isNotEmpty && text.isNotEmpty) return true;
  return _isHeading(element) && _seriesTitle.hasMatch(text);
}

/// 整段文字都在加粗标签里、且不长的块，按标题处理（书里的小标题都是这样）。
bool _isHeading(dom.Element element) {
  if (_headingTags.contains(element.localName)) return true;
  final text = _squeeze(_textOf(element));
  if (text.isEmpty || text.length > _headingLimit) return false;
  final bold = _squeeze(element.querySelectorAll('span.bold, strong, b').map(_textOf).join());
  return bold == text;
}

List<String> _imagePathsOf(dom.Element element, String chapterDir) {
  final paths = <String>[];
  final candidates = <dom.Element>[
    if (element.localName == 'img' || element.localName == 'image') element,
    ...element.querySelectorAll('img, image'),
  ];

  for (final image in candidates) {
    final src = _imageSource(image);
    if (src == null) continue;
    final path = _resolve(chapterDir, src);
    if (!paths.contains(path)) paths.add(path);
  }
  return paths;
}

/// 取插图的路径：`<img src>` 普通 HTML 属性，SVG 的 `<image xlink:href>` 则
/// 会被 html 包存成带命名空间的属性（key 是 [dom.AttributeName]，不是字符串），
/// 所以要连 key 一起看。
String? _imageSource(dom.Element image) {
  final src = _attribute(image, 'src');
  if (src != null && src.isNotEmpty) return src;

  for (final entry in image.attributes.entries) {
    if (entry.key.toString().endsWith('href') && entry.value.isNotEmpty) {
      return entry.value;
    }
  }
  return null;
}

String? _attribute(dom.Element element, String name) {
  final direct = element.attributes[name];
  if (direct != null) return direct;
  for (final entry in element.attributes.entries) {
    if (entry.key.toString() == name) return entry.value;
  }
  return null;
}

String _textOf(dom.Element element) =>
    element.text.replaceAll(RegExp(r'[\s\u00a0]+'), ' ').trim();

String _squeeze(String text) => text.replaceAll(RegExp(r'\s+'), '');

// ───────────────────────── 书档读写 ─────────────────────────

Map<String, Uint8List> _collectImages(Archive archive) {
  final images = <String, Uint8List>{};
  for (final file in archive.files) {
    if (!file.isFile) continue;
    if (!_imageExtensions.contains(p.posix.extension(file.name).toLowerCase())) continue;
    images[file.name] = file.content;
  }
  return images;
}

/// 从 `META-INF/container.xml` 读 OPF 路径；读不到就在书里找 `.opf`。
String _opfPath(Archive archive) {
  final container = _readTextOrNull(archive, 'META-INF/container.xml');
  if (container != null) {
    final rootfile = _firstWhere(
      XmlDocument.parse(container).findAllElements('rootfile'),
      (e) => true,
    );
    final path = rootfile?.getAttribute('full-path');
    if (path != null && path.isNotEmpty) return path;
  }

  final opf = _firstWhere(
    archive.files,
    (file) => file.isFile && file.name.toLowerCase().endsWith('.opf'),
  );
  if (opf == null) throw const FormatException('书档里找不到 OPF 文件');
  return opf.name;
}

String? _readTextOrNull(Archive archive, String path) {
  final file = archive.findFile(path);
  return file == null ? null : utf8.decode(file.content, allowMalformed: true);
}

String _readText(Archive archive, String path) {
  final text = _readTextOrNull(archive, path);
  if (text == null) throw FormatException('书档里缺少 $path');
  return text;
}

/// 把书里的相对路径（相对于 OPF 所在目录）解析成书档内路径。
String _resolve(String baseDir, String href) =>
    p.posix.normalize(p.posix.join(baseDir, Uri.decodeFull(href)));

T? _firstWhere<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

// ───────────────────────── 常量 ─────────────────────────

const String _ncxMediaType = 'application/x-dtbncx+xml';

const Set<String> _headingTags = {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'};

const Set<String> _imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'};

/// 这本书里夹了两页来源网站的推广页，阅读器不展示。
const Set<String> _skippedFiles = {'ad_chapter.xhtml', 'ad_chapter12.xhtml'};

final RegExp _seriesTitle = RegExp(r'^(第[一二三四五六七八九十百]+[式章节]|最终式)');

/// 标题超过这个长度就说明锚点是挂在正文段落上的，只在跳转列表里截断显示。
const int _titleLimit = 24;

/// 加粗且不超过这个长度的块才当标题。
const int _headingLimit = 30;

class _ManifestItem {
  const _ManifestItem({
    required this.path,
    required this.mediaType,
    required this.properties,
  });

  final String path;
  final String mediaType;
  final String properties;

  bool get isDocument => mediaType == 'application/xhtml+xml';
}
