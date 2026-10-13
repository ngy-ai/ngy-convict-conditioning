import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ngy_convict_conditioning/core/theme.dart';
import 'package:ngy_convict_conditioning/data/book/book_locator.dart';
import 'package:ngy_convict_conditioning/data/models/big_six.dart';
import 'package:ngy_convict_conditioning/features/book/book_page.dart';
import 'package:ngy_convict_conditioning/features/book/book_reader_page.dart';
import 'package:ngy_convict_conditioning/providers/book_provider.dart';
import 'package:ngy_convict_conditioning/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读界面：封面与目录、正文分节排版、按路由打开指定小节。
///
/// 书档在 setUp 里解析（testWidgets 体内 await provider 会卡在假异步区），
/// 用例里只做同步读取与 pump。
void main() {
  late ProviderContainer container;
  late BookLocator locator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    // 先把书档解析完，页面首帧就能拿到数据。
    locator = BookLocator(await container.read(bookProvider.future));
  });

  tearDown(() => container.dispose());

  Widget wrap(Widget child) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: child,
        ),
      );

  testWidgets('封面页给出书名、作者、继续阅读与目录', (tester) async {
    await tester.pumpWidget(wrap(const BookPage()));
    await tester.pumpAndSettle();

    expect(find.text('囚徒健身'), findsOneWidget);
    expect(find.text('保罗•威德'), findsOneWidget);
    expect(find.text('开始阅读'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    expect(find.text('第二部分：六艺'), findsOneWidget);
    expect(find.text('第五章铠甲般的胸肌与钢铁般的肱三头肌'), findsOneWidget);
    expect(find.text('第十章健康、强力的肩膀'), findsOneWidget);
  });

  testWidgets('没有目录标题的章（封面页）用书名当标题', (tester) async {
    await tester.pumpWidget(wrap(const BookReaderPage(
      chapterHref: 'EPUB/titlepage.xhtml',
    )));
    await tester.pumpAndSettle();

    expect(find.text('囚徒健身'), findsOneWidget);
    expect(find.text('titlepage.xhtml'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('正文按小节排版，插图与版式都在', (tester) async {
    await tester.pumpWidget(wrap(const BookReaderPage(
      chapterHref: 'EPUB/index_split_007.html',
      sectionKey: 'filepos104555',
    )));
    await tester.pumpAndSettle();

    // 章标题（AppBar + 章首小节）与式标题。
    expect(find.text('第五章铠甲般的胸肌与钢铁般的肱三头肌'), findsWidgets);
    expect(find.text('第一式墙壁俯卧撑'), findsOneWidget);
    // 整章都在树上（一屏之外的小节也构建好了），所以小标题会有多个。
    expect(find.text('动作'), findsWidgets);
    expect(find.text('初级标准：1 组，10 次'), findsWidgets);
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('打开阅读页就把读到的位置记下来', (tester) async {
    await tester.pumpWidget(wrap(const BookReaderPage(
      chapterHref: 'EPUB/index_split_007.html',
      sectionKey: 'filepos104555',
    )));
    await tester.pumpAndSettle();

    final position = container.read(readingPositionProvider);

    expect(position?.chapterHref, 'EPUB/index_split_007.html');
    expect(position?.sectionKey, 'filepos104555');
  });

  testWidgets('小节列表里的跳转按钮能换到别的式', (tester) async {
    await tester.pumpWidget(wrap(const BookReaderPage(
      chapterHref: 'EPUB/index_split_011.html',
      sectionKey: 'filepos360339',
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('本章小节'));
    await tester.pumpAndSettle();

    // 弹层只构建可见的几项，挑一项看得到的：正文里也有同名标题，
    // 所以限定在弹层的 ListTile 上点。
    final sheetItem = find.descendant(
      of: find.byType(ListTile),
      matching: find.text('训练脊柱'),
    );
    expect(sheetItem, findsOneWidget);

    await tester.tap(sheetItem);
    await tester.pumpAndSettle();

    expect(container.read(readingPositionProvider)?.sectionKey, 'filepos341250');
  });

  testWidgets('路由参数能还原出章与小节（章路径里带斜杠）', (tester) async {
    final route = locator.referenceOf(BigSix.pullup, 5)!.route;

    final router = GoRouter(
      initialLocation: route,
      routes: [
        GoRoute(
          path: '/book/read',
          builder: (context, state) => BookReaderPage(
            chapterHref: state.uri.queryParameters['chapter'] ?? '',
            sectionKey: state.uri.queryParameters['section'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('第五式标准引体向上'), findsOneWidget);
    expect(container.read(readingPositionProvider)?.chapterHref, 'EPUB/index_split_009.html');
    expect(container.read(readingPositionProvider)?.sectionKey, 'filepos250625');
  });
}
