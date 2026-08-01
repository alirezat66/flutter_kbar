import 'package:flutter/widgets.dart';

import '../model/kbar_state.dart';
import 'kbar_controller.dart';
import 'kbar_equality.dart';

/// Builds with a slice of palette state, and rebuilds only when that slice
/// changes.
///
/// This is the Flutter translation of kbar's `useKBar(collector)`. The
/// defining property is the same: the widget subscribes to the whole store but
/// only rebuilds when the value [selector] returns actually differs, compared
/// with [equals] (deep by default).
///
/// ```dart
/// KBarSelector<String>(
///   selector: (state) => state.searchQuery,
///   builder: (context, query, kbar, child) => Text(query),
/// )
/// ```
///
/// A selector on `searchQuery` will not rebuild when `activeIndex` changes.
class KBarSelector<T> extends StatefulWidget {
  /// Creates a selector.
  const KBarSelector({
    required this.selector,
    required this.builder,
    this.equals,
    this.child,
    super.key,
  });

  /// Extracts the slice of state this widget cares about.
  ///
  /// Keep it cheap: it runs on every state change.
  final T Function(KBarState state) selector;

  /// Builds the subtree from the selected value.
  final Widget Function(
    BuildContext context,
    T value,
    KBarController kbar,
    Widget? child,
  )
  builder;

  /// Decides whether two selected values are the same.
  ///
  /// Defaults to [kbarDefaultEquals], which compares collections element by
  /// element.
  final bool Function(T a, T b)? equals;

  /// Passed through to [builder] unchanged, for subtrees that do not depend on
  /// the selected value.
  final Widget? child;

  @override
  State<KBarSelector<T>> createState() => _KBarSelectorState<T>();
}

class _KBarSelectorState<T> extends State<KBarSelector<T>> {
  KBarController? _controller;
  late T _value;

  bool _equals(T a, T b) => (widget.equals ?? kbarDefaultEquals<T>)(a, b);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final KBarController controller = KBarController.of(context);
    if (identical(controller, _controller)) return;
    _controller?.removeListener(_handleChange);
    _controller = controller..addListener(_handleChange);
    _value = widget.selector(controller.state);
  }

  @override
  void didUpdateWidget(KBarSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selector != oldWidget.selector && _controller != null) {
      _value = widget.selector(_controller!.state);
    }
  }

  void _handleChange() {
    final KBarController? controller = _controller;
    if (controller == null) return;
    final T next = widget.selector(controller.state);
    if (_equals(_value, next)) return;
    setState(() => _value = next);
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _value, _controller!, widget.child);
}

/// Builds from the whole palette state, rebuilding on every change.
///
/// Prefer [KBarSelector] — this rebuilds far more often than it usually needs
/// to. Reach for it only when a subtree genuinely depends on most of the state.
class KBarBuilder extends StatelessWidget {
  /// Creates a builder over the entire state.
  const KBarBuilder({required this.builder, this.child, super.key});

  /// Builds the subtree from the full state snapshot.
  final Widget Function(
    BuildContext context,
    KBarState state,
    KBarController kbar,
    Widget? child,
  )
  builder;

  /// Passed through to [builder] unchanged.
  final Widget? child;

  @override
  Widget build(BuildContext context) => KBarSelector<KBarState>(
    selector: (KBarState state) => state,
    builder: builder,
    child: child,
  );
}
