import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_convict_conditioning/data/book/book_highlight.dart';
import 'package:ngy_convict_conditioning/providers/book_provider.dart';
import 'package:ngy_convict_conditioning/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 划线：按划线切正文、存档读写、本地保存。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const paragraph = '一二三四五六七八九十';

  BookHighlight highlight(
    int start,
    int end, {
    HighlightStyle style = HighlightStyle.marker,
    String section = 'filepos1',
    int block = 0,
  }) =>
      BookHighlight(
        chapterHref: 'EPUB/chapter.xhtml',
        sectionKey: section,
        blockIndex: block,
        start: start,
        end: end,
        style: style,
        text: paragraph.substring(start.clamp(0, paragraph.length),
            end.clamp(0, paragraph.length)),
        createdAt: DateTime(2026, 10, 13, 9, 30),
      );

  List<String?> stylesOf(List<HighlightedTextPiece> pieces) =>
      [for (final piece in pieces) piece.style?.name];

  group('按划线切分正文', () {
    test('没有划线时整段一个片段', () {
      final pieces = splitHighlightedText(paragraph, const []);

      expect(pieces, hasLength(1));
      expect(pieces.single.text, paragraph);
      expect(pieces.single.style, isNull);
    });

    test('一条划线把段落切成三段，中间那段带样式', () {
      final pieces = splitHighlightedText(paragraph, [highlight(2, 5)]);

      expect([for (final piece in pieces) piece.text], ['一二', '三四五', '六七八九十']);
      expect(stylesOf(pieces), [null, 'marker', null]);
    });

    test('整段划满就是一段带样式', () {
      final pieces =
          splitHighlightedText(paragraph, [highlight(0, 10, style: HighlightStyle.line)]);

      expect(pieces, hasLength(1));
      expect(pieces.single.text, paragraph);
      expect(pieces.single.style, HighlightStyle.line);
    });

    test('重叠时更短的那条显示在自己的区间上', () {
      final pieces = splitHighlightedText(paragraph, [
        highlight(0, 8, style: HighlightStyle.line),
        highlight(2, 5, style: HighlightStyle.wavy),
      ]);

      expect([for (final piece in pieces) piece.text], ['一二', '三四五', '六七八', '九十']);
      expect(stylesOf(pieces), ['line', 'wavy', 'line', null]);
    });

    test('同样的区间画两次，取后加的那条', () {
      final pieces = splitHighlightedText(paragraph, [
        highlight(2, 5, style: HighlightStyle.marker),
        highlight(2, 5, style: HighlightStyle.wavy),
      ]);

      expect(stylesOf(pieces), [null, 'wavy', null]);
    });

    test('区间超出正文长度或落在正文外时按正文长度截断', () {
      final pieces = splitHighlightedText(paragraph, [highlight(8, 20)]);

      expect([for (final piece in pieces) piece.text], ['一二三四五六七八', '九十']);
      expect(stylesOf(pieces), [null, 'marker']);

      // 完全落在正文之外的（正文被改短的旧划线）不影响排版。
      final stale = splitHighlightedText(paragraph, [highlight(20, 30)]);
      expect(stale, hasLength(1));
      expect(stale.single.text, paragraph);
    });

    test('按段过滤：别的段、别的章的划线不参与', () {
      final all = [
        highlight(0, 2),
        highlight(0, 2, block: 1),
        highlight(0, 2, section: 'filepos2'),
      ];

      final mine = highlightsOfBlock(
        all,
        chapterHref: 'EPUB/chapter.xhtml',
        sectionKey: 'filepos1',
        blockIndex: 0,
      );

      expect(mine, hasLength(1));
      expect(mine.single.blockIndex, 0);
      expect(mine.single.sectionKey, 'filepos1');
    });
  });

  group('划线存档', () {
    test('写出再读回内容不变', () {
      final source = [
        highlight(0, 3, style: HighlightStyle.wavy),
        highlight(5, 8, style: HighlightStyle.line, block: 2),
      ];

      final restored = BookHighlight.decodeList(BookHighlight.encodeList(source));

      expect(restored, source);
      expect(restored.first.style, HighlightStyle.wavy);
      expect(restored.first.createdAt, DateTime(2026, 10, 13, 9, 30));
      expect(restored.last.blockIndex, 2);
    });

    test('空存档就是没有划线', () {
      expect(BookHighlight.decodeList(null), isEmpty);
      expect(BookHighlight.decodeList(''), isEmpty);
      expect(BookHighlight.decodeList('   '), isEmpty);
    });

    test('存档坏掉或条目不全时跳过坏数据', () {
      expect(BookHighlight.decodeList('{不是 JSON'), isEmpty);
      expect(BookHighlight.decodeList('{"a": 1}'), isEmpty);
      expect(BookHighlight.decodeList('[{"chapter":"a"}]'), isEmpty);
      expect(BookHighlight.decodeList('[{"chapter":"a","section":"b","block":0,"start":3,"end":3}]'), isEmpty);

      // 一条好的、一条坏的：只留好的。
      final mixed = BookHighlight.encodeList([highlight(0, 3)]);
      final restored = BookHighlight.decodeList(
        '[{"chapter":"a"},${mixed.substring(1)}',
      );
      expect(restored, hasLength(1));
      expect(restored.single.text, '一二三');
    });

    test('认不出的样式按马克笔处理', () {
      final restored = BookHighlight.decodeList(
        '[{"chapter":"a","section":"b","block":0,"start":0,"end":1,'
        '"style":"sparkle","text":"一"}]',
      );

      expect(restored.single.style, HighlightStyle.marker);
    });
  });

  group('划线本地保存', () {
    Future<ProviderContainer> makeContainer([
      Map<String, Object> values = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(values);
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('没画过线时一条都没有', () async {
      final container = await makeContainer();

      expect(container.read(bookHighlightsProvider), isEmpty);
    });

    test('画线后立即生效并写入本地', () async {
      final container = await makeContainer();
      final prefs = await SharedPreferences.getInstance();

      await container.read(bookHighlightsProvider.notifier).add(highlight(1, 4));

      final saved = container.read(bookHighlightsProvider);
      expect(saved, hasLength(1));
      expect(saved.single.start, 1);
      expect(
        BookHighlight.decodeList(prefs.getString('book.highlights')),
        saved,
      );
    });

    test('同一段同一区间再画一次只换样式，不留两条', () async {
      final container = await makeContainer();
      final notifier = container.read(bookHighlightsProvider.notifier);

      await notifier.add(highlight(1, 4, style: HighlightStyle.marker));
      await notifier.add(highlight(1, 4, style: HighlightStyle.line));

      final saved = container.read(bookHighlightsProvider);
      expect(saved, hasLength(1));
      expect(saved.single.style, HighlightStyle.line);
    });

    test('区间重叠但不同的线都留着，按段记录各自的块', () async {
      final container = await makeContainer();
      final notifier = container.read(bookHighlightsProvider.notifier);

      await notifier.add(highlight(0, 8, style: HighlightStyle.line));
      await notifier.add(highlight(2, 5, style: HighlightStyle.wavy, block: 3));

      expect(container.read(bookHighlightsProvider), hasLength(2));
    });

    test('空白区间（只选到首行缩进）不落库', () async {
      final container = await makeContainer();

      await container.read(bookHighlightsProvider.notifier).add(highlight(3, 3));

      expect(container.read(bookHighlightsProvider), isEmpty);
    });

    test('删掉划线后本地也跟着空', () async {
      final container = await makeContainer();
      final prefs = await SharedPreferences.getInstance();
      final notifier = container.read(bookHighlightsProvider.notifier);
      final line = highlight(1, 4);
      await notifier.add(line);

      await notifier.remove(line);

      expect(container.read(bookHighlightsProvider), isEmpty);
      expect(
        BookHighlight.decodeList(prefs.getString('book.highlights')),
        isEmpty,
      );
    });

    test('下次打开沿用本地记录的划线', () async {
      final saved = [highlight(0, 3, style: HighlightStyle.wavy)];
      final container = await makeContainer({
        'flutter.book.highlights': BookHighlight.encodeList(saved),
      });

      final restored = container.read(bookHighlightsProvider);

      expect(restored, hasLength(1));
      expect(restored.single.style, HighlightStyle.wavy);
      expect(restored.single.chapterHref, 'EPUB/chapter.xhtml');
    });
  });
}
