import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_convict_conditioning/data/book/book_locator.dart';
import 'package:ngy_convict_conditioning/data/book/book_models.dart';
import 'package:ngy_convict_conditioning/data/book/epub_parser.dart';
import 'package:ngy_convict_conditioning/data/models/big_six.dart';
import 'package:ngy_convict_conditioning/data/seed/big_six_seed.dart';

/// 六艺各自的书中章节（书里「第二部分：六艺」的六章，按顺序对应六艺）。
const _chapterOf = {
  BigSix.pushup: 'EPUB/index_split_007.html',
  BigSix.squat: 'EPUB/index_split_008.html',
  BigSix.pullup: 'EPUB/index_split_009.html',
  BigSix.legRaise: 'EPUB/index_split_010.html',
  BigSix.bridge: 'EPUB/index_split_011.html',
  BigSix.handstandPushup: 'EPUB/index_split_012.html',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookLocator locator;

  setUpAll(() async {
    locator = BookLocator(await loadBookAsset());
  });

  test('六艺各自定位到自己的章节', () {
    for (final exercise in BigSix.values) {
      final chapter = locator.chapterOf(exercise);
      expect(chapter, isNotNull, reason: '${exercise.label} 找不到章节');
      expect(chapter!.href, _chapterOf[exercise], reason: '${exercise.label} 章节不对');
      // 章内一定有一节标题就是六艺名称，定位靠它。
      expect(chapter.sections.any((s) => s.title == exercise.label), isTrue);
    }
  });

  test('60 式在书中都能定位到对应序号的式', () {
    var located = 0;

    for (final move in kAllMoves) {
      final reference = locator.referenceOf(move.exercise, move.level);

      expect(reference, isNotNull, reason: '${move.exercise.label}第${move.level}式没定位到');
      expect(reference!.chapter.href, _chapterOf[move.exercise]);
      expect(
        BookLocator.seriesLevel(reference.section.title),
        move.level,
        reason: '${move.exercise.label}第${move.level}式对应到了「${reference.section.title}」',
      );
      expect(reference.section.blocks, isNotEmpty);
      located++;
    }

    expect(located, 60);
  });

  test('抽查几式的书名', () {
    String titleOf(BigSix exercise, int level) =>
        locator.sectionOf(exercise, level)!.title;

    expect(titleOf(BigSix.pushup, 1), '第一式墙壁俯卧撑');
    expect(titleOf(BigSix.pushup, 2), '第二式上斜俯卧撑');
    expect(titleOf(BigSix.pushup, 10), '最终式单臂俯卧撑');
    expect(titleOf(BigSix.squat, 10), '最终式单腿深蹲');
    expect(titleOf(BigSix.pullup, 2), '第二式水平引体向上');
    expect(titleOf(BigSix.legRaise, 2), '第二式平卧抬膝');
    expect(titleOf(BigSix.bridge, 4), '第四式顶桥');
    expect(titleOf(BigSix.handstandPushup, 1), '第一式靠墙顶立');
  });

  test('识别式标题的序号', () {
    expect(BookLocator.seriesLevel('第一式短桥'), 1);
    expect(BookLocator.seriesLevel('第九式杠杆倒立撑'), 9);
    expect(BookLocator.seriesLevel('最终式单臂引体向上'), 10);
    expect(BookLocator.seriesLevel('关于第七式偏重深蹲'), isNull);
    expect(BookLocator.seriesLevel('更上一层楼'), isNull);
    expect(BookLocator.seriesLevel('变式'), isNull);
  });

  test('给出可直接跳转的阅读页路由', () {
    final reference = locator.referenceOf(BigSix.legRaise, 3)!;

    expect(reference.route, startsWith('/book/read?chapter='));
    expect(reference.route, contains('index_split_010.html'));
    expect(reference.route, contains('filepos302512'));
  });

  test('目录指向的小节能还原成正文小节', () {
    final entries = <BookTocEntry>[];
    void walk(List<BookTocEntry> list) {
      for (final entry in list) {
        entries.add(entry);
        walk(entry.children);
      }
    }

    walk(locator.book.toc);

    expect(entries, isNotEmpty);
    for (final entry in entries) {
      expect(locator.book.sectionFor(entry), isNotNull, reason: '目录「${entry.title}」找不到正文');
    }
  });
}
