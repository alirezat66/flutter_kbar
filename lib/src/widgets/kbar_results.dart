import 'package:flutter/widgets.dart';

import '../model/kbar_result_item.dart';
import '../store/kbar_controller.dart';
import 'kbar_matches_builder.dart';

/// Builds one row of the result list.
///
/// [item] is either a [KBarSectionHeader] or a [KBarActionResult]; switch on it
/// exhaustively.
typedef KBarItemBuilder =
    Widget Function(
      BuildContext context,
      KBarResultItem item,
      int index,
      bool isActive,
    );

/// The scrolling list of section headings and matching actions.
///
/// Handles keyboard-driven scrolling and pointer hover; the appearance of each
/// row is entirely up to [itemBuilder].
class KBarResults extends StatefulWidget {
  /// Creates the result list.
  const KBarResults({
    required this.itemBuilder,
    this.maxHeight = 400,
    this.padding,
    this.emptyBuilder,
    this.revealDuration = const Duration(milliseconds: 120),
    super.key,
  });

  /// Builds each row.
  final KBarItemBuilder itemBuilder;

  /// Tallest the list may grow before it scrolls.
  final double maxHeight;

  /// Insets inside the scroll view.
  final EdgeInsetsGeometry? padding;

  /// Builds the empty state. Renders nothing when omitted.
  final Widget Function(BuildContext context, String query)? emptyBuilder;

  /// How long scrolling the highlighted row into view takes.
  final Duration revealDuration;

  @override
  State<KBarResults> createState() => _KBarResultsState();
}

class _KBarResultsState extends State<KBarResults> {
  final ScrollController _scroll = ScrollController();
  final Map<int, BuildContext> _rowContexts = <int, BuildContext>{};

  KBarController? _controller;
  int _lastActiveIndex = 0;

  /// Hover must not steal the highlight until the pointer has genuinely moved.
  ///
  /// Otherwise opening the palette under a stationary cursor immediately
  /// overrides the keyboard's selection.
  bool _pointerHasMoved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final KBarController controller = KBarController.of(context);
    if (identical(controller, _controller)) return;
    _controller?.removeListener(_handleControllerChanged);
    _controller = controller..addListener(_handleControllerChanged);
    _lastActiveIndex = controller.state.activeIndex;
  }

  void _handleControllerChanged() {
    final int index = _controller!.state.activeIndex;
    if (index == _lastActiveIndex) return;
    final bool movingDown = index > _lastActiveIndex;
    _lastActiveIndex = index;
    // Reveal after layout, so a row that has just appeared has a context.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(index, movingDown: movingDown),
    );
  }

  void _reveal(int index, {required bool movingDown}) {
    if (!mounted || !_scroll.hasClients) return;

    // react-virtual's `align: 'end'` for the first rows resolves, after
    // clamping, to "scroll to the very top" — which is what keeps a leading
    // section heading visible. Translating that literally as an alignment
    // value would instead re-centre the list on every keypress.
    if (index <= 1) {
      if (_scroll.offset != 0) {
        _scroll.animateTo(
          0,
          duration: widget.revealDuration,
          curve: Curves.easeOut,
        );
      }
      return;
    }

    final BuildContext? rowContext = _rowContexts[index];
    if (rowContext == null || !rowContext.mounted) return;

    Scrollable.ensureVisible(
      rowContext,
      duration: widget.revealDuration,
      curve: Curves.easeOut,
      // Minimal scroll in the direction of travel, matching react-virtual's
      // 'auto'. A fixed alignment would re-centre instead.
      alignmentPolicy: movingDown
          ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
          : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleControllerChanged);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KBarMatchesBuilder(
      builder:
          (
            BuildContext context,
            KBarMatches matches,
            KBarController kbar,
            Widget? child,
          ) {
            if (matches.isEmpty) {
              return widget.emptyBuilder?.call(context, matches.query) ??
                  const SizedBox.shrink();
            }

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxHeight),
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                child: ListView.builder(
                  controller: _scroll,
                  padding: widget.padding,
                  // The viewport is hard-capped above, so shrink-wrapping is
                  // safe here — and it is what lets KBarAnimator measure and
                  // animate the panel's height.
                  shrinkWrap: true,
                  itemCount: matches.items.length,
                  itemBuilder: (BuildContext context, int index) =>
                      _buildRow(context, matches, kbar, index),
                ),
              ),
            );
          },
    );
  }

  Widget _buildRow(
    BuildContext context,
    KBarMatches matches,
    KBarController kbar,
    int index,
  ) {
    final KBarResultItem item = matches.items[index];

    return Builder(
      builder: (BuildContext rowContext) {
        _rowContexts[index] = rowContext;

        if (item is! KBarActionResult) {
          // Headings are inert: no hover, no tap, no highlight.
          return widget.itemBuilder(rowContext, item, index, false);
        }

        return KBarActiveIndexListener(
          index: index,
          builder: (BuildContext context, bool isActive) {
            final Widget row = widget.itemBuilder(
              rowContext,
              item,
              index,
              isActive,
            );
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Listener(
                // onPointerHover, not MouseRegion.onEnter: onEnter also fires
                // when the list scrolls beneath a stationary cursor, which
                // makes the mouse fight keyboard navigation.
                onPointerHover: (_) {
                  if (!_pointerHasMoved) {
                    _pointerHasMoved = true;
                    return;
                  }
                  kbar.setActiveIndex(index);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => kbar.performAction(item.action),
                  child: row,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Rebuilds only when a particular row's highlighted state changes.
///
/// Selecting on `activeIndex == index` rather than on `activeIndex` means
/// moving the highlight rebuilds two rows, not the whole list.
class KBarActiveIndexListener extends StatefulWidget {
  /// Watches whether [index] is the highlighted row.
  const KBarActiveIndexListener({
    required this.index,
    required this.builder,
    super.key,
  });

  /// The row being watched.
  final int index;

  /// Builds the row from its highlighted state.
  final Widget Function(BuildContext context, bool isActive) builder;

  @override
  State<KBarActiveIndexListener> createState() =>
      _KBarActiveIndexListenerState();
}

class _KBarActiveIndexListenerState extends State<KBarActiveIndexListener> {
  KBarController? _controller;
  late bool _isActive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final KBarController controller = KBarController.of(context);
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_handleChange);
      _controller = controller..addListener(_handleChange);
    }
    _isActive = controller.state.activeIndex == widget.index;
  }

  @override
  void didUpdateWidget(KBarActiveIndexListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) _handleChange();
  }

  void _handleChange() {
    final bool next = _controller!.state.activeIndex == widget.index;
    if (next == _isActive) return;
    setState(() => _isActive = next);
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _isActive);
}
