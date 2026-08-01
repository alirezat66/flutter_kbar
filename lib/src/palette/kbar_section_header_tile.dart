import 'package:flutter/material.dart';

import 'kbar_theme.dart';
import 'kbar_theme_data.dart';

/// The default section heading row.
class KBarSectionHeaderTile extends StatelessWidget {
  /// Renders [title] as a heading.
  const KBarSectionHeaderTile(this.title, {this.style, super.key});

  /// The heading text.
  final String title;

  /// Overrides for the ambient palette theme.
  final KBarThemeData? style;

  @override
  Widget build(BuildContext context) {
    final KBarThemeData theme = KBarTheme.of(context).merge(style);
    return Semantics(
      header: true,
      child: Padding(
        padding: theme.sectionHeaderPadding ?? EdgeInsets.zero,
        child: Text(title.toUpperCase(), style: theme.sectionHeaderStyle),
      ),
    );
  }
}
