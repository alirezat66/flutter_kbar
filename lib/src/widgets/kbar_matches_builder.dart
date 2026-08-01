import 'package:flutter/widgets.dart';

import '../model/kbar_result_item.dart';
import '../store/kbar_controller.dart';

/// Builds from the current result list.
///
/// The Flutter translation of kbar's `useMatches()`. Where kbar re-runs its
/// whole match pipeline inside every call, this listens to a single shared
/// computation, so using it in several places costs nothing extra.
class KBarMatchesBuilder extends StatelessWidget {
  /// Builds from the current [KBarMatches].
  const KBarMatchesBuilder({required this.builder, this.child, super.key});

  /// Builds the subtree from the current results.
  final Widget Function(
    BuildContext context,
    KBarMatches matches,
    KBarController kbar,
    Widget? child,
  )
  builder;

  /// Passed through to [builder] unchanged.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final KBarController kbar = KBarController.of(context);
    return ValueListenableBuilder<KBarMatches>(
      valueListenable: kbar.matches,
      child: child,
      builder: (BuildContext context, KBarMatches matches, Widget? child) =>
          builder(context, matches, kbar, child),
    );
  }
}
