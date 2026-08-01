import 'package:flutter/material.dart';

import 'kbar_theme_data.dart';

/// Applies a [KBarThemeData] to a subtree.
///
/// Only needed to override the palette's appearance in one part of the app;
/// for an app-wide look, register the extension on your [ThemeData] instead:
///
/// ```dart
/// ThemeData(extensions: [KBarThemeData(backgroundColor: Colors.black)])
/// ```
class KBarTheme extends InheritedWidget {
  /// Applies [data] to [child].
  const KBarTheme({required this.data, required super.child, super.key});

  /// The overrides to apply.
  final KBarThemeData data;

  /// The palette theme in effect at [context].
  ///
  /// Layers, from lowest precedence to highest:
  ///
  ///  1. [KBarThemeData.fromTheme] — derived from the ambient [ThemeData], so
  ///     the palette matches the app with no configuration.
  ///  2. `Theme.of(context).extension<KBarThemeData>()` — app-wide overrides.
  ///  3. The nearest [KBarTheme] — subtree overrides.
  ///
  /// Each layer merges over the one below, so partial overrides work: setting
  /// only `backgroundColor` leaves everything else derived.
  static KBarThemeData of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return KBarThemeData.fromTheme(theme)
        .merge(theme.extension<KBarThemeData>())
        .merge(context.dependOnInheritedWidgetOfExactType<KBarTheme>()?.data);
  }

  @override
  bool updateShouldNotify(KBarTheme oldWidget) => data != oldWidget.data;
}
