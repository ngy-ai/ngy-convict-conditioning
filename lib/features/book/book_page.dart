import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/book/book_locator.dart';
import '../../data/book/book_models.dart';
import '../../providers/book_provider.dart';

/// 原书入口：封面、继续阅读与目录。
class BookPage extends ConsumerWidget {
  const BookPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('原书阅读')),
      body: bookAsync.when(
        data: (book) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _CoverCard(book: book),
            const SizedBox(height: 22),
            for (final entry in book.toc) ...[
              _TocPart(entry: entry, book: book),
              const SizedBox(height: 16),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
      ),
    );
  }
}

/// 封面 + 继续阅读。读过就接着上次的小节读，没读过就从第一章开始。
class _CoverCard extends ConsumerWidget {
  const _CoverCard({required this.book});

  final BookDocument book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coverPath = book.meta.coverImagePath;
    final cover = coverPath == null ? null : book.imageBytes(coverPath);

    final position = ref.watch(readingPositionProvider);
    final lastChapter = position == null ? null : book.chapterOf(position.chapterHref);
    final lastSection = position == null
        ? null
        : lastChapter?.sectionByKey(position.sectionKey);
    final target = lastChapter ?? (book.chapters.isEmpty ? null : book.chapters.first);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cover != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(cover, width: 96, fit: BoxFit.cover),
          ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.meta.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                book.meta.author,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (lastSection != null) ...[
                Text(
                  lastChapter!.title.isEmpty ? book.meta.title : lastChapter.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (lastSection.title.isNotEmpty)
                  Text(
                    lastSection.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ] else
                Text(
                  '共 ${book.chapters.length} 章',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 14),
              if (target != null)
                FilledButton.tonal(
                  onPressed: () => context.push(bookReaderRoute(target, lastSection)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(lastSection == null ? '开始阅读' : '继续阅读'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 目录里的一部分：部分标题 + 它下面各章。
class _TocPart extends StatelessWidget {
  const _TocPart({required this.entry, required this.book});

  final BookTocEntry entry;
  final BookDocument book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chapters = entry.hasChildren ? entry.children : [entry];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            entry.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < chapters.length; index++) ...[
                if (index > 0)
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
                ListTile(
                  title: Text(chapters[index].title),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.outline,
                  ),
                  onTap: () => _open(context, chapters[index]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, BookTocEntry target) {
    final chapter = book.chapterOf(target.href);
    if (chapter == null) return;
    context.push(bookReaderRoute(chapter, book.sectionFor(target)));
  }
}
