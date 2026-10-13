import 'package:flutter/material.dart';

/// 应用的两套皮肤。
///
/// - 浅色「纸感」：牛皮纸底 + 白卡片 + 铁锈红点缀；
/// - 深色「夜铁」：暖黑底 + 哑光铁灰层次 + 亮铁锈橙点缀。
///
/// 两套皮肤共用同一套设计语言（同源主色、同样的圆角与描边规则），
/// 只在明暗与层次上区分，因此切换皮肤时布局完全不变。
/// 颜色全部集中在 [_Tokens] 里，调整皮肤只要改这一个类。
///
/// 页面层不需要判断明暗：一律使用 `ColorScheme` 语义色
/// （`primary` / `onSurfaceVariant` / `outline` / `surfaceContainerHighest` …）。
class AppTheme {
  AppTheme._();

  /// 品牌主色：铁锈红。两套皮肤的主色都由它派生。
  static const seed = Color(0xFFA8431A);

  static ThemeData light() => _build(_light);

  static ThemeData dark() => _build(_dark);

  static const _radiusCard = 18.0;
  static const _radiusControl = 14.0;

  // ── 浅色皮肤「纸感」 ───────────────────────────────────────────
  static const _light = _Tokens(
    brightness: Brightness.light,
    canvas: Color(0xFFF5F0EA),
    surface: Color(0xFFFFFFFF),
    surfaceLowest: Color(0xFFFFFFFF),
    surfaceLow: Color(0xFFFBF7F2),
    surfaceContainer: Color(0xFFF7F1EA),
    surfaceHigh: Color(0xFFF2EAE1),
    surfaceHighest: Color(0xFFEDE3D9),
    primary: Color(0xFFA8431A),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFDBC7),
    onPrimaryContainer: Color(0xFF3B1200),
    secondary: Color(0xFF6E5A4D),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFF3E3D6),
    onSecondaryContainer: Color(0xFF2A1A10),
    tertiary: Color(0xFF6B4A3A),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF6DED2),
    onTertiaryContainer: Color(0xFF2C150B),
    onSurface: Color(0xFF241A14),
    onSurfaceVariant: Color(0xFF6D5C50),
    outline: Color(0xFFB0A093),
    outlineVariant: Color(0xFFE7DBD0),
    inverseSurface: Color(0xFF332B26),
    onInverseSurface: Color(0xFFF7F1EA),
    inversePrimary: Color(0xFFFFB48F),
    scrollThumb: Color(0xFFC9B9AC),
  );

  // ── 深色皮肤「夜铁」 ───────────────────────────────────────────
  static const _dark = _Tokens(
    brightness: Brightness.dark,
    canvas: Color(0xFF121011),
    surface: Color(0xFF1B1817),
    surfaceLowest: Color(0xFF0C0A0A),
    surfaceLow: Color(0xFF171414),
    surfaceContainer: Color(0xFF1B1817),
    surfaceHigh: Color(0xFF221E1D),
    surfaceHighest: Color(0xFF2A2524),
    primary: Color(0xFFFF9E6B),
    onPrimary: Color(0xFF4A1600),
    primaryContainer: Color(0xFF8A3312),
    onPrimaryContainer: Color(0xFFFFDBCC),
    secondary: Color(0xFFD8C2B4),
    onSecondary: Color(0xFF3A2A20),
    secondaryContainer: Color(0xFF503F34),
    onSecondaryContainer: Color(0xFFF3DFD2),
    tertiary: Color(0xFFE3B7A0),
    onTertiary: Color(0xFF43291C),
    tertiaryContainer: Color(0xFF5C3B2A),
    onTertiaryContainer: Color(0xFFFFE0D0),
    onSurface: Color(0xFFEDE6E1),
    onSurfaceVariant: Color(0xFFB4A69C),
    outline: Color(0xFF8C7E75),
    outlineVariant: Color(0xFF322C29),
    inverseSurface: Color(0xFFEDE6E1),
    onInverseSurface: Color(0xFF322B27),
    inversePrimary: Color(0xFFA8431A),
    scrollThumb: Color(0xFF4A423E),
  );

  static ThemeData _build(_Tokens t) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: t.brightness,
    ).copyWith(
      primary: t.primary,
      onPrimary: t.onPrimary,
      primaryContainer: t.primaryContainer,
      onPrimaryContainer: t.onPrimaryContainer,
      secondary: t.secondary,
      onSecondary: t.onSecondary,
      secondaryContainer: t.secondaryContainer,
      onSecondaryContainer: t.onSecondaryContainer,
      tertiary: t.tertiary,
      onTertiary: t.onTertiary,
      tertiaryContainer: t.tertiaryContainer,
      onTertiaryContainer: t.onTertiaryContainer,
      surface: t.surface,
      onSurface: t.onSurface,
      onSurfaceVariant: t.onSurfaceVariant,
      surfaceContainerLowest: t.surfaceLowest,
      surfaceContainerLow: t.surfaceLow,
      surfaceContainer: t.surfaceContainer,
      surfaceContainerHigh: t.surfaceHigh,
      surfaceContainerHighest: t.surfaceHighest,
      outline: t.outline,
      outlineVariant: t.outlineVariant,
      inverseSurface: t.inverseSurface,
      onInverseSurface: t.onInverseSurface,
      inversePrimary: t.inversePrimary,
      // 全靠层次与描边表达高度，避免系统自动叠加的色调。
      surfaceTint: Colors.transparent,
    );

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_radiusCard),
      side: BorderSide(color: t.outlineVariant),
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_radiusControl),
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: t.canvas,
      canvasColor: t.canvas,
      appBarTheme: AppBarThemeData(
        backgroundColor: t.canvas,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: cardShape,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.primaryContainer,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? t.primary
                : t.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: t.primary,
                )
              : TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: t.onSurfaceVariant,
                ),
        ),
      ),
      // 选中项一律用主色实心填充，避免默认的次要色容器跑出无关色相。
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          shape: WidgetStatePropertyAll(controlShape),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.selected)
                  ? t.primary
                  : t.outlineVariant,
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? t.primary
                : t.canvas,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? t.onPrimary
                : t.onSurfaceVariant,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? t.onPrimary
                : t.onSurfaceVariant,
          ),
          overlayColor: WidgetStateProperty.resolveWith(
            (states) {
              final base = states.contains(WidgetState.selected)
                  ? t.onPrimary
                  : t.primary;
              if (states.contains(WidgetState.pressed)) {
                return base.withValues(alpha: 0.14);
              }
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)) {
                return base.withValues(alpha: 0.08);
              }
              return null;
            },
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surfaceHighest,
        selectedColor: t.primary,
        secondarySelectedColor: t.primary,
        checkmarkColor: t.onPrimary,
        side: BorderSide.none,
        elevation: 0,
        pressElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: t.onSurface,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: t.onPrimary,
        ),
        iconTheme: IconThemeData(size: 16, color: t.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: controlShape,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: controlShape,
          foregroundColor: t.onSurface,
          side: BorderSide(color: t.outlineVariant),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: t.surfaceHigh,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusControl),
          borderSide: BorderSide(color: t.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusControl),
          borderSide: BorderSide(color: t.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusControl),
          borderSide: BorderSide(color: t.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusControl),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusControl),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.primary,
        selectionColor: t.primary.withValues(alpha: 0.22),
        selectionHandleColor: t.primary,
      ),
      dividerTheme: DividerThemeData(
        color: t.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: t.outlineVariant),
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: t.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14.5,
          height: 1.5,
          color: t.onSurfaceVariant,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        headerBackgroundColor: t.primaryContainer,
        headerForegroundColor: t.onPrimaryContainer,
        todayForegroundColor: WidgetStatePropertyAll(t.primary),
        todayBorder: BorderSide(color: t.primary),
        dayOverlayColor: WidgetStatePropertyAll(
          t.primary.withValues(alpha: 0.08),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        modalBackgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.inverseSurface,
        contentTextStyle: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: t.onInverseSurface,
        ),
        actionTextColor: t.inversePrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusControl),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(fontSize: 12, color: t.onInverseSurface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.primary,
        linearTrackColor: t.surfaceHighest,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(t.scrollThumb),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(4),
        interactive: true,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

/// 一套皮肤的全部颜色。字段名对应用途，不依赖 Material 的角色命名。
class _Tokens {
  const _Tokens({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceLowest,
    required this.surfaceLow,
    required this.surfaceContainer,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.inversePrimary,
    required this.scrollThumb,
  });

  /// 页面底色（Scaffold / AppBar）。
  final Brightness brightness;
  final Color canvas;

  /// 卡片、导航栏、弹层底色。
  final Color surface;
  final Color surfaceLowest;
  final Color surfaceLow;
  final Color surfaceContainer;

  /// 输入框、未选中标签等“凹下去”的一层。
  final Color surfaceHigh;

  /// 未选中的 chip 底色。
  final Color surfaceHighest;

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;

  /// 正文 / 次要文字。
  final Color onSurface;
  final Color onSurfaceVariant;

  /// 常规描边色 / 卡片与分隔线描边色。
  final Color outline;
  final Color outlineVariant;

  /// 提示条（SnackBar、Tooltip）底色与文字色。
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color inversePrimary;

  /// 滚动条滑块。
  final Color scrollThumb;
}
