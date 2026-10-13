import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_convict_conditioning/data/book/book_models.dart';
import 'package:ngy_convict_conditioning/data/book/epub_parser.dart';

/// 跑真实书档（assets/book/convict_conditioning.epub），确认解析结果能直接喂给阅读页。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookDocument book;

  setUpAll(() async {
    book = await loadBookAsset();
  });

  List<String> sectionTitles(String href) =>
      book.chapterOf(href)!.sections.map((s) => s.title).toList();

  BookTocEntry? findEntry(List<BookTocEntry> entries, String title) {
    for (final entry in entries) {
      if (entry.title == title) return entry;
      final found = findEntry(entry.children, title);
      if (found != null) return found;
    }
    return null;
  }

  test('读出书名、作者、语言与封面', () {
    expect(book.meta.title, '囚徒健身');
    expect(book.meta.author, '保罗•威德');
    expect(book.meta.language, 'zh');

    final cover = book.imageBytes(book.meta.coverImagePath!);
    expect(cover, isNotNull);
    // JPEG 的文件头。
    expect(cover!.take(2).toList(), [0xFF, 0xD8]);
  });

  test('目录取到三个部分，第二部分是六艺的六章', () {
    expect(
      book.toc.map((e) => e.title).toList(),
      ['第一部分：预备', '第二部分：六艺', '第三部分：自我指导', '制作者'],
    );

    final sixArts = book.toc[1].children.map((e) => e.title).toList();
    expect(sixArts.length, 6);
    expect(sixArts.first, '第五章铠甲般的胸肌与钢铁般的肱三头肌');
    expect(sixArts.last, '第十章健康、强力的肩膀');

    // 目录能直接落到正文小节上（「第一式墙壁俯卧撑」挂在「俯卧撑」下面）。
    final entry = findEntry(book.toc, '第一式墙壁俯卧撑')!;
    final section = book.sectionFor(entry);
    expect(section?.anchor, 'filepos104555');
    expect(section?.blocks, isNotEmpty);
  });

  test('按正文顺序给出每一章，并剔除来源网站的推广页', () {
    final hrefs = book.chapters.map((c) => c.href).toList();

    expect(hrefs.first, 'EPUB/titlepage.xhtml');
    expect(hrefs.contains('EPUB/ad_chapter.xhtml'), isFalse);
    expect(hrefs.contains('EPUB/ad_chapter12.xhtml'), isFalse);
    expect(book.chapters.every((c) => c.sections.isNotEmpty), isTrue);
    // 目录里没有的章（封面页）标题留空，界面上用书名兜底，不暴露文件名。
    expect(hrefs.where((h) => h.contains('.xhtml')), isNotEmpty);
    expect(book.chapters.every((c) => !c.title.contains('.xhtml')), isTrue);
    expect(book.chapterOf('EPUB/titlepage.xhtml')!.title, isEmpty);
    expect(book.chapterOf('EPUB/index_split_007.html')!.title, '第五章铠甲般的胸肌与钢铁般的肱三头肌');
  });

  test('俯卧撑章分成十式小节，包括书里漏了锚点的第二式', () {
    final titles = sectionTitles('EPUB/index_split_007.html');

    expect(titles, contains('第五章铠甲般的胸肌与钢铁般的肱三头肌'));
    expect(titles, contains('第一式墙壁俯卧撑'));
    expect(titles, contains('第二式上斜俯卧撑'));
    expect(titles, contains('最终式单臂俯卧撑'));
    expect(
      titles.where((t) => RegExp(r'^(第[一二三四五六七八九十]+式|最终式)').hasMatch(t)).length,
      10,
    );

    final second = book.chapterOf('EPUB/index_split_007.html')!.sections
        .firstWhere((s) => s.title == '第二式上斜俯卧撑');
    expect(second.anchor, isEmpty);
    expect(second.key, 'i${second.index}');
  });

  test('小节正文分出标题、段落、引文与插图', () {
    final section = book
        .chapterOf('EPUB/index_split_007.html')!
        .sections
        .firstWhere((s) => s.title == '第一式墙壁俯卧撑');

    // 书里「解析」这个小标题和正文挤在同一个 <p> 里，所以只当正文，不是标题。
    final headings = section.blocks.whereType<BookText>().where((b) => b.style == BookTextStyle.heading);
    expect(headings.map((b) => b.text), ['动作', '训练目标', '稳扎稳打']);
    expect(
      section.blocks.whereType<BookText>().any((b) => b.text.startsWith('解析俯卧撑动作共有十式')),
      isTrue,
    );

    final quotes = section.blocks.whereType<BookText>().where((b) => b.style == BookTextStyle.quote);
    expect(quotes.map((b) => b.text), contains('初级标准：1 组，10 次'));

    final body = section.blocks.whereType<BookText>().where((b) => b.style == BookTextStyle.body);
    expect(body, isNotEmpty);

    // 起止两张插图都能取到字节。
    final figures = section.blocks.whereType<BookFigure>().toList();
    expect(figures, hasLength(1));
    expect(figures.first.imagePaths, hasLength(2));
    for (final path in figures.first.imagePaths) {
      expect(path, startsWith('EPUB/images/'));
      expect(book.imageBytes(path), isNotNull);
    }
  });

  test('封面页的 SVG 插图也能识别成插图块', () {
    final cover = book.chapterOf('EPUB/titlepage.xhtml');
    final figures = cover!.sections.expand((s) => s.blocks).whereType<BookFigure>().toList();

    expect(figures, isNotEmpty);
    expect(figures.first.imagePaths.single, book.meta.coverImagePath);
  });
}
