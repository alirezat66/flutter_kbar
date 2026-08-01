import 'package:flutter/material.dart';

import '../model/kbar_result_item.dart';
import '../model/kbar_state.dart';
import '../store/kbar_controller.dart';
import '../store/kbar_selector.dart';
import '../widgets/kbar_animator.dart';
import '../widgets/kbar_portal.dart';
import '../widgets/kbar_positioner.dart';
import '../widgets/kbar_results.dart';
import '../widgets/kbar_search_field.dart';
import 'kbar_result_tile.dart';
import 'kbar_section_header_tile.dart';
import 'kbar_theme.dart';
import 'kbar_theme_data.dart';

/// A complete, ready-to-use command palette.
///
/// Drop this anywhere below a `KBarProvider` — usually in `MaterialApp.builder`
/// so it survives route changes:
///
/// ```dart
/// KBarProvider(
///   actions: myActions,
///   child: MaterialApp(
///     builder: (context, child) => KBarPalette(child: child),
///     home: const HomePage(),
///   ),
/// )
/// ```
///
/// It is assembled entirely from the public primitives — `KBarPortal`,
/// `KBarPositioner`, `KBarAnimator`, `KBarSearchField` and `KBarResults` — so
/// there is no cliff between using it as-is, restyling it with
/// [KBarThemeData], overriding a single row with [itemBuilder], and composing
/// your own palette from scratch.
class KBarPalette extends StatelessWidget {
  /// Creates the bundled palette.
  const KBarPalette({
    this.child,
    this.style,
    this.placeholder = 'Type a command or search…',
    this.itemBuilder,
    this.headerBuilder,
    this.emptyBuilder,
    this.trailing,
    this.showBreadcrumbs = true,
    this.showShortcuts = true,
    this.highlightMatches = true,
    this.semanticLabel = 'Command palette',
    super.key,
  });

  /// The app, when this is used as `MaterialApp.builder`.
  ///
  /// The palette renders above it in an overlay; leave null when placing this
  /// widget somewhere that already has the app around it.
  final Widget? child;

  /// Overrides for the ambient palette theme.
  final KBarThemeData? style;

  /// Hint shown in the search field at the top level.
  final String placeholder;

  /// Replaces the default result row.
  final Widget Function(
    BuildContext context,
    KBarActionResult result,
    bool isActive,
  )?
  itemBuilder;

  /// Replaces the default section heading.
  final Widget Function(BuildContext context, KBarSectionHeader header)?
  headerBuilder;

  /// Replaces the default empty state.
  final Widget Function(BuildContext context, String query)? emptyBuilder;

  /// Extra widget at the trailing edge of the search row.
  final Widget? trailing;

  /// Whether result rows show the trail of ancestors they came from.
  final bool showBreadcrumbs;

  /// Whether result rows show their key bindings.
  final bool showShortcuts;

  /// Whether matched characters are emphasised in result names.
  final bool highlightMatches;

  /// Accessibility label for the panel.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KBarThemeData theme = KBarTheme.of(context).merge(style);

    final Widget palette = KBarPortal(
      barrierColor: theme.barrierColor ?? const Color(0x66000000),
      child: KBarPositioner(
        topFraction: theme.topFraction ?? 0.14,
        maxWidth: theme.maxWidth ?? 620,
        child: KBarAnimator(child: _panel(context, theme)),
      ),
    );

    if (child == null) return palette;
    return Stack(children: <Widget>[child!, palette]);
  }

  Widget _panel(BuildContext context, KBarThemeData theme) {
    return Semantics(
      label: semanticLabel,
      container: true,
      explicitChildNodes: true,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: theme.borderRadius,
            border: theme.border,
            boxShadow: theme.shadows,
          ),
          child: ClipRRect(
            borderRadius:
                theme.borderRadius?.resolve(Directionality.of(context)) ??
                BorderRadius.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _searchRow(theme),
                _divider(theme),
                // Not Flexible: KBarResults already caps its own height and
                // shrink-wraps, and adding flex here makes the enclosing
                // AnimatedSize re-dirty itself during its own layout.
                _results(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchRow(KBarThemeData theme) {
    return Padding(
      padding: theme.searchPadding ?? EdgeInsets.zero,
      child: Row(
        children: <Widget>[
          if (theme.searchIcon != null) ...<Widget>[
            theme.searchIcon!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: KBarSearchField(
              placeholder: placeholder,
              style: theme.searchTextStyle,
              placeholderStyle: theme.placeholderStyle,
              padding: EdgeInsets.zero,
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }

  Widget _divider(KBarThemeData theme) {
    // Hidden when there is nothing below it, so an empty palette reads as one
    // clean surface rather than a rule with a void under it.
    return KBarSelector<bool>(
      selector: (KBarState state) => true,
      builder:
          (
            BuildContext context,
            bool _,
            KBarController kbar,
            Widget? child,
          ) => ValueListenableBuilder<KBarMatches>(
            valueListenable: kbar.matches,
            builder: (BuildContext context, KBarMatches matches, Widget? _) =>
                matches.isEmpty
                ? const SizedBox.shrink()
                : Divider(height: 1, thickness: 1, color: theme.dividerColor),
          ),
    );
  }

  Widget _results(KBarThemeData theme) {
    return KBarSelector<String?>(
      selector: (KBarState state) => state.currentRootActionId,
      builder:
          (
            BuildContext context,
            String? rootId,
            KBarController kbar,
            Widget? child,
          ) => KBarResults(
            maxHeight: theme.maxResultsHeight ?? 400,
            padding: const EdgeInsets.symmetric(vertical: 6),
            emptyBuilder: (BuildContext context, String query) =>
                emptyBuilder?.call(context, query) ??
                Padding(
                  padding: theme.emptyStatePadding ?? EdgeInsets.zero,
                  child: Center(
                    child: Text(
                      query.isEmpty
                          ? 'No commands available'
                          : 'No results for "$query"',
                      style: theme.emptyStateStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            itemBuilder:
                (
                  BuildContext context,
                  KBarResultItem item,
                  int index,
                  bool isActive,
                ) => switch (item) {
                  KBarSectionHeader() =>
                    headerBuilder?.call(context, item) ??
                        KBarSectionHeaderTile(item.title, style: style),
                  KBarActionResult() =>
                    itemBuilder?.call(context, item, isActive) ??
                        KBarResultTile(
                          result: item,
                          isActive: isActive,
                          style: style,
                          showBreadcrumbs: showBreadcrumbs,
                          showShortcut: showShortcuts,
                          highlightMatches: highlightMatches,
                          currentRootActionId: rootId,
                        ),
                },
          ),
    );
  }
}
