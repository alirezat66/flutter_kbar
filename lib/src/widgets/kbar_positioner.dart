import 'package:flutter/widgets.dart';

/// Places the palette on screen.
///
/// Anchors near the top rather than centring vertically, which is the
/// convention for command palettes: the eye starts at the search field and the
/// result list grows downward without shifting it.
class KBarPositioner extends StatelessWidget {
  /// Positions [child] within the available space.
  const KBarPositioner({
    required this.child,
    this.topFraction = 0.14,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.maxWidth = 620,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  /// The palette panel.
  final Widget child;

  /// Distance from the top of the viewport, as a fraction of its height.
  ///
  /// Defaults to kbar's `14vh`.
  final double topFraction;

  /// Insets applied around the panel.
  final EdgeInsetsGeometry padding;

  /// Widest the panel may become.
  final double maxWidth;

  /// Where the panel sits within the viewport.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double top = media.size.height * topFraction;

    return Padding(
      // Keep clear of the on-screen keyboard and any system insets.
      padding: EdgeInsets.only(
        top: top,
        bottom: 16 + media.viewInsets.bottom,
      ).add(padding),
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
