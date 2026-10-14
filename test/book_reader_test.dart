import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ngy_convict_conditioning/core/theme.dart';
import 'package:ngy_convict_conditioning/data/book/book_highlight.dart';
import 'package:ngy_convict_conditioning/data/book/book_locator.dart';
import 'package:ngy_convict_conditioning/data/models/big_six.dart';
import 'package:ngy_convict_conditioning/features/book/book_page.dart';
import 'package:ngy_convict_conditioning/features/book/book_reader_page.dart';
import 'package:ngy_convict_conditioning/features/book/highlightable_text.dart';
import 'package:ngy_convict_conditioning/providers/book_provider.dart';
import 'package:ngy_convict_conditioning/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读界面：封面与目录、正文分节排版、选中划线、按路由打开指定小节。
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

  /// 正文里的一段：找第一段以 [prefix] 开头的文字。
  Finder paragraphStartingWith(String prefix) => find.byWidgetPredicate(
        (widget) => widget is HighlightableText && widget.text.startsWith(prefix),
      );

  /// 选中一段正文并弹出工具条。
  ///
  /// 长按选中要按坐标猜落点，测试里直接给选区：偏移是排版文字的偏移，
  /// 正文段会多带两格首行缩进。
  Future<EditableTextState> selectParagraph(
    WidgetTester tester,
    Finder paragraph, {
    int from = 2,
    int to = 8,
  }) async {
    final state = tester.state<EditableTextState>(
      find.descendant(of: paragraph, matching: find.byType(EditableText)),
    );
    state.userUpdateTextEditingValue(
      state.textEditingValue.copyWith(
        selection: TextSelection(baseOffset: from, extentOffset: to),
      ),
      SelectionChangedCause.longPress,
    );
    await tester.pump();
    state.showToolbar();
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('选中正文弹出工具条：复制与三种划线，没有写想法与 AI 问书', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(wrap(const BookReaderPage(
      chapterHref: 'EPUB/index_split_007.html',
      sectionKey: 'filepos104555',
    )));
    await tester.pumpAndSettle();

    final paragraph = paragraphStartingWith('初级标准');
    expect(paragraph, findsWidgets);
    final target = tester.widget<HighlightableText>(paragraph.first);
    final start = 2 - target.indent.length;
    final end = 8 - target.indent.length;

    await selectParagraph(tester, paragraph.first);

    expect(find.text('复制'), findsOneWidget);
    expect(find.text('马克笔'), findsOneWidget);
    expect(find.text('波浪线'), findsOneWidget);
    expect(find.text('直线'), findsOneWidget);
    expect(find.text('写想法'), findsNothing);
    expect(find.text('AI问书'), findsNothing);

    // 工具条要贴在选区上方：整条排在一行里，高度符合选择工具条的限制（44）。
    final pill = tester.getSize(
      find.ancestor(of: find.text('马克笔'), matching: find.byType(Material)).first,
    );
    expect(pill.height, lessThanOrEqualTo(44));
    expect(pill.width, greaterThan(pill.height));

    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();

    expect(copied, target.text.substring(start, end));

    await selectParagraph(tester, paragraph.first);
    await tester.tap(find.text('马克笔'));
    await tester.pumpAndSettle();

    final highlights = container.read(bookHighlightsProvider);
    expect(highlights, hasLength(1));
    expect(highlights.single.style, HighlightStyle.marker);
    expect(highlights.single.chapterHref, 'EPUB/index_split_007.html');
    expect(highlights.single.sectionKey, target.sectionKey);
    expect(highlights.single.blockIndex, target.blockIndex);
    expect(highlights.single.start, start);
    expect(highlights.single.end, end);
    expect(highlights.single.text, target.text.substring(start, end));

    // 划线立刻画在正文上：选中的那段带底色，其余照旧。
    final selectable = tester.widget<SelectableText>(
      find.descendant(of: paragraph.first, matching: find.byType(SelectableText)),
    );
    final marked = [
      for (final span in selectable.textSpan!.children!.cast<TextSpan>())
        if (span.style?.backgroundColor != null) span,
    ];
    expect(marked, hasLength(1));
    expect(marked.single.text, target.text.substring(start, end));
  });

  testWidgets('桌面鼠标拖选正文后弹出工具条，可以直接划线', (tester) async {
    // 桌面框架只对触摸/触控笔自动弹工具条，鼠标这条是自己补的，别再被改回去。
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(wrap(const BookReaderPage(
        chapterHref: 'EPUB/index_split_007.html',
        sectionKey: 'filepos104555',
      )));
      await tester.pumpAndSettle();

      final paragraph = paragraphStartingWith('初级标准').first;
      await tester.ensureVisible(paragraph);
      await tester.pumpAndSettle();

      final left = tester.getTopLeft(paragraph);
      final gesture = await tester.startGesture(
        Offset(left.dx + 20, left.dy + 10),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveTo(Offset(left.dx + 80, left.dy + 10));
      await tester.pump();
      await gesture.moveTo(Offset(left.dx + 160, left.dy + 10));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('马克笔'), findsOneWidget);

      await tester.tap(find.text('直线'));
      await tester.pumpAndSettle();

      final highlights = container.read(bookHighlightsProvider);
      expect(highlights, hasLength(1));
      expect(highlights.single.style, HighlightStyle.line);
      expect(highlights.single.text, isNotEmpty);
      expect(highlights.single.end, greaterThan(highlights.single.start));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('手机长按选中正文后弹出工具条，可以直接划线', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(wrap(const BookReaderPage(
        chapterHref: 'EPUB/index_split_007.html',
        sectionKey: 'filepos104555',
      )));
      await tester.pumpAndSettle();

      final paragraph = paragraphStartingWith('初级标准').first;
      await tester.ensureVisible(paragraph);
      await tester.pumpAndSettle();

      final left = tester.getTopLeft(paragraph);
      await tester.longPressAt(Offset(left.dx + 60, left.dy + 10));
      await tester.pumpAndSettle();

      expect(find.text('波浪线'), findsOneWidget);

      await tester.tap(find.text('波浪线'));
      await tester.pumpAndSettle();

      final highlights = container.read(bookHighlightsProvider);
      expect(highlights, hasLength(1));
      expect(highlights.single.style, HighlightStyle.wavy);
      expect(highlights.single.text, isNotEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('本章划线列表：点一条跳回划线处，也能删掉划线', (tester) async {
    await container.read(bookHighlightsProvider.notifier).add(
          BookHighlight(
            chapterHref: 'EPUB/index_split_011.html',
            sectionKey: 'filepos341250',
            blockIndex: 0,
            start: 0,
            end: 4,
            style: HighlightStyle.wavy,
            text: '脊柱保持中立',
            createdAt: DateTime(2026, 10, 13),
          ),
        );

    await tester.pumpWidget(wrap(const BookReaderPage(
      chapterHref: 'EPUB/index_split_011.html',
      sectionKey: 'filepos360339',
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('本章划线'));
    await tester.pumpAndSettle();

    final item = find.text('脊柱保持中立');
    expect(item, findsOneWidget);
    expect(find.text('波浪线 · 训练脊柱'), findsOneWidget);

    await tester.tap(item);
    await tester.pumpAndSettle();

    expect(container.read(readingPositionProvider)?.sectionKey, 'filepos341250');

    await tester.tap(find.byTooltip('本章划线'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除划线'));
    await tester.pumpAndSettle();

    expect(container.read(bookHighlightsProvider), isEmpty);
    expect(find.text('这一章还没有划线'), findsOneWidget);
    expect(find.byTooltip('本章划线'), findsNothing);
  });
}
