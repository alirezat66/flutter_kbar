import 'package:flutter/widgets.dart';

import '../model/kbar_visual_state.dart';
import '../store/kbar_controller.dart';

/// Animates the palette panel opening, closing, resizing and descending.
///
/// Reproduces kbar's three animations:
///
///  * **Appearance** — `opacity 0 / scale .99` → `opacity 1 / scale 1.01` →
///    `scale 1`, over `enter` with an ease-out curve. The exit plays the same
///    keyframes in reverse with ease-in over `exit`. Flutter expresses that
///    exactly: one [AnimationController] with a `reverseDuration`, wrapped in a
///    [CurvedAnimation] with a `reverseCurve`. `Curves.easeOut` and
///    `Curves.easeIn` are bit-for-bit the CSS `ease-out` and `ease-in` cubics.
///  * **Height** — the panel grows and shrinks with the result list over
///    `enter / 2`, via [AnimatedSize].
///  * **Bump** — `scale 1 → .98 → 1` when descending into a nested action,
///    skipped on first render so opening the palette does not bump.
class KBarAnimator extends StatefulWidget {
  /// Animates [child].
  const KBarAnimator({
    required this.child,
    this.enableBump = true,
    this.enableResize = true,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  /// The panel contents.
  final Widget child;

  /// Whether descending into a nested action plays the bump animation.
  final bool enableBump;

  /// Whether the panel animates between heights as results change.
  final bool enableResize;

  /// Anchor for the scale and resize animations.
  ///
  /// Top-centre keeps the search field still while the list grows downward.
  final AlignmentGeometry alignment;

  @override
  State<KBarAnimator> createState() => _KBarAnimatorState();
}

class _KBarAnimatorState extends State<KBarAnimator>
    with TickerProviderStateMixin {
  late final AnimationController _appearance = AnimationController(
    vsync: this,
    duration: Duration.zero,
    reverseDuration: Duration.zero,
  );
  late final AnimationController _bump = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );

  late final Animation<double> _curved = CurvedAnimation(
    parent: _appearance,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );

  // Web Animations assigns the three keyframes implicit offsets 0 / 0.5 / 1.
  // Opacity's last explicit stop is the middle one, so it holds at 1 from there.
  late final Animation<double> _opacity =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 0, end: 1),
          weight: 50,
        ),
        TweenSequenceItem<double>(tween: ConstantTween<double>(1), weight: 50),
      ]).animate(_curved);

  late final Animation<double> _scale =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 0.99, end: 1.01),
          weight: 50,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 1.01, end: 1),
          weight: 50,
        ),
      ]).animate(_curved);

  late final Animation<double> _bumpScale =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 1, end: 0.98),
          weight: 50,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 0.98, end: 1),
          weight: 50,
        ),
      ]).animate(CurvedAnimation(parent: _bump, curve: Curves.easeOut));

  KBarController? _controller;
  KBarVisualState _lastVisualState = KBarVisualState.hidden;
  String? _lastRootId;
  bool _sawFirstRoot = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final KBarController controller = KBarController.of(context);
    if (identical(controller, _controller)) return;
    _controller?.removeListener(_handleControllerChanged);
    _controller = controller..addListener(_handleControllerChanged);
    _syncDurations();
    _lastRootId = controller.state.currentRootActionId;
    _applyVisualState(controller.state.visualState);
  }

  void _syncDurations() {
    final KBarController controller = _controller!;
    _appearance
      ..duration = controller.options.animations.enter
      ..reverseDuration = controller.options.animations.exit;
    _bump.duration = controller.options.animations.enter;
  }

  void _handleControllerChanged() {
    _syncDurations();
    final KBarController controller = _controller!;

    final KBarVisualState visualState = controller.state.visualState;
    if (visualState != _lastVisualState) _applyVisualState(visualState);

    final String? rootId = controller.state.currentRootActionId;
    if (rootId != _lastRootId) {
      _lastRootId = rootId;
      // Skip the very first root we see after opening: kbar bumps only on a
      // genuine navigation, not on the initial render.
      if (_sawFirstRoot && widget.enableBump && visualState.isVisible) {
        _bump.forward(from: 0);
      }
      _sawFirstRoot = true;
    }
  }

  void _applyVisualState(KBarVisualState visualState) {
    _lastVisualState = visualState;
    switch (visualState) {
      case KBarVisualState.animatingIn:
        // forward() resumes from wherever an interrupted exit left off, so
        // reopening mid-close is smooth for free.
        _appearance.forward();
      case KBarVisualState.showing:
        _appearance.value = 1;
      case KBarVisualState.animatingOut:
        _appearance.reverse();
      case KBarVisualState.hidden:
        _appearance.value = 0;
        _sawFirstRoot = false;
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleControllerChanged);
    _appearance.dispose();
    _bump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Duration resizeDuration =
        (_controller?.options.animations.enter ?? Duration.zero) ~/ 2;

    final Widget animated = AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_curved, _bumpScale]),
      child: widget.child,
      builder: (BuildContext context, Widget? child) => Opacity(
        opacity: _opacity.value.clamp(0.0, 1.0),
        child: Transform.scale(
          // Composing the two scales multiplicatively avoids a second
          // Transform layer.
          scale: _scale.value * _bumpScale.value,
          alignment: widget.alignment,
          child: child,
        ),
      ),
    );

    // A zero duration must skip AnimatedSize entirely, not pass zero to it:
    // its internal controller would complete synchronously inside its own
    // performLayout and re-dirty itself, which asserts. This is the path
    // KBarAnimations.none takes, so it matters for every golden test.
    if (!widget.enableResize || resizeDuration <= Duration.zero) {
      return animated;
    }

    // AnimatedSize sits *outside* the appearance animation. Nesting it inside
    // means every tick of the entrance rebuilds within AnimatedSize's subtree
    // while it is laying out, which re-dirties it mid-layout.
    return AnimatedSize(
      alignment: widget.alignment,
      duration: resizeDuration,
      curve: Curves.easeOut,
      child: animated,
    );
  }
}
