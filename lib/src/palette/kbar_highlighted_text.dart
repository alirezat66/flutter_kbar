import 'package:flutter/material.dart';

import '../match/kbar_matcher.dart';

/// Text with the characters that matched the query emphasised.
///
/// kbar asks fuse.js for match positions and then throws them away; surfacing
/// them is one of the things this port adds. Ranges come from
/// [KBarMatch.nameRanges].
class KBarHighlightedText extends StatelessWidget {
  /// Renders [text], emphasising [ranges].
  const KBarHighlightedText(
    this.text, {
    this.ranges = const <KBarTextRange>[],
    this.style,
    this.highlightStyle,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    super.key,
  });

  /// The full string.
  final String text;

  /// Half-open ranges to emphasise. Overlaps and bad bounds are tolerated.
  final List<KBarTextRange> ranges;

  /// Style for unmatched characters.
  final TextStyle? style;

  /// Style merged over [style] for matched characters.
  final TextStyle? highlightStyle;

  /// Maximum lines before truncating.
  final int maxLines;

  /// How to truncate.
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    if (ranges.isEmpty || highlightStyle == null) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }

    return Text.rich(
      TextSpan(children: _spans()),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  List<TextSpan> _spans() {
    // Clamp and merge first: fuse can report several adjacent single-character
    // hits, and rendering each as its own span would be wasteful.
    final List<KBarTextRange> clean = <KBarTextRange>[
      for (final KBarTextRange range in ranges)
        if (range.start < text.length && range.end > range.start)
          KBarTextRange(
            range.start.clamp(0, text.length),
            range.end.clamp(0, text.length),
          ),
    ]..sort((KBarTextRange a, KBarTextRange b) => a.start.compareTo(b.start));

    final List<KBarTextRange> merged = <KBarTextRange>[];
    for (final KBarTextRange range in clean) {
      if (merged.isNotEmpty && range.start <= merged.last.end) {
        final KBarTextRange last = merged.removeLast();
        merged.add(
          KBarTextRange(
            last.start,
            range.end > last.end ? range.end : last.end,
          ),
        );
      } else {
        merged.add(range);
      }
    }

    final List<TextSpan> spans = <TextSpan>[];
    int cursor = 0;
    for (final KBarTextRange range in merged) {
      if (range.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, range.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(range.start, range.end),
          style: highlightStyle,
        ),
      );
      cursor = range.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }
}
