import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/book/book_highlight.dart';
import '../../providers/book_provider.dart';

/// 划线样式对应的图标（工具条与划线列表共用）。
IconData highlightStyleIcon(HighlightStyle style) => switch (style) {
      HighlightStyle.marker => Icons.brush_outlined,
      HighlightStyle.wavy => Icons.waves,
      HighlightStyle.line => Icons.format_underline,
    };

/// 正文段落：可以选中，选中后浮出工具条（复制 / 马克笔 / 波浪线 / 直线）。
///
/// 一段正文一块 [SelectableText]，选中区间就是这段文字的字符区间，划线因此能精确记下来。
/// 各段选中互不影响：点到别的段，上一段的选中由 SelectableText 自己清掉。
class HighlightableText extends ConsumerWidget {
  const HighlightableText({
    super.key,
    required this.chapterHref,
    required this.sectionKey,
    required this.blockIndex,
    required this.text,
    this.indent = '',
    this.style,
  });

  /// 所在章（书档内路径）。
  final String chapterHref;

  /// 所在小节。
  final String sectionKey;

  /// 这一段在小节 blocks 里的下标。
  final int blockIndex;

  /// 段落原文：划线区间以它为坐标。
  final String text;

  /// 排版时加在正文前、不计入划线的缩进（中文正文首行缩进两格）。
  final String indent;

  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final marker =
        (theme.extension<BookHighlightTheme>() ?? BookHighlightTheme.fallback)
            .marker;
    final highlights = highlightsOfBlock(
      ref.watch(bookHighlightsProvider),
      chapterHref: chapterHref,
      sectionKey: sectionKey,
      blockIndex: blockIndex,
    );

    return Listener(
      // 鼠标（桌面）选中后框架不会自己弹工具条——它只对触摸与触控笔弹，
      // 所以这里在松开鼠标时补一次，桌面上才能选完就划线。
      onPointerUp: (event) => _showToolbarIfSelected(context, event),
      child: SelectableText.rich(
        TextSpan(
          children: [
            if (indent.isNotEmpty) TextSpan(text: indent),
            for (final piece in splitHighlightedText(text, highlights))
              TextSpan(
                text: piece.text,
                style: _decorationOf(piece.style, theme, marker),
              ),
          ],
        ),
        style: style,
        contextMenuBuilder: (context, editableTextState) =>
            _toolbar(ref, editableTextState),
      ),
    );
  }

  /// 松开鼠标/触控板时，若这一段的选中不是空的，就把工具条弹出来。
  void _showToolbarIfSelected(BuildContext context, PointerUpEvent event) {
    const desktopPointers = {
      PointerDeviceKind.mouse,
      PointerDeviceKind.trackpad,
    };
    if (!desktopPointers.contains(event.kind)) return;

    final editableTextState = _editableTextStateOf(context);
    if (editableTextState == null) return;
    if (editableTextState.textEditingValue.selection.isCollapsed) return;
    editableTextState.showToolbar();
  }

  /// 这一段里那个 [EditableText] 的状态。
  ///
  /// [SelectableText] 不把状态或 key 暴露出来，只能在自己的子树里找一遍；
  /// 只在松开鼠标时走一次，开销可以忽略。
  EditableTextState? _editableTextStateOf(BuildContext context) {
    EditableTextState? found;
    void visit(Element element) {
      if (found != null) return;
      final state = element is StatefulElement ? element.state : null;
      if (state is EditableTextState) {
        found = state;
        return;
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    return found;
  }

  /// 选中文字后弹出的工具条；没选中内容就不弹。
  Widget _toolbar(WidgetRef ref, EditableTextState editableTextState) {
    final selection = editableTextState.textEditingValue.selection;
    final start = (selection.start - indent.length).clamp(0, text.length);
    final end = (selection.end - indent.length).clamp(0, text.length);
    if (selection.isCollapsed || start >= end) return const SizedBox.shrink();

    return _SelectionToolbar(
      anchors: editableTextState.contextMenuAnchors,
      onSelected: (action) {
        editableTextState.hideToolbar();
        _run(ref, action, start, end);
      },
    );
  }

  /// 复制选中的文字，或给它画一条划线。
  void _run(WidgetRef ref, _ToolbarAction action, int start, int end) {
    final selected = text.substring(start, end);
    final style = action.style;
    if (style == null) {
      Clipboard.setData(ClipboardData(text: selected));
      return;
    }

    ref.read(bookHighlightsProvider.notifier).add(
          BookHighlight(
            chapterHref: chapterHref,
            sectionKey: sectionKey,
            blockIndex: blockIndex,
            start: start,
            end: end,
            style: style,
            text: selected,
            createdAt: DateTime.now(),
          ),
        );
  }
}

/// 划线在正文里的画法：马克笔压底色，波浪线与直线用主色。
TextStyle? _decorationOf(
  HighlightStyle? style,
  ThemeData theme,
  Color marker,
) =>
    switch (style) {
      null => null,
      HighlightStyle.marker => TextStyle(backgroundColor: marker),
      HighlightStyle.wavy => TextStyle(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.wavy,
          decorationColor: theme.colorScheme.primary,
          decorationThickness: 1.4,
        ),
      HighlightStyle.line => TextStyle(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.solid,
          decorationColor: theme.colorScheme.primary,
          decorationThickness: 1.6,
        ),
    };

/// 工具条上的动作：复制，以及三种划线样式。
class _ToolbarAction {
  const _ToolbarAction(this.label, this.icon, this.style);

  final String label;
  final IconData icon;

  /// 划线样式；复制没有样式。
  final HighlightStyle? style;

  static final List<_ToolbarAction> all = [
    const _ToolbarAction('复制', Icons.content_copy, null),
    for (final style in HighlightStyle.values)
      _ToolbarAction(style.label, highlightStyleIcon(style), style),
  ];
}

/// 浮在选区上方的工具条，底部弹层之外的第二种「选中即操作」入口。
class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({required this.anchors, required this.onSelected});

  final TextSelectionToolbarAnchors anchors;
  final ValueChanged<_ToolbarAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return TextSelectionToolbar(
      anchorAbove: anchors.primaryAnchor,
      anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
      toolbarBuilder: _surface,
      children: [
        for (final action in _ToolbarAction.all)
          _ToolbarButton(action: action, onPressed: () => onSelected(action)),
      ],
    );
  }

  /// 反色胶囊，跟 SnackBar / Tooltip 一个调子。
  static Widget _surface(BuildContext context, Widget child) => Material(
        color: Theme.of(context).colorScheme.inverseSurface,
        elevation: 3,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: child,
        ),
      );
}

/// 工具条上的一格：图标在上、名字在下。高度受选择工具条限制（44），排得紧凑些。
class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.action, required this.onPressed});

  final _ToolbarAction action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onInverseSurface;

    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 18, color: color),
            Text(
              action.label,
              maxLines: 1,
              style: TextStyle(fontSize: 10.5, height: 1.3, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
