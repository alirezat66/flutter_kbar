import 'package:flutter/widgets.dart';

import 'kbar_controller.dart';

/// Carries the [KBarController] down the tree.
///
/// This deliberately propagates the controller's *identity* and nothing else,
/// so [updateShouldNotify] is false for the provider's entire lifetime and
/// `KBarController.of(context)` never itself causes a rebuild. All value
/// changes travel through the controller as a [Listenable], which is what lets
/// each `KBarSelector` rebuild on its own slice instead of on every change.
class KBarScope extends InheritedWidget {
  /// Wraps [child] with access to [controller].
  const KBarScope({required this.controller, required super.child, super.key});

  /// The controller made available to descendants.
  final KBarController controller;

  @override
  bool updateShouldNotify(KBarScope oldWidget) =>
      !identical(controller, oldWidget.controller);
}
