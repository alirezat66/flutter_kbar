import 'package:flutter/widgets.dart';

import '../keyboard/kbar_keyboard_service.dart';
import '../model/kbar_action.dart';
import '../model/kbar_options.dart';
import '../store/kbar_controller.dart';
import '../store/kbar_scope.dart';

/// Makes a command palette available to everything below it.
///
/// Place this above your app — typically wrapping `MaterialApp` — so that the
/// palette outlives route changes and every page can register actions into it.
///
/// ```dart
/// KBarProvider(
///   actions: myActions,
///   child: MaterialApp(
///     builder: (context, child) => KBarPalette(child: child!),
///     home: const HomePage(),
///   ),
/// )
/// ```
///
/// This widget only provides state and keyboard handling; it renders no UI.
/// Add `KBarPalette` for the bundled interface, or compose `KBarPortal`,
/// `KBarPositioner`, `KBarAnimator`, `KBarSearchField` and `KBarResults`
/// yourself.
class KBarProvider extends StatefulWidget {
  /// Creates a palette scope around [child].
  const KBarProvider({
    required this.child,
    this.actions = const <KBarAction>[],
    this.options = const KBarOptions(),
    this.controller,
    super.key,
  });

  /// Actions available everywhere in the app.
  ///
  /// Page-specific actions are better registered with `KBarRegisterActions`,
  /// which removes them again on unmount.
  final List<KBarAction> actions;

  /// Configuration for shortcuts, animation, callbacks and matching.
  ///
  /// Changing this after the first build takes effect immediately, unlike kbar
  /// which freezes its options on first render.
  final KBarOptions options;

  /// An externally owned controller.
  ///
  /// Supply one to drive the palette from outside the widget tree. When null a
  /// controller is created and disposed automatically. A controller you pass in
  /// is yours to dispose.
  final KBarController? controller;

  /// The subtree with access to this palette.
  final Widget child;

  @override
  State<KBarProvider> createState() => _KBarProviderState();
}

class _KBarProviderState extends State<KBarProvider> {
  KBarController? _ownedController;
  KBarUnregister? _unregister;
  KBarKeyboardService? _keyboard;

  KBarController get _controller => widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    if (widget.controller == null) {
      _ownedController = KBarController(options: widget.options);
    } else {
      widget.controller!.options = widget.options;
    }
    _unregister = _controller.registerActions(widget.actions);
    _keyboard = KBarKeyboardService(_controller)..attach();
  }

  void _detach() {
    // Detach before disposing: the global key handler must not outlive the
    // controller it drives.
    _keyboard?.detach();
    _keyboard = null;
    _unregister?.call();
    _unregister = null;
    _ownedController?.dispose();
    _ownedController = null;
  }

  @override
  void didUpdateWidget(KBarProvider oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      _detach();
      _attach();
      return;
    }

    if (widget.options != oldWidget.options) {
      _controller.options = widget.options;
    }

    if (!_sameActions(widget.actions, oldWidget.actions)) {
      _unregister?.call();
      _unregister = _controller.registerActions(widget.actions);
    }
  }

  static bool _sameActions(List<KBarAction> a, List<KBarAction> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!a[i].sameDefinitionAs(b[i])) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KBarScope(controller: _controller, child: widget.child);
}
