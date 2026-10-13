import '../models/big_six.dart';
import 'book_models.dart';

/// 某一式在书里的位置：哪一章的哪一小节。
class BookReference {
  const BookReference({required this.chapter, required this.section});

  final BookChapter chapter;
  final BookSection section;

  /// 阅读页的路由。
  String get route => bookReaderRoute(chapter, section);
}

/// 阅读页路由：章用书档内路径、小节用锚点，都放在查询参数里（路径里带 `/` 不方便）。
String bookReaderRoute(BookChapter chapter, [BookSection? section]) {
  final query = {
    'chapter': chapter.href,
    if (section != null) 'section': section.key,
  };
  return Uri(path: '/book/read', queryParameters: query).toString();
}

/// 把 App 的「六艺十式」对应到书中章节与小节。
///
/// 书里「第二部分：六艺」的六章，每章开头都有一节标题正好是六艺名称
/// （俯卧撑 / 深蹲 / 引体向上 / 举腿 / 桥 / 倒立撑），其后依次是
/// 「第一式…」到「第九式…」和「最终式…」，所以按序号即可对上十式。
/// 书的用词与 App 的动作库并不完全一致（书里「平卧抬膝」对应
/// App 的「平躺屈膝抬腿」），因此只按序号与章节对应，不按名称匹配。
class BookLocator {
  const BookLocator(this.book);

  final BookDocument book;

  /// 六艺对应的书中章节。
  BookChapter? chapterOf(BigSix exercise) {
    for (final chapter in book.chapters) {
      for (final section in chapter.sections) {
        if (section.title.trim() == exercise.label) return chapter;
      }
    }
    return null;
  }

  /// 第 [level] 式在书中对应的小节。
  BookSection? sectionOf(BigSix exercise, int level) {
    final chapter = chapterOf(exercise);
    if (chapter == null) return null;
    for (final section in chapter.sections) {
      if (seriesLevel(section.title) == level) return section;
    }
    return null;
  }

  /// 某一式在书中的位置；书里找不到时返回 null。
  BookReference? referenceOf(BigSix exercise, int level) {
    final chapter = chapterOf(exercise);
    final section = sectionOf(exercise, level);
    if (chapter == null || section == null) return null;
    return BookReference(chapter: chapter, section: section);
  }

  /// 「第一式墙壁俯卧撑」→ 1，「最终式单臂俯卧撑」→ 10，其它标题 → null。
  static int? seriesLevel(String title) {
    final text = title.trim();
    if (text.startsWith('最终式')) return 10;
    final match = _seriesPattern.firstMatch(text);
    return match == null ? null : _chineseDigits[match.group(1)];
  }

  static final RegExp _seriesPattern = RegExp(r'^第([一二三四五六七八九十]+)式');

  /// 书里「第 N 式」只用到一~十。
  static const Map<String, int> _chineseDigits = {
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
    '十': 10,
  };
}
