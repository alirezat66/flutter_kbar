/// Conventional priority values for actions and sections.
///
/// Priority is a plain [int], so any value works; these are the three named
/// constants kbar ships. Higher sorts first.
///
/// Named `KBarPriority` rather than `Priority` because `package:flutter`'s
/// `scheduler` library already exports a `Priority` class.
abstract final class KBarPriority {
  /// Sorts after [normal]. Equivalent to kbar's `Priority.LOW`.
  static const int low = -1;

  /// The default. Equivalent to kbar's `Priority.NORMAL`.
  static const int normal = 0;

  /// Sorts before [normal]. Equivalent to kbar's `Priority.HIGH`.
  static const int high = 1;
}
