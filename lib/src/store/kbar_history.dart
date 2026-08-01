import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/kbar_action.dart';

/// One undoable step.
@immutable
class KBarHistoryEntry {
  /// Creates an entry.
  const KBarHistoryEntry({
    required this.actionId,
    required this.undo,
    required this.redo,
  });

  /// The action that produced this step.
  final String actionId;

  /// Reverses the step.
  final KBarUndo undo;

  /// Re-applies the step by performing the action again.
  final Future<void> Function() redo;
}

/// Undo and redo stacks for actions that registered an undo.
///
/// Opt in with `KBarOptions.enableHistory`. Only actions that call
/// `KBarActionContext.undoWith` inside their `perform` are recorded; everything
/// else runs untracked.
///
/// Note that history has no effect on ranking. kbar has no notion of recency
/// or frecency, and neither does this — if you want a "Recents" section, build
/// it yourself with a high-priority [KBarSection].
class KBarHistory extends ChangeNotifier {
  final List<KBarHistoryEntry> _undoStack = <KBarHistoryEntry>[];
  final List<KBarHistoryEntry> _redoStack = <KBarHistoryEntry>[];

  /// Steps available to undo, oldest first.
  List<KBarHistoryEntry> get undoStack =>
      List<KBarHistoryEntry>.unmodifiable(_undoStack);

  /// Steps available to redo, oldest first.
  List<KBarHistoryEntry> get redoStack =>
      List<KBarHistoryEntry>.unmodifiable(_redoStack);

  /// Whether there is anything to undo.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there is anything to redo.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Records a step.
  ///
  /// Performing the same action again replaces its previous record rather than
  /// stacking a second one, matching kbar.
  void record(KBarHistoryEntry entry) {
    _undoStack.removeWhere(
      (KBarHistoryEntry e) => e.actionId == entry.actionId,
    );
    _redoStack.removeWhere(
      (KBarHistoryEntry e) => e.actionId == entry.actionId,
    );
    _undoStack.add(entry);
    notifyListeners();
  }

  /// Reverses the most recent step.
  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    final KBarHistoryEntry entry = _undoStack.removeLast();
    _redoStack.add(entry);
    notifyListeners();
    await entry.undo();
  }

  /// Re-applies the most recently undone step.
  ///
  /// Re-performing the action records a fresh undo entry, so the step becomes
  /// undoable again.
  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    final KBarHistoryEntry entry = _redoStack.removeLast();
    notifyListeners();
    await entry.redo();
  }

  /// Empties both stacks.
  void clear() {
    if (_undoStack.isEmpty && _redoStack.isEmpty) return;
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }
}
