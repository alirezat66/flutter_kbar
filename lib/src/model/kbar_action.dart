import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../util/kbar_id.dart';
import 'kbar_action_registry.dart';
import 'kbar_priority.dart';
import 'kbar_section.dart';

/// Reverses the effect of a [KBarPerform].
///
/// Registered from inside a [KBarPerform] to make the action undoable, and only
/// recorded when history is enabled via `KBarOptions.enableHistory`.
typedef KBarUndo = FutureOr<void> Function();

/// Runs an action.
///
/// Two deliberate differences from kbar:
///
///  * This may return a [Future]; the controller awaits it before closing the
///    palette. Flutter commands are frequently asynchronous (`await save()`),
///    which kbar's synchronous `perform` cannot express.
///  * kbar makes an action undoable by *returning* the undo function. That is
///    undiscoverable, and in Dart it would force every ordinary command to end
///    in `return null` just to satisfy the analyzer. Call
///    [KBarActionContext.undoWith] instead, from inside the body where the
///    state being changed is already in scope.
typedef KBarPerform = FutureOr<void> Function(KBarActionContext context);

/// What a [KBarPerform] is given when it runs.
class KBarActionContext {
  /// Creates a context. Built by the controller; you only ever receive one.
  const KBarActionContext({
    required this.action,
    required void Function(KBarUndo undo) recordUndo,
  }) : _recordUndo = recordUndo;

  /// The action being performed, with its place in the tree resolved.
  final KBarActionNode action;

  final void Function(KBarUndo undo) _recordUndo;

  /// Makes this run undoable.
  ///
  /// Call from inside `perform`, where the previous state is still in scope:
  ///
  /// ```dart
  /// perform: (context) {
  ///   final previous = theme.mode;
  ///   theme.mode = ThemeMode.dark;
  ///   context.undoWith(() => theme.mode = previous);
  /// }
  /// ```
  ///
  /// Ignored unless `KBarOptions.enableHistory` is set.
  void undoWith(KBarUndo undo) => _recordUndo(undo);
}

/// The immutable definition of a single command in the palette.
///
/// Named `KBarAction` rather than `Action` because `package:flutter`'s widgets
/// library already exports `Action<T extends Intent>`.
///
/// Actions form a tree via [parent]. An action with children but no [perform]
/// acts as a navigational "page": selecting it descends into its children
/// instead of executing anything.
@immutable
class KBarAction {
  /// Creates an action with an explicit [id].
  ///
  /// Prefer [KBarAction.auto] (or the top-level `createAction`) when the id is
  /// not meaningful to your app.
  const KBarAction({
    required this.id,
    required this.name,
    this.shortcut = const <String>[],
    this.keywords,
    this.section,
    this.icon,
    this.subtitle,
    this.perform,
    this.parent,
    this.priority = KBarPriority.normal,
  });

  /// Creates an action with a generated [id].
  ///
  /// Equivalent to kbar's `createAction`.
  KBarAction.auto({
    required this.name,
    this.shortcut = const <String>[],
    this.keywords,
    this.section,
    this.icon,
    this.subtitle,
    this.perform,
    this.parent,
    this.priority = KBarPriority.normal,
  }) : id = kbarRandomId();

  /// Unique identifier. Registering a second action with the same id replaces
  /// the first.
  final String id;

  /// The primary label, and the highest-signal field for search.
  final String name;

  /// Key bindings that trigger this action while the palette is *closed*.
  ///
  /// Each entry is a single "press" in tinykeys syntax; a list of more than one
  /// entry forms a *sequence*. For example `['g', 'h']` means "press g, then
  /// h", and `[r'$mod+k']` means Command+K on Apple platforms and Control+K
  /// everywhere else.
  ///
  /// If this action has children, triggering its shortcut opens the palette
  /// scoped to this action rather than performing it.
  final List<String> shortcut;

  /// Additional comma-separated search terms.
  ///
  /// The [section] name is appended to these automatically, so typing a section
  /// name surfaces its members.
  final String? keywords;

  /// The group this action is listed under. Null renders it without a heading.
  final KBarSection? section;

  /// Leading widget rendered by the default result tile.
  ///
  /// kbar never renders the icon itself; here the bundled `KBarPalette` does,
  /// but custom item builders are free to ignore it.
  final Widget? icon;

  /// Secondary descriptive text. Also searched.
  final String? subtitle;

  /// What running this action does.
  ///
  /// When null, the action is navigational: selecting it descends into its
  /// children instead of executing.
  final KBarPerform? perform;

  /// The [id] of this action's parent, or null for a top-level action.
  final String? parent;

  /// Ordering weight. Higher sorts first. See [KBarPriority].
  final int priority;

  /// Returns a copy with the given fields replaced.
  KBarAction copyWith({
    String? id,
    String? name,
    List<String>? shortcut,
    String? keywords,
    KBarSection? section,
    Widget? icon,
    String? subtitle,
    KBarPerform? perform,
    String? parent,
    int? priority,
  }) {
    return KBarAction(
      id: id ?? this.id,
      name: name ?? this.name,
      shortcut: shortcut ?? this.shortcut,
      keywords: keywords ?? this.keywords,
      section: section ?? this.section,
      icon: icon ?? this.icon,
      subtitle: subtitle ?? this.subtitle,
      perform: perform ?? this.perform,
      parent: parent ?? this.parent,
      priority: priority ?? this.priority,
    );
  }

  /// Whether two actions describe the same command, ignoring [perform] and
  /// [icon].
  ///
  /// Used to decide whether a re-registered action list actually changed.
  /// Closures rebuilt on every `build()` never compare equal, so comparing
  /// [perform] would cause an unregister/register storm.
  bool sameDefinitionAs(KBarAction other) =>
      other.id == id &&
      other.name == name &&
      listEquals(other.shortcut, shortcut) &&
      other.keywords == keywords &&
      other.section == section &&
      other.subtitle == subtitle &&
      other.parent == parent &&
      other.priority == priority;

  /// Value equality over every field except [perform].
  ///
  /// [perform] is excluded because a closure has no useful notion of equality
  /// across rebuilds.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KBarAction && sameDefinitionAs(other) && other.icon == icon;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(shortcut),
    keywords,
    section,
    subtitle,
    parent,
    priority,
    icon,
  );

  @override
  String toString() => 'KBarAction($id, "$name")';
}

/// Creates an action with a generated id.
///
/// The direct equivalent of kbar's `createAction`.
KBarAction createAction({
  required String name,
  List<String> shortcut = const <String>[],
  String? keywords,
  KBarSection? section,
  Widget? icon,
  String? subtitle,
  KBarPerform? perform,
  String? parent,
  int priority = KBarPriority.normal,
}) {
  return KBarAction.auto(
    name: name,
    shortcut: shortcut,
    keywords: keywords,
    section: section,
    icon: icon,
    subtitle: subtitle,
    perform: perform,
    parent: parent,
    priority: priority,
  );
}
