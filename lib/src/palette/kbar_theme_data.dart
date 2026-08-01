import 'package:flutter/material.dart';

/// Visual configuration for `KBarPalette` and the default tiles.
///
/// A [ThemeExtension], so it lerps across theme transitions and light/dark
/// switches for free:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(extensions: const [KBarThemeData.light]),
///   darkTheme: ThemeData(extensions: const [KBarThemeData.dark]),
/// )
/// ```
///
/// Every field is nullable and falls back to something derived from the
/// ambient [ColorScheme] and [TextTheme], so the palette looks at home in your
/// app with no configuration at all. See [KBarThemeData.fromTheme].
@immutable
class KBarThemeData extends ThemeExtension<KBarThemeData> {
  /// Creates a theme. Any field left null is derived from the ambient theme.
  const KBarThemeData({
    this.backgroundColor,
    this.barrierColor,
    this.dividerColor,
    this.shadows,
    this.borderRadius,
    this.border,
    this.maxWidth,
    this.maxResultsHeight,
    this.topFraction,
    this.searchPadding,
    this.searchTextStyle,
    this.placeholderStyle,
    this.searchIcon,
    this.sectionHeaderStyle,
    this.sectionHeaderPadding,
    this.itemPadding,
    this.itemSpacing,
    this.itemBorderRadius,
    this.itemTextStyle,
    this.itemSubtitleStyle,
    this.activeItemColor,
    this.activeItemTextStyle,
    this.hoverItemColor,
    this.iconColor,
    this.iconSize,
    this.highlightStyle,
    this.breadcrumbStyle,
    this.shortcutTextStyle,
    this.shortcutDecoration,
    this.shortcutPadding,
    this.emptyStateStyle,
    this.emptyStatePadding,
  });

  /// Derives a complete theme from the ambient [ThemeData].
  ///
  /// This is the zero-configuration default: colours come from the app's
  /// [ColorScheme] and type from its [TextTheme], so the palette matches the
  /// surrounding app without being told anything.
  factory KBarThemeData.fromTheme(ThemeData theme) {
    final ColorScheme colors = theme.colorScheme;
    final TextTheme text = theme.textTheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return KBarThemeData(
      backgroundColor: colors.surface,
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.6 : 0.35),
      dividerColor: colors.outlineVariant.withValues(alpha: 0.5),
      shadows: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
          blurRadius: 40,
          spreadRadius: -8,
          offset: const Offset(0, 16),
        ),
      ],
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      maxWidth: 620,
      maxResultsHeight: 400,
      topFraction: 0.14,
      searchPadding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      searchTextStyle: text.titleMedium?.copyWith(color: colors.onSurface),
      placeholderStyle: text.titleMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
      searchIcon: Icon(Icons.search, size: 20, color: colors.onSurfaceVariant),
      sectionHeaderStyle: text.labelSmall?.copyWith(
        color: colors.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
      sectionHeaderPadding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      itemPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      itemSpacing: 2,
      itemBorderRadius: const BorderRadius.all(Radius.circular(9)),
      itemTextStyle: text.bodyMedium?.copyWith(color: colors.onSurface),
      itemSubtitleStyle: text.bodySmall?.copyWith(
        color: colors.onSurfaceVariant,
      ),
      activeItemColor: colors.primary.withValues(alpha: isDark ? 0.22 : 0.11),
      activeItemTextStyle: text.bodyMedium?.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w600,
      ),
      hoverItemColor: colors.onSurface.withValues(alpha: 0.04),
      iconColor: colors.onSurfaceVariant,
      iconSize: 18,
      highlightStyle: TextStyle(
        color: colors.primary,
        fontWeight: FontWeight.w700,
      ),
      breadcrumbStyle: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
      shortcutTextStyle: text.labelSmall?.copyWith(
        color: colors.onSurfaceVariant,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
      shortcutDecoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: isDark ? 0.09 : 0.05),
        borderRadius: const BorderRadius.all(Radius.circular(5)),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: isDark ? 0.14 : 0.08),
        ),
      ),
      shortcutPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      emptyStateStyle: text.bodyMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
      emptyStatePadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 28,
      ),
    );
  }

  /// Panel background.
  final Color? backgroundColor;

  /// Scrim painted over the app behind the palette.
  final Color? barrierColor;

  /// Rule between the search field and the results.
  final Color? dividerColor;

  /// Shadows cast by the panel.
  final List<BoxShadow>? shadows;

  /// Panel corner radius.
  final BorderRadiusGeometry? borderRadius;

  /// Panel outline.
  final BoxBorder? border;

  /// Widest the panel may become.
  final double? maxWidth;

  /// Tallest the result list may become before it scrolls.
  final double? maxResultsHeight;

  /// Distance from the top of the viewport, as a fraction of its height.
  final double? topFraction;

  /// Insets around the search row.
  final EdgeInsetsGeometry? searchPadding;

  /// Style of the entered query.
  final TextStyle? searchTextStyle;

  /// Style of the placeholder.
  final TextStyle? placeholderStyle;

  /// Leading widget in the search row.
  final Widget? searchIcon;

  /// Style of section headings.
  final TextStyle? sectionHeaderStyle;

  /// Insets around section headings.
  final EdgeInsetsGeometry? sectionHeaderPadding;

  /// Insets inside each result row.
  final EdgeInsetsGeometry? itemPadding;

  /// Vertical gap between result rows.
  final double? itemSpacing;

  /// Corner radius of the highlight behind a result row.
  final BorderRadiusGeometry? itemBorderRadius;

  /// Style of a result's name.
  final TextStyle? itemTextStyle;

  /// Style of a result's subtitle.
  final TextStyle? itemSubtitleStyle;

  /// Background of the highlighted row.
  final Color? activeItemColor;

  /// Style of the highlighted row's name.
  final TextStyle? activeItemTextStyle;

  /// Background of a hovered row.
  final Color? hoverItemColor;

  /// Colour applied to a result's icon.
  final Color? iconColor;

  /// Size of a result's icon.
  final double? iconSize;

  /// Style applied to the characters that matched the query.
  final TextStyle? highlightStyle;

  /// Style of the ancestor trail shown on results from nested actions.
  final TextStyle? breadcrumbStyle;

  /// Style of shortcut key labels.
  final TextStyle? shortcutTextStyle;

  /// Decoration behind each shortcut key label.
  final Decoration? shortcutDecoration;

  /// Insets inside each shortcut key label.
  final EdgeInsetsGeometry? shortcutPadding;

  /// Style of the empty-state message.
  final TextStyle? emptyStateStyle;

  /// Insets around the empty-state message.
  final EdgeInsetsGeometry? emptyStatePadding;

  /// Returns a copy with every non-null field of [other] applied on top.
  KBarThemeData merge(KBarThemeData? other) {
    if (other == null) return this;
    return copyWith(
      backgroundColor: other.backgroundColor,
      barrierColor: other.barrierColor,
      dividerColor: other.dividerColor,
      shadows: other.shadows,
      borderRadius: other.borderRadius,
      border: other.border,
      maxWidth: other.maxWidth,
      maxResultsHeight: other.maxResultsHeight,
      topFraction: other.topFraction,
      searchPadding: other.searchPadding,
      searchTextStyle: other.searchTextStyle,
      placeholderStyle: other.placeholderStyle,
      searchIcon: other.searchIcon,
      sectionHeaderStyle: other.sectionHeaderStyle,
      sectionHeaderPadding: other.sectionHeaderPadding,
      itemPadding: other.itemPadding,
      itemSpacing: other.itemSpacing,
      itemBorderRadius: other.itemBorderRadius,
      itemTextStyle: other.itemTextStyle,
      itemSubtitleStyle: other.itemSubtitleStyle,
      activeItemColor: other.activeItemColor,
      activeItemTextStyle: other.activeItemTextStyle,
      hoverItemColor: other.hoverItemColor,
      iconColor: other.iconColor,
      iconSize: other.iconSize,
      highlightStyle: other.highlightStyle,
      breadcrumbStyle: other.breadcrumbStyle,
      shortcutTextStyle: other.shortcutTextStyle,
      shortcutDecoration: other.shortcutDecoration,
      shortcutPadding: other.shortcutPadding,
      emptyStateStyle: other.emptyStateStyle,
      emptyStatePadding: other.emptyStatePadding,
    );
  }

  @override
  KBarThemeData copyWith({
    Color? backgroundColor,
    Color? barrierColor,
    Color? dividerColor,
    List<BoxShadow>? shadows,
    BorderRadiusGeometry? borderRadius,
    BoxBorder? border,
    double? maxWidth,
    double? maxResultsHeight,
    double? topFraction,
    EdgeInsetsGeometry? searchPadding,
    TextStyle? searchTextStyle,
    TextStyle? placeholderStyle,
    Widget? searchIcon,
    TextStyle? sectionHeaderStyle,
    EdgeInsetsGeometry? sectionHeaderPadding,
    EdgeInsetsGeometry? itemPadding,
    double? itemSpacing,
    BorderRadiusGeometry? itemBorderRadius,
    TextStyle? itemTextStyle,
    TextStyle? itemSubtitleStyle,
    Color? activeItemColor,
    TextStyle? activeItemTextStyle,
    Color? hoverItemColor,
    Color? iconColor,
    double? iconSize,
    TextStyle? highlightStyle,
    TextStyle? breadcrumbStyle,
    TextStyle? shortcutTextStyle,
    Decoration? shortcutDecoration,
    EdgeInsetsGeometry? shortcutPadding,
    TextStyle? emptyStateStyle,
    EdgeInsetsGeometry? emptyStatePadding,
  }) {
    return KBarThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      barrierColor: barrierColor ?? this.barrierColor,
      dividerColor: dividerColor ?? this.dividerColor,
      shadows: shadows ?? this.shadows,
      borderRadius: borderRadius ?? this.borderRadius,
      border: border ?? this.border,
      maxWidth: maxWidth ?? this.maxWidth,
      maxResultsHeight: maxResultsHeight ?? this.maxResultsHeight,
      topFraction: topFraction ?? this.topFraction,
      searchPadding: searchPadding ?? this.searchPadding,
      searchTextStyle: searchTextStyle ?? this.searchTextStyle,
      placeholderStyle: placeholderStyle ?? this.placeholderStyle,
      searchIcon: searchIcon ?? this.searchIcon,
      sectionHeaderStyle: sectionHeaderStyle ?? this.sectionHeaderStyle,
      sectionHeaderPadding: sectionHeaderPadding ?? this.sectionHeaderPadding,
      itemPadding: itemPadding ?? this.itemPadding,
      itemSpacing: itemSpacing ?? this.itemSpacing,
      itemBorderRadius: itemBorderRadius ?? this.itemBorderRadius,
      itemTextStyle: itemTextStyle ?? this.itemTextStyle,
      itemSubtitleStyle: itemSubtitleStyle ?? this.itemSubtitleStyle,
      activeItemColor: activeItemColor ?? this.activeItemColor,
      activeItemTextStyle: activeItemTextStyle ?? this.activeItemTextStyle,
      hoverItemColor: hoverItemColor ?? this.hoverItemColor,
      iconColor: iconColor ?? this.iconColor,
      iconSize: iconSize ?? this.iconSize,
      highlightStyle: highlightStyle ?? this.highlightStyle,
      breadcrumbStyle: breadcrumbStyle ?? this.breadcrumbStyle,
      shortcutTextStyle: shortcutTextStyle ?? this.shortcutTextStyle,
      shortcutDecoration: shortcutDecoration ?? this.shortcutDecoration,
      shortcutPadding: shortcutPadding ?? this.shortcutPadding,
      emptyStateStyle: emptyStateStyle ?? this.emptyStateStyle,
      emptyStatePadding: emptyStatePadding ?? this.emptyStatePadding,
    );
  }

  @override
  KBarThemeData lerp(ThemeExtension<KBarThemeData>? other, double t) {
    if (other is! KBarThemeData) return this;
    return KBarThemeData(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      barrierColor: Color.lerp(barrierColor, other.barrierColor, t),
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t),
      shadows: BoxShadow.lerpList(shadows, other.shadows, t),
      borderRadius: BorderRadiusGeometry.lerp(
        borderRadius,
        other.borderRadius,
        t,
      ),
      border: BoxBorder.lerp(border, other.border, t),
      maxWidth: _lerpDouble(maxWidth, other.maxWidth, t),
      maxResultsHeight: _lerpDouble(
        maxResultsHeight,
        other.maxResultsHeight,
        t,
      ),
      topFraction: _lerpDouble(topFraction, other.topFraction, t),
      searchPadding: EdgeInsetsGeometry.lerp(
        searchPadding,
        other.searchPadding,
        t,
      ),
      searchTextStyle: TextStyle.lerp(
        searchTextStyle,
        other.searchTextStyle,
        t,
      ),
      placeholderStyle: TextStyle.lerp(
        placeholderStyle,
        other.placeholderStyle,
        t,
      ),
      searchIcon: t < 0.5 ? searchIcon : other.searchIcon,
      sectionHeaderStyle: TextStyle.lerp(
        sectionHeaderStyle,
        other.sectionHeaderStyle,
        t,
      ),
      sectionHeaderPadding: EdgeInsetsGeometry.lerp(
        sectionHeaderPadding,
        other.sectionHeaderPadding,
        t,
      ),
      itemPadding: EdgeInsetsGeometry.lerp(itemPadding, other.itemPadding, t),
      itemSpacing: _lerpDouble(itemSpacing, other.itemSpacing, t),
      itemBorderRadius: BorderRadiusGeometry.lerp(
        itemBorderRadius,
        other.itemBorderRadius,
        t,
      ),
      itemTextStyle: TextStyle.lerp(itemTextStyle, other.itemTextStyle, t),
      itemSubtitleStyle: TextStyle.lerp(
        itemSubtitleStyle,
        other.itemSubtitleStyle,
        t,
      ),
      activeItemColor: Color.lerp(activeItemColor, other.activeItemColor, t),
      activeItemTextStyle: TextStyle.lerp(
        activeItemTextStyle,
        other.activeItemTextStyle,
        t,
      ),
      hoverItemColor: Color.lerp(hoverItemColor, other.hoverItemColor, t),
      iconColor: Color.lerp(iconColor, other.iconColor, t),
      iconSize: _lerpDouble(iconSize, other.iconSize, t),
      highlightStyle: TextStyle.lerp(highlightStyle, other.highlightStyle, t),
      breadcrumbStyle: TextStyle.lerp(
        breadcrumbStyle,
        other.breadcrumbStyle,
        t,
      ),
      shortcutTextStyle: TextStyle.lerp(
        shortcutTextStyle,
        other.shortcutTextStyle,
        t,
      ),
      shortcutDecoration: Decoration.lerp(
        shortcutDecoration,
        other.shortcutDecoration,
        t,
      ),
      shortcutPadding: EdgeInsetsGeometry.lerp(
        shortcutPadding,
        other.shortcutPadding,
        t,
      ),
      emptyStateStyle: TextStyle.lerp(
        emptyStateStyle,
        other.emptyStateStyle,
        t,
      ),
      emptyStatePadding: EdgeInsetsGeometry.lerp(
        emptyStatePadding,
        other.emptyStatePadding,
        t,
      ),
    );
  }

  static double? _lerpDouble(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    return a + (b - a) * t;
  }
}
