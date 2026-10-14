import 'dart:convert';

/// 划线的三种样式：马克笔（底色）、波浪线、直线（下划线）。
enum HighlightStyle {
  marker('马克笔'),
  wavy('波浪线'),
  line('直线');

  const HighlightStyle(this.label);

  /// 工具条与划线列表里显示的样式名。
  final String label;

  /// 本地存档里的标识；认不出的（手改过的档）按马克笔处理。
  static HighlightStyle fromName(Object? name) => values.firstWhere(
        (style) => style.name == name,
        orElse: () => HighlightStyle.marker,
      );
}

/// 一条划线：某章、某小节、某一段正文里的一段文字。
///
/// [start] / [end] 是段内字符区间，坐标是段落原文本身（不含正文首行缩进），
/// 所以将来调整排版也不会让已有划线跑偏。
class BookHighlight {
  const BookHighlight({
    required this.chapterHref,
    required this.sectionKey,
    required this.blockIndex,
    required this.start,
    required this.end,
    required this.style,
    required this.text,
    required this.createdAt,
  });

  /// 章（书档内路径）。
  final String chapterHref;

  /// 小节标识（`BookSection.key`）。
  final String sectionKey;

  /// 这一段在小节 `blocks` 里的下标。
  final int blockIndex;

  final int start;
  final int end;
  final HighlightStyle style;

  /// 划线时选中的文字：列表展示用；正文若变动，以区间为准。
  final String text;

  final DateTime createdAt;

  int get length => end - start;

  /// 是否与另一条划线落在同一段的同一区间上（样式可以不同）。
  bool sameRange(BookHighlight other) =>
      chapterHref == other.chapterHref &&
      sectionKey == other.sectionKey &&
      blockIndex == other.blockIndex &&
      start == other.start &&
      end == other.end;

  Map<String, Object?> toJson() => {
        'chapter': chapterHref,
        'section': sectionKey,
        'block': blockIndex,
        'start': start,
        'end': end,
        'style': style.name,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  /// 解析一条划线；字段不全或区间不合法时返回 null，坏数据直接丢掉。
  static BookHighlight? fromJson(Object? value) {
    if (value is! Map) return null;
    final chapter = value['chapter'];
    final section = value['section'];
    final block = value['block'];
    final start = value['start'];
    final end = value['end'];
    if (chapter is! String || chapter.isEmpty) return null;
    if (section is! String) return null;
    if (block is! num || start is! num || end is! num) return null;
    if (start.toInt() < 0 || start.toInt() >= end.toInt()) return null;

    final createdAt = value['createdAt'];
    return BookHighlight(
      chapterHref: chapter,
      sectionKey: section,
      blockIndex: block.toInt(),
      start: start.toInt(),
      end: end.toInt(),
      style: HighlightStyle.fromName(value['style']),
      text: value['text'] is String ? value['text'] as String : '',
      createdAt: createdAt is String
          ? DateTime.tryParse(createdAt) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// 存档：整份划线写成一段 JSON 文本。
  static String encodeList(List<BookHighlight> highlights) =>
      jsonEncode([for (final highlight in highlights) highlight.toJson()]);

  /// 还原存档；内容坏掉时当作没有划线，不影响读书。
  static List<BookHighlight> decodeList(String? source) {
    if (source == null || source.isEmpty) return const [];
    final Object? raw;
    try {
      raw = jsonDecode(source);
    } on FormatException {
      return const [];
    }
    if (raw is! List) return const [];
    return [
      for (final item in raw) ?BookHighlight.fromJson(item),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is BookHighlight &&
      other.chapterHref == chapterHref &&
      other.sectionKey == sectionKey &&
      other.blockIndex == blockIndex &&
      other.start == start &&
      other.end == end &&
      other.style == style &&
      other.text == text;

  @override
  int get hashCode =>
      Object.hash(chapterHref, sectionKey, blockIndex, start, end, style, text);
}

/// 正文按划线切出来的一段：不带样式时 [style] 为 null。
class HighlightedTextPiece {
  const HighlightedTextPiece(this.text, this.style);

  final String text;
  final HighlightStyle? style;
}

/// 取出某一段正文上的全部划线。
List<BookHighlight> highlightsOfBlock(
  List<BookHighlight> all, {
  required String chapterHref,
  required String sectionKey,
  required int blockIndex,
}) =>
    [
      for (final highlight in all)
        if (highlight.chapterHref == chapterHref &&
            highlight.sectionKey == sectionKey &&
            highlight.blockIndex == blockIndex)
          highlight,
    ];

/// 把段落原文按划线切成带样式的片段。
///
/// 区间重叠时取更短（更具体）的那条：整句画了马克笔，句中的词再画波浪线，
/// 该词显示波浪线、句子其余部分仍是马克笔；同样短则取靠后加入的那条。
List<HighlightedTextPiece> splitHighlightedText(
  String text,
  List<BookHighlight> highlights,
) {
  final usable = [
    for (final highlight in highlights)
      if (highlight.start < text.length && highlight.end > highlight.start)
        highlight,
  ]..sort((a, b) => a.start.compareTo(b.start));

  if (usable.isEmpty) return [HighlightedTextPiece(text, null)];

  final bounds = <int>{0, text.length};
  for (final highlight in usable) {
    bounds.add(highlight.start.clamp(0, text.length));
    bounds.add(highlight.end.clamp(0, text.length));
  }
  final points = bounds.toList()..sort();

  final pieces = <HighlightedTextPiece>[];
  for (var i = 0; i < points.length - 1; i++) {
    final start = points[i];
    final end = points[i + 1];
    if (start >= end) continue;
    pieces.add(
      HighlightedTextPiece(text.substring(start, end), _styleAt(usable, start, end)),
    );
  }
  return pieces;
}

/// 覆盖 `[start, end)` 的划线里挑一条：区间更短的优先。
HighlightStyle? _styleAt(List<BookHighlight> highlights, int start, int end) {
  HighlightStyle? result;
  var shortest = -1;
  for (final highlight in highlights) {
    if (highlight.start > start || highlight.end < end) continue;
    if (shortest < 0 || highlight.length <= shortest) {
      shortest = highlight.length;
      result = highlight.style;
    }
  }
  return result;
}
