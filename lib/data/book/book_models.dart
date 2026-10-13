import 'dart:typed_data';

/// 《囚徒健身》电子书的数据模型。
///
/// 书档只在启动后解析一次（见 `epub_parser.dart`），解析结果都是不可变对象，
/// 页面层只负责渲染，不再碰 zip / html。

/// 书的元数据。
class BookMeta {
  const BookMeta({
    required this.title,
    required this.author,
    required this.language,
    this.coverImagePath,
  });

  final String title;
  final String author;
  final String language;

  /// 封面插图在书档内的路径；书里没有封面时为 null。
  final String? coverImagePath;
}

/// 正文块的版式：小节标题、正文段落、引文。
enum BookTextStyle { heading, body, quote }

/// 正文块：一段文字，或一组并排的插图。
///
/// 书里用两张图表示一个动作的起止姿势，所以插图按「一组」组织。
sealed class BookBlock {
  const BookBlock();
}

/// 一段文字。
final class BookText extends BookBlock {
  const BookText(this.text, this.style);

  final String text;
  final BookTextStyle style;
}

/// 一组插图。
final class BookFigure extends BookBlock {
  const BookFigure(this.imagePaths);

  /// 书档内的图片路径，用 [BookDocument.imageBytes] 取字节。
  final List<String> imagePaths;
}

/// 小节：章内一个可跳转的片段，例如「第一式墙壁俯卧撑」。
class BookSection {
  const BookSection({
    required this.index,
    required this.anchor,
    required this.title,
    required this.blocks,
  });

  /// 章内顺序，从 0 开始。
  final int index;

  /// 书里的锚点 id；没有锚点的小节（如书里漏了 id 的「第二式上斜俯卧撑」）为空串。
  final String anchor;

  /// 小节标题。
  final String title;

  /// 小节正文。
  final List<BookBlock> blocks;

  /// 跳转与记忆阅读位置用的稳定标识。
  String get key => anchor.isEmpty ? 'i$index' : anchor;
}

/// 一章 = 书档里的一个正文文档。
class BookChapter {
  BookChapter({
    required this.href,
    required this.title,
    required List<BookSection> sections,
  }) : sections = List.unmodifiable(sections);

  /// 书档内的路径，例如 `EPUB/index_split_007.html`。
  final String href;

  final String title;
  final List<BookSection> sections;

  BookSection? sectionByKey(String key) {
    for (final section in sections) {
      if (section.key == key) return section;
    }
    return null;
  }
}

/// 目录条目，保留书里 `toc.ncx` 的层级（部分 → 章 → 节）。
class BookTocEntry {
  BookTocEntry({
    required this.title,
    required this.href,
    this.fragment,
    List<BookTocEntry> children = const [],
  }) : children = List.unmodifiable(children);

  final String title;

  /// 目录指向的章（书档内路径）。
  final String href;

  /// 章内锚点，指向小节；为空表示指向整章。
  final String? fragment;

  final List<BookTocEntry> children;

  bool get hasChildren => children.isNotEmpty;
}

/// 解析完成的整本书。
class BookDocument {
  BookDocument({
    required this.meta,
    required List<BookChapter> chapters,
    required List<BookTocEntry> toc,
    Map<String, Uint8List> images = const {},
  })  : chapters = List.unmodifiable(chapters),
        toc = List.unmodifiable(toc),
        images = Map.unmodifiable(images);

  final BookMeta meta;

  /// 按书里的正文顺序排列的章。
  final List<BookChapter> chapters;

  /// 目录树。
  final List<BookTocEntry> toc;

  /// 书档内的插图：路径 → 字节。
  final Map<String, Uint8List> images;

  Uint8List? imageBytes(String path) => images[path];

  BookChapter? chapterOf(String href) {
    for (final chapter in chapters) {
      if (chapter.href == href) return chapter;
    }
    return null;
  }

  /// 目录条目对应的正文小节（条目只指向整章时返回该章首个小节）。
  BookSection? sectionFor(BookTocEntry entry) {
    final chapter = chapterOf(entry.href);
    if (chapter == null || chapter.sections.isEmpty) return null;
    final fragment = entry.fragment;
    if (fragment == null) return chapter.sections.first;
    return chapter.sectionByKey(fragment) ?? chapter.sections.first;
  }
}
