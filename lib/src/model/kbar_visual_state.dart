/// The four-phase lifecycle of the palette's visibility.
///
/// The palette is *mounted* for every value except [hidden], which is what lets
/// the enter and exit animations run before the subtree is torn down.
enum KBarVisualState {
  /// Mounted and playing its entrance animation.
  animatingIn,

  /// Fully open and idle.
  showing,

  /// Still mounted, playing its exit animation.
  animatingOut,

  /// Unmounted. Search query and nested-action state are reset on arrival here.
  hidden;

  /// Whether the palette subtree is mounted.
  bool get isVisible => this != KBarVisualState.hidden;

  /// Whether the palette is open or on its way open.
  bool get isOpening =>
      this == KBarVisualState.animatingIn || this == KBarVisualState.showing;

  /// Whether the palette is closed or on its way closed.
  bool get isClosing =>
      this == KBarVisualState.animatingOut || this == KBarVisualState.hidden;
}
