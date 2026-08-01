import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_kbar/flutter_kbar.dart';

/// Makes <kbd>Esc</kbd> go back anywhere in the app.
///
/// Closes whatever is on top — a dialog, or a pushed page — and does nothing at
/// the root, so Escape on the home page is simply ignored. The command palette
/// keeps its own Escape handling.
///
/// ## Why a private intent instead of `DismissIntent`
///
/// `WidgetsApp` already binds Escape to [DismissIntent], so reusing it looks
/// obvious — but it cannot work. [ModalRoute] installs its own `DismissIntent`
/// action around every route, enabled only for a dismissible barrier, and
/// `Actions.maybeFind` stops at the **first** action it finds for a type
/// whether or not that action is enabled. A page route's disabled handler
/// therefore shadows any ancestor one, and Escape does nothing.
///
/// Dispatching a type nobody else claims avoids the collision entirely. This
/// widget's [Shortcuts] also sits below `WidgetsApp`'s, so it sees Escape
/// first; when its action is disabled the event simply carries on upward to the
/// usual `DismissIntent` path.
///
/// ## Cooperating with the palette
///
/// The action disables itself while the palette is visible, so Escape closes
/// the palette and nothing else. Without that guard, Escape would close the
/// palette *and* pop the route behind it — the palette's Escape is handled
/// before the focus tree ever sees the key, so both would fire.
///
/// `isVisible` rather than `isOpen`: a palette part-way through its exit
/// animation is no longer "open", but the keystroke that closed it should still
/// not pop anything.
class EscapeToGoBack extends StatelessWidget {
  /// Wraps [child] so Escape pops the top route.
  const EscapeToGoBack({
    required this.navigatorKey,
    required this.child,
    super.key,
  });

  /// The navigator to pop.
  ///
  /// A key rather than `Navigator.of(context)` because this widget is intended
  /// for `MaterialApp.builder`, which runs *above* the navigator it wraps.
  final GlobalKey<NavigatorState> navigatorKey;

  /// The app.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): _GoBackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _GoBackIntent: _EscapeBackAction(
            navigatorKey,
            KBarController.maybeOf(context),
          ),
        },
        child: child,
      ),
    );
  }
}

/// Escape, as a type no other widget in the tree handles.
class _GoBackIntent extends Intent {
  const _GoBackIntent();
}

class _EscapeBackAction extends Action<_GoBackIntent> {
  _EscapeBackAction(this.navigatorKey, this.kbar);

  final GlobalKey<NavigatorState> navigatorKey;
  final KBarController? kbar;

  /// Disabled at the root and while the palette is up, so the key falls through
  /// to whatever else wants it rather than being swallowed.
  @override
  bool isEnabled(_GoBackIntent intent, [BuildContext? context]) {
    if (kbar?.state.isVisible ?? false) return false;
    return navigatorKey.currentState?.canPop() ?? false;
  }

  @override
  Object? invoke(_GoBackIntent intent) {
    // maybePop, not pop: a route that guards itself with PopScope still gets
    // the final say.
    navigatorKey.currentState?.maybePop();
    return null;
  }
}
