import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/book/book_highlight.dart';
import '../data/book/book_locator.dart';
import '../data/book/book_models.dart';
import '../data/book/epub_parser.dart';
import 'theme_provider.dart';

// ───────────────────────── 书档 ─────────────────────────

/// 整本书的解析结果。书档要解压再解析，只做一次，页面共用同一份。
final bookProvider = FutureProvider<BookDocument>((ref) => loadBookAsset());

/// 六艺十式 → 书中章节与小节的定位。
final bookLocatorProvider = FutureProvider<BookLocator>(
  (ref) async => BookLocator(await ref.watch(bookProvider.future)),
);

// ───────────────────────── 阅读位置 ─────────────────────────

/// 最近读到的位置：哪一章的哪一小节。
class ReadingPosition {
  const ReadingPosition({required this.chapterHref, required this.sectionKey});

  final String chapterHref;
  final String sectionKey;

  @override
  bool operator ==(Object other) =>
      other is ReadingPosition &&
      other.chapterHref == chapterHref &&
      other.sectionKey == sectionKey;

  @override
  int get hashCode => Object.hash(chapterHref, sectionKey);
}

/// 阅读位置记忆：本地保存，下次打开接着读。
class ReadingPositionNotifier extends Notifier<ReadingPosition?> {
  static const _chapterKey = 'book.last_chapter';
  static const _sectionKey = 'book.last_section';

  @override
  ReadingPosition? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final chapterHref = prefs.getString(_chapterKey);
    if (chapterHref == null) return null;
    return ReadingPosition(
      chapterHref: chapterHref,
      sectionKey: prefs.getString(_sectionKey) ?? '',
    );
  }

  /// 记录读到哪一节。滚动会反复上报，位置没变就不写本地。
  Future<void> record({required String chapterHref, required String sectionKey}) async {
    final position =
        ReadingPosition(chapterHref: chapterHref, sectionKey: sectionKey);
    if (state == position) return;
    state = position;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_chapterKey, chapterHref);
    await prefs.setString(_sectionKey, sectionKey);
  }
}

/// 上次读到的位置，没读过时为 null。
final readingPositionProvider =
    NotifierProvider<ReadingPositionNotifier, ReadingPosition?>(
  ReadingPositionNotifier.new,
);

// ───────────────────────── 划线 ─────────────────────────

/// 全书划线：一段 JSON 文本存在本地，重启后还在。
class BookHighlightsNotifier extends Notifier<List<BookHighlight>> {
  static const _key = 'book.highlights';

  @override
  List<BookHighlight> build() =>
      BookHighlight.decodeList(ref.watch(sharedPreferencesProvider).getString(_key));

  /// 画一条划线；同一段同一区间重复画时换成新样式，不留两条。
  Future<void> add(BookHighlight highlight) async {
    if (highlight.end <= highlight.start) return;
    await _save([
      for (final item in state)
        if (!item.sameRange(highlight)) item,
      highlight,
    ]);
  }

  Future<void> remove(BookHighlight highlight) async {
    await _save([
      for (final item in state)
        if (item != highlight) item,
    ]);
  }

  Future<void> _save(List<BookHighlight> highlights) async {
    state = List.unmodifiable(highlights);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, BookHighlight.encodeList(highlights));
  }
}

/// 全部划线，按加入顺序排列。
final bookHighlightsProvider =
    NotifierProvider<BookHighlightsNotifier, List<BookHighlight>>(
  BookHighlightsNotifier.new,
);
