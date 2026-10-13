import 'package:flutter_riverpod/flutter_riverpod.dart';

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
