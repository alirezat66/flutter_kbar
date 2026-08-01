import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../model/kbar_action.dart';
import '../store/kbar_controller.dart';

/// Registers [actions] for as long as this widget is mounted.
///
/// The Flutter translation of kbar's `useRegisterActions`. Actions appear when
/// the widget mounts and disappear when it unmounts, which is how a page
/// contributes its own commands to a palette declared far above it.
///
/// ```dart
/// KBarRegisterActions(
///   actions: [createAction(name: 'Save', perform: (_) => save())],
///   child: MyPage(),
/// )
/// ```
///
/// Re-registration follows React's dependency-array semantics:
///
///  * With [deps] given, actions are re-registered only when [deps] changes.
///  * With [deps] omitted, [actions] is diffed by
///    [KBarAction.sameDefinitionAs], which ignores `perform` and `icon`.
///    Comparing closures would re-register on every rebuild, since a closure
///    created in `build` never equals the previous one.
class KBarRegisterActions extends StatefulWidget {
  /// Registers [actions] while [child] is mounted.
  const KBarRegisterActions({
    required this.actions,
    required this.child,
    this.deps,
    super.key,
  });

  /// The actions to register.
  final List<KBarAction> actions;

  /// Values that, when changed, force re-registration.
  ///
  /// Pass this when [actions] closes over state whose changes must be picked
  /// up even though the action definitions look identical.
  final List<Object?>? deps;

  /// The subtree these actions belong to.
  final Widget child;

  @override
  State<KBarRegisterActions> createState() => _KBarRegisterActionsState();
}

class _KBarRegisterActionsState extends State<KBarRegisterActions> {
  KBarController? _controller;
  KBarUnregister? _unregister;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final KBarController controller = KBarController.of(context);
    if (identical(controller, _controller)) return;
    _controller = controller;
    _register();
  }

  @override
  void didUpdateWidget(KBarRegisterActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldReregister(oldWidget)) _register();
  }

  bool _shouldReregister(KBarRegisterActions oldWidget) {
    if (widget.deps != null || oldWidget.deps != null) {
      return !listEquals(widget.deps, oldWidget.deps);
    }
    if (widget.actions.length != oldWidget.actions.length) return true;
    for (int i = 0; i < widget.actions.length; i++) {
      if (!widget.actions[i].sameDefinitionAs(oldWidget.actions[i])) {
        return true;
      }
    }
    return false;
  }

  void _register() {
    _unregister?.call();
    _unregister = _controller?.registerActions(widget.actions);
  }

  @override
  void dispose() {
    _unregister?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Registers actions from a [StatefulWidget]'s state.
///
/// An alternative to [KBarRegisterActions] for pages that already have a
/// [State] and would rather not add a wrapper widget. Implement
/// [buildKBarActions], and call [refreshKBarActions] whenever the actions
/// should change.
///
/// ```dart
/// class _EditorState extends State<Editor> with KBarActionsMixin<Editor> {
///   @override
///   List<KBarAction> buildKBarActions() => [
///     createAction(name: 'Save', perform: (_) => _save()),
///   ];
/// }
/// ```
mixin KBarActionsMixin<T extends StatefulWidget> on State<T> {
  KBarController? _kbarController;
  KBarUnregister? _kbarUnregister;

  /// The actions this widget contributes while mounted.
  List<KBarAction> buildKBarActions();

  /// Re-runs [buildKBarActions] and replaces the registered actions.
  void refreshKBarActions() {
    _kbarUnregister?.call();
    _kbarUnregister = _kbarController?.registerActions(buildKBarActions());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final KBarController controller = KBarController.of(context);
    if (identical(controller, _kbarController)) return;
    _kbarController = controller;
    refreshKBarActions();
  }

  @override
  void dispose() {
    _kbarUnregister?.call();
    super.dispose();
  }
}
