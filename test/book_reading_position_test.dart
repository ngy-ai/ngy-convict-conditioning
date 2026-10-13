import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_convict_conditioning/providers/book_provider.dart';
import 'package:ngy_convict_conditioning/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读位置记忆：本地保存，下次打开接着读。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> makeContainer([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('没读过时没有位置', () async {
    final container = await makeContainer();

    expect(container.read(readingPositionProvider), isNull);
  });

  test('记录位置后立即生效并写入本地', () async {
    final container = await makeContainer();
    final prefs = await SharedPreferences.getInstance();

    await container.read(readingPositionProvider.notifier).record(
          chapterHref: 'EPUB/index_split_007.html',
          sectionKey: 'filepos104555',
        );

    expect(
      container.read(readingPositionProvider),
      const ReadingPosition(
        chapterHref: 'EPUB/index_split_007.html',
        sectionKey: 'filepos104555',
      ),
    );
    expect(prefs.getString('book.last_chapter'), 'EPUB/index_split_007.html');
    expect(prefs.getString('book.last_section'), 'filepos104555');
  });

  test('下次打开沿用本地记录的位置', () async {
    final container = await makeContainer({
      'flutter.book.last_chapter': 'EPUB/index_split_011.html',
      'flutter.book.last_section': 'filepos383602',
    });

    final position = container.read(readingPositionProvider);

    expect(position?.chapterHref, 'EPUB/index_split_011.html');
    expect(position?.sectionKey, 'filepos383602');
  });

  test('位置没变就不重复写入', () async {
    final container = await makeContainer();
    final notifier = container.read(readingPositionProvider.notifier);

    await notifier.record(chapterHref: 'a', sectionKey: 'b');
    final first = container.read(readingPositionProvider);
    await notifier.record(chapterHref: 'a', sectionKey: 'b');

    expect(container.read(readingPositionProvider), same(first));
  });
}
