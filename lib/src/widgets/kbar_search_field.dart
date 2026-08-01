import 'package:flutter/material.dart';

import '../model/kbar_state.dart';
import '../store/kbar_controller.dart';
import '../store/kbar_selector.dart';

/// The palette's search input.
///
/// Bound to `KBarController.searchController`, so — unlike kbar, whose input
/// keeps its text in local state — `KBarController.setSearch` actually updates
/// what the user sees.
///
/// While browsing a nested action the placeholder becomes that action's name,
/// matching kbar.
class KBarSearchField extends StatelessWidget {
  /// Creates the search field.
  const KBarSearchField({
    this.placeholder = 'Type a command or search…',
    this.style,
    this.placeholderStyle,
    this.decoration,
    this.autofocus = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    super.key,
  });

  /// Hint shown at the top level.
  final String placeholder;

  /// Style for the entered text.
  final TextStyle? style;

  /// Style for the placeholder.
  final TextStyle? placeholderStyle;

  /// Replaces the default borderless decoration entirely.
  final InputDecoration? decoration;

  /// Whether the field takes focus as soon as the palette opens.
  final bool autofocus;

  /// Insets around the field.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return KBarSelector<String?>(
      // Only the nested action's name matters here; typing must not rebuild
      // the field, which would fight the user's own input.
      selector: (KBarState state) => state.currentRootAction?.name,
      builder:
          (
            BuildContext context,
            String? rootName,
            KBarController kbar,
            Widget? child,
          ) {
            final TextStyle effectiveStyle =
                style ??
                Theme.of(context).textTheme.titleMedium ??
                const TextStyle(fontSize: 16);

            return Padding(
              padding: padding,
              child: TextField(
                controller: kbar.searchController,
                focusNode: kbar.searchFocusNode,
                autofocus: autofocus,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.go,
                style: effectiveStyle,
                cursorColor: Theme.of(context).colorScheme.primary,
                // Enter is handled globally so that a tap and a keypress take
                // the same code path.
                onSubmitted: (_) => kbar.performActiveAction(),
                decoration:
                    decoration ??
                    InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: rootName ?? placeholder,
                      hintStyle:
                          placeholderStyle ??
                          effectiveStyle.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                    ),
              ),
            );
          },
    );
  }
}
