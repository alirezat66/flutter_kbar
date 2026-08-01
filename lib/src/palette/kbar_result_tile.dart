import 'package:flutter/material.dart';

import '../match/kbar_matcher.dart';
import '../model/kbar_action_registry.dart';
import '../model/kbar_result_item.dart';
import 'kbar_highlighted_text.dart';
import 'kbar_shortcut_chips.dart';
import 'kbar_theme.dart';
import 'kbar_theme_data.dart';

/// The default result row.
///
/// Renders the action's icon, name with matched characters emphasised, an
/// optional subtitle, an ancestor trail, and its shortcut.
class KBarResultTile extends StatelessWidget {
  /// Renders [result].
  const KBarResultTile({
    required this.result,
    required this.isActive,
    this.style,
    this.showBreadcrumbs = true,
    this.showShortcut = true,
    this.highlightMatches = true,
    this.currentRootActionId,
    super.key,
  });

  /// The row to render.
  final KBarActionResult result;

  /// Whether this is the highlighted row.
  final bool isActive;

  /// Overrides for the ambient palette theme.
  final KBarThemeData? style;

  /// Whether to show the trail of ancestors above the action's name.
  final bool showBreadcrumbs;

  /// Whether to show the action's key binding.
  final bool showShortcut;

  /// Whether to emphasise the characters that matched the query.
  final bool highlightMatches;

  /// The nested action currently being browsed, if any.
  ///
  /// Used to trim the ancestor trail: inside "Set theme", the row for "Dark"
  /// should read "Dark", not "Set theme › Dark".
  final String? currentRootActionId;

  /// The ancestors worth showing, trimmed past [currentRootActionId].
  List<KBarActionNode> get _breadcrumbs {
    final List<KBarActionNode> ancestors = result.action.ancestors;
    if (currentRootActionId == null) return ancestors;
    final int index = ancestors.indexWhere(
      (KBarActionNode node) => node.id == currentRootActionId,
    );
    return index == -1 ? ancestors : ancestors.sublist(index + 1);
  }

  @override
  Widget build(BuildContext context) {
    final KBarThemeData theme = KBarTheme.of(context).merge(style);
    final KBarActionNode action = result.action;
    final List<KBarActionNode> breadcrumbs = showBreadcrumbs
        ? _breadcrumbs
        : const <KBarActionNode>[];

    final TextStyle? nameStyle = isActive
        ? theme.activeItemTextStyle
        : theme.itemTextStyle;

    return Semantics(
      button: true,
      selected: isActive,
      label: <String>[
        for (final KBarActionNode crumb in breadcrumbs) crumb.name,
        action.name,
        if (action.subtitle != null) action.subtitle!,
      ].join(', '),
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 6,
          vertical: (theme.itemSpacing ?? 0) / 2,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isActive ? theme.activeItemColor : null,
            borderRadius: theme.itemBorderRadius,
          ),
          child: Padding(
            padding: theme.itemPadding ?? EdgeInsets.zero,
            child: Row(
              children: <Widget>[
                if (action.icon != null) ...<Widget>[
                  IconTheme.merge(
                    data: IconThemeData(
                      color: theme.iconColor,
                      size: theme.iconSize,
                    ),
                    child: action.icon!,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          for (final KBarActionNode crumb in breadcrumbs) ...[
                            Flexible(
                              child: Text(
                                crumb.name,
                                style: theme.breadcrumbStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: Text('›', style: theme.breadcrumbStyle),
                            ),
                          ],
                          Flexible(
                            child: KBarHighlightedText(
                              action.name,
                              ranges: highlightMatches
                                  ? (result.match?.nameRanges ??
                                        const <KBarTextRange>[])
                                  : const <KBarTextRange>[],
                              style: nameStyle,
                              highlightStyle: theme.highlightStyle,
                            ),
                          ),
                        ],
                      ),
                      if (action.subtitle != null &&
                          action.subtitle!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          action.subtitle!,
                          style: theme.itemSubtitleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (showShortcut && action.shortcut.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 12),
                  KBarShortcutChips(action.shortcut, style: style),
                ] else if (action.isNavigational) ...<Widget>[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right,
                    size: theme.iconSize,
                    color: theme.iconColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
