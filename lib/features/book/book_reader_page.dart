import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/book/book_models.dart';
import '../../providers/book_provider.dart';

/// 正文阅读页：按小节顺序排版一章，支持跳到指定小节并记住读到哪一节。
///
/// 一章整段渲染（一章最多几十个小节、几百段，比按需构建更省心），
/// 这样跳到章内任何小节都能直接滚动到位。
class BookReaderPage extends ConsumerStatefulWidget {
  const BookReaderPage({super.key, required this.chapterHref, this.sectionKey});

  /// 要读的章（书档内路径）。
  final String chapterHref;

  /// 打开时要滚到的小节；为空则从章首开始。
  final String? sectionKey;

  @override
  ConsumerState<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends ConsumerState<BookReaderPage> {
  final _scrollController = ScrollController();
  final _sectionKeys = <String, GlobalKey>{};
  var _jumped = false;

  /// 刚跳过去的小节。插图解码后会把正文撑高，得再对齐几次，
  /// 否则深链的落点会被上面的图顶走一屏。
  BookSection? _pendingTarget;
  var _realignments = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyOf(BookSection section) =>
      _sectionKeys.putIfAbsent(section.key, GlobalKey.new);

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookProvider);
    final chapter = bookAsync.value?.chapterOf(widget.chapterHref);
    // 封面页、版权页这类章没有标题，退回书名。
    final title = chapter == null || chapter.title.isEmpty
        ? bookAsync.value?.meta.title ?? '阅读'
        : chapter.title;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (chapter != null)
            IconButton(
              tooltip: '本章小节',
              onPressed: () => _showSections(chapter),
              icon: const Icon(Icons.toc_outlined),
            ),
        ],
      ),
      body: bookAsync.when(
        data: (book) {
          final chapter = book.chapterOf(widget.chapterHref);
          if (chapter == null) return const Center(child: Text('这一章不在书里'));

          _jumpToInitial(chapter);
          final viewportTop = MediaQuery.paddingOf(context).top + kToolbarHeight;

          return NotificationListener<ScrollMetricsNotification>(
            // 内容高度变化（插图解码完成）时，把跳转目标重新顶到最上面。
            onNotification: (_) {
              _realignTarget();
              return false;
            },
            child: NotificationListener<ScrollStartNotification>(
              onNotification: (notification) {
                // 用户自己开始拖动就不再干预。
                if (notification.dragDetails != null) _pendingTarget = null;
                return false;
              },
              child: NotificationListener<ScrollEndNotification>(
                onNotification: (_) {
                  _recordPosition(chapter, viewportTop);
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final section in chapter.sections)
                        _SectionView(
                          key: _keyOf(section),
                          section: section,
                          book: book,
                          isFirst: section.index == 0,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
      ),
    );
  }

  /// 第一次构建后滚到目标小节（来自目录或六艺页），并把位置记下来。
  void _jumpToInitial(BookChapter chapter) {
    if (_jumped || chapter.sections.isEmpty) return;
    _jumped = true;

    final target = widget.sectionKey == null
        ? chapter.sections.first
        : chapter.sectionByKey(widget.sectionKey!) ?? chapter.sections.first;
    _trackTarget(target);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollTo(target);
      _recordPosition(chapter, MediaQuery.paddingOf(context).top + kToolbarHeight);
    });
  }

  /// 记下要停留的小节，等插图解码把内容撑高后再重新对齐。
  void _trackTarget(BookSection section) {
    _pendingTarget = section;
    _realignments = 0;
  }

  void _realignTarget() {
    final target = _pendingTarget;
    if (target == null || _realignments >= 6) return;
    _realignments++;
    _scrollTo(target, animated: false);
  }

  void _scrollTo(BookSection section, {bool animated = true}) {
    final context = _sectionKeys[section.key]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: animated ? const Duration(milliseconds: 220) : Duration.zero,
      alignment: 0,
    );
  }

  /// 记住视口顶部正在读的那一节；滚到底时记最后一节。
  void _recordPosition(BookChapter chapter, double viewportTop) {
    if (chapter.sections.isEmpty) return;

    var current = chapter.sections.first;
    for (final section in chapter.sections) {
      final box = _sectionKeys[section.key]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      if (box.localToGlobal(Offset.zero).dy > viewportTop + 24) break;
      current = section;
    }

    final position = _scrollController.hasClients ? _scrollController.position : null;
    if (position != null && position.pixels >= position.maxScrollExtent - 4) {
      current = chapter.sections.last;
    }

    ref.read(readingPositionProvider.notifier).record(
          chapterHref: chapter.href,
          sectionKey: current.key,
        );
  }

  Future<void> _showSections(BookChapter chapter) async {
    final selected = await showModalBottomSheet<BookSection>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (final section in chapter.sections)
            ListTile(
              dense: true,
              title: Text(
                section.title.isEmpty ? '第 ${section.index + 1} 节' : section.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(context).pop(section),
            ),
        ],
      ),
    );

    if (selected == null || !mounted) return;
    _trackTarget(selected);
    _scrollTo(selected);
  }
}

/// 一个小节：小节名 + 它的正文块。
class _SectionView extends StatelessWidget {
  const _SectionView({
    super.key,
    required this.section,
    required this.book,
    required this.isFirst,
  });

  final BookSection section;
  final BookDocument book;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.title.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: isFirst ? 6 : 26, bottom: 10),
            child: Text(
              section.title,
              style: isFirst
                  ? theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    )
                  : theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
            ),
          ),
        for (final block in section.blocks) _BlockView(block: block, book: book),
      ],
    );
  }
}

/// 一个正文块：文字按版式排版，插图并排显示。
class _BlockView extends StatelessWidget {
  const _BlockView({required this.block, required this.book});

  final BookBlock block;
  final BookDocument book;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      BookText(:final text, :final style) => _text(context, text, style),
      BookFigure(:final imagePaths) => _figure(context, imagePaths),
    };
  }

  Widget _text(BuildContext context, String text, BookTextStyle style) {
    final theme = Theme.of(context);

    return switch (style) {
      BookTextStyle.heading => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      BookTextStyle.body => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            // 中文正文首行缩进两格。
            '\u3000\u3000$text',
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
          ),
        ),
      BookTextStyle.quote => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
    };
  }

  Widget _figure(BuildContext context, List<String> imagePaths) {
    final images = <Uint8List>[
      for (final path in imagePaths) ?book.imageBytes(path),
    ];
    if (images.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final bytes in images)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
