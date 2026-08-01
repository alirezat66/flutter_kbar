import 'dart:math';

final Random _random = Random();
int _counter = 0;

/// Generates a short, process-unique identifier for an action.
///
/// kbar uses `Math.random().toString(36).substring(2, 9)`, which can collide.
/// A monotonic counter is mixed in so ids are unique within a single process
/// regardless of how unlucky the random source is.
String kbarRandomId() {
  final int n = _random.nextInt(1 << 32);
  final String suffix = (_counter++).toRadixString(36);
  return 'kbar_${n.toRadixString(36)}_$suffix';
}
