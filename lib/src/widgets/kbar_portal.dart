import 'package:flutter/widgets.dart';

import '../model/kbar_visual_state.dart';
import '../store/kbar_controller.dart';

/// Mounts the palette above everything else while it is open.
///
/// Uses [OverlayPortal] targeting the root overlay rather than pushing a route,
/// for two reasons:
///
///  * **Inherited widgets keep working.** An overlay child stays in the same
///    *element* tree as this widget, so `KBarController.of`, `Theme.of`,
///    `MediaQuery` and your own providers all resolve normally inside the
///    palette. A route's builder runs under the root `Navigator`, where every
///    one of those lookups would have to be re-injected by hand.
///  * **A palette is not a navigation destination.** Pushing a route changes
///    `Navigator.canPop()`, interferes with the host app's `PopScope` logic,
///    and can disturb browser history on the web.
///
/// The subtree is fully unmounted while closed, matching kbar, which is why
/// search state resets naturally and autofocus works on every open.
class KBarPortal extends StatefulWidget {
  /// Mounts [child] while the palette is open.
  const KBarPortal({
    required this.child,
    this.barrierColor = const Color(0x66000000),
    this.barrierSemanticLabel = 'Dismiss command palette',
    super.key,
  });

  /// The palette UI — typically a `KBarPositioner` wrapping a `KBarAnimator`.
  final Widget child;

  /// Colour painted over the app behind the palette.
  ///
  /// Use [Color] `0x00000000` for no scrim.
  final Color barrierColor;

  /// Accessibility label for the dismiss barrier.
  final String barrierSemanticLabel;

  @override
  State<KBarPortal> createState() => _KBarPortalState();
}

class _KBarPortalState extends State<KBarPortal> {
  final OverlayPortalController _portal = OverlayPortalController(
    debugLabel: 'kbar',
  );
  final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'kbar');

  KBarController? _controller;
  FocusNode? _focusToRestore;
  KBarVisualState _lastVisualState = KBarVisualState.hidden;

  /// Whether an [Overlay] is available to host the palette.
  ///
  /// It is not when the palette sits in `MaterialApp.builder`, which runs
  /// *above* the app's [Navigator] and therefore above its overlay. That is the
  /// recommended placement, because a palette declared there survives route
  /// changes — so rather than rejecting it, the portal renders inline in that
  /// case. Being the last child of the builder's stack already puts it above
  /// every route, which is what the overlay would have achieved anyway.
  bool _hasOverlay = false;

  bool get _isVisible => _lastVisualState.isVisible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hasOverlay = Overlay.maybeOf(context, rootOverlay: true) != null;

    final KBarController controller = KBarController.of(context);
    if (identical(controller, _controller)) return;
    _controller?.removeListener(_handleControllerChanged);
    _controller = controller..addListener(_handleControllerChanged);
    _syncVisibility();
  }

  void _handleControllerChanged() {
    if (_controller!.state.visualState == _lastVisualState) return;
    _syncVisibility();
  }

  void _syncVisibility() {
    final bool wasVisible = _isVisible;
    final KBarVisualState next = _controller!.state.visualState;
    _lastVisualState = next;
    if (next.isVisible == wasVisible) return;

    if (next.isVisible) {
      // Capture the outgoing focus before the palette takes it.
      _focusToRestore = FocusManager.instance.primaryFocus;
      if (_hasOverlay) _portal.show();
    } else {
      // Decide before hiding, while the palette subtree is still mounted and
      // its focus node is still reachable.
      final bool restore =
          _controller!.options.restoreFocusOnClose && _focusIsStillOurs();

      if (_hasOverlay) _portal.hide();

      if (restore) {
        final FocusNode? target = _focusToRestore;
        if (target != null &&
            target.canRequestFocus &&
            (target.context?.mounted ?? false)) {
          target.requestFocus();
        }
      }
      _focusToRestore = null;
    }

    if (!_hasOverlay && mounted) setState(() {});
  }

  /// Whether focus is still the palette's to hand back.
  ///
  /// An action's `perform` runs while the palette is closing, and it may open a
  /// dialog or route that takes focus for itself. Restoring unconditionally
  /// would then yank focus away from that dialog a moment later — once the exit
  /// animation finishes — leaving the user typing into nothing.
  bool _focusIsStillOurs() {
    final FocusNode? current = FocusManager.instance.primaryFocus;
    if (current == null) return true;
    if (identical(current, _scope)) return true;
    return _scope.descendants.contains(current);
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleControllerChanged);
    _scope.dispose();
    super.dispose();
  }

  Widget _buildPalette(BuildContext context) {
    final KBarController controller = _controller!;
    final bool dismissible = controller.options.closeOnOutsideTap;
    return Actions(
      // A dismiss handler of our own, because the palette does not live inside
      // a ModalRoute and so nothing else provides one. Without it, Escape
      // reaching the search field asserts on an unhandled DismissIntent.
      actions: <Type, Action<Intent>>{
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (DismissIntent intent) {
            if (controller.options.closeOnEscape) controller.close();
            return null;
          },
        ),
      },
      child: FocusScope(
        node: _scope,
        child: Stack(
          children: <Widget>[
            // ModalBarrier both paints the scrim and blocks interaction with
            // the app behind, and gives the dismiss gesture proper semantics.
            ModalBarrier(
              color: widget.barrierColor,
              dismissible: dismissible,
              semanticsLabel: widget.barrierSemanticLabel,
              onDismiss: dismissible
                  ? () {
                      controller.close();
                      controller.options.callbacks.onClose?.call();
                    }
                  : null,
            ),
            widget.child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasOverlay) {
      if (!_isVisible) return const SizedBox.shrink();
      // Supply an Overlay of our own. EditableText requires one for its
      // selection handles and toolbar, so the search field would assert
      // without it.
      return Overlay(
        clipBehavior: Clip.none,
        initialEntries: <OverlayEntry>[OverlayEntry(builder: _buildPalette)],
      );
    }
    return OverlayPortal(
      controller: _portal,
      // The root overlay, so a palette declared inside a nested Navigator or
      // tab shell still paints above the whole app.
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: _buildPalette,
      child: const SizedBox.shrink(),
    );
  }
}
