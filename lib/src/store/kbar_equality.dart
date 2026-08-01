import 'package:collection/collection.dart';

const DeepCollectionEquality _deep = DeepCollectionEquality();

/// The comparison `KBarSelector` uses to decide whether a slice really changed.
///
/// This is the Dart equivalent of the deep-equality check kbar runs on every
/// collector's output before notifying it. Collections are compared element by
/// element so that a selector returning, say, `List<KBarActionNode>` does not
/// rebuild merely because a fresh list was allocated.
///
/// Deep comparison of a [KBarActionNode] is safe despite the action tree being
/// cyclic, because node equality never dereferences `children` or `ancestors`.
bool kbarDefaultEquals<T>(T a, T b) {
  if (identical(a, b)) return true;
  if (a is Iterable || a is Map || a is Set) return _deep.equals(a, b);
  return a == b;
}
