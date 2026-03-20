import 'package:flutter/foundation.dart';
import 'package:wurp/logic/quests/quest.dart';
import 'package:wurp/logic/quests/quest_system.dart';
import 'package:wurp/logic/repositories/quest_repository.dart';


/// Tracks quest changes locally with full undo/redo support.
/// Changes are applied to [QuestSystem] immediately when recorded.
/// Call [push] to sync all pending changes to the server as a single "commit",
/// collapsing redundant operations (e.g. multiple moves of the same quest)
/// before sending.
class QuestChangeManager with ChangeNotifier {
  final QuestSystem questSystem;
  final QuestRepository repo;

  /// Changes that have been applied locally but not yet pushed to the server.
  final List<QuestChange> _pendingChanges = [];

  /// Stack of applied changes available for undo.
  final List<QuestChange> _undoStack = [];

  /// Stack of undone changes available for redo.
  final List<QuestChange> _redoStack = [];

  bool get hasPendingChanges => _pendingChanges.isNotEmpty;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  int get pendingCount => _pendingChanges.length;

  QuestChangeManager({required this.questSystem, required this.repo});


  /// Applies [change] locally and adds it to the pending queue.
  /// Clears the redo stack (new change invalidates undone history).
  void record(QuestChange change) {
    change.applyLocally(questSystem);
    _pendingChanges.add(change);
    _undoStack.add(change);
    _redoStack.clear();
    notifyListeners();
  }


  void undo() {
    if (!canUndo) return;
    final change = _undoStack.removeLast();
    change.undoLocally(questSystem);
    _pendingChanges.remove(change);
    _redoStack.add(change);
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    final change = _redoStack.removeLast();
    change.applyLocally(questSystem);
    _pendingChanges.add(change);
    _undoStack.add(change);
    notifyListeners();
  }


  /// Collapses and pushes all pending changes to the server.
  ///
  /// Pending list is cleared optimistically before the network calls begin.
  /// If a push fails the caller is responsible for re-queuing or error handling.
  Future<void> push() async {
    if (_pendingChanges.isEmpty) return;

    final batch = List<QuestChange>.from(_pendingChanges);
    _pendingChanges.clear();
    notifyListeners();

    final collapsed = _collapse(batch);
    for (final change in collapsed) {
      await change.push(repo);
    }
  }

  /// Collapses redundant changes using each change's [collapseKey]:
  /// - Multiple updates to the same quest → one update (last write wins,
  ///   but `before` is preserved from the first change for correct rollback).
  /// - Add + Delete for the same quest → no-op (never send to server).
  /// - Add/Remove connection followed by its inverse → no-op.
  List<QuestChange> _collapse(List<QuestChange> changes) {
    final Map<String, QuestChange> map = {};
    for (final c in changes) {
      final existing = map[c.collapseKey];
      if (existing == null) {
        map[c.collapseKey] = c;
      } else {
        final merged = existing.mergeWith(c);
        if (merged == null) {
          map.remove(c.collapseKey); // changes cancel each other out
        } else {
          map[c.collapseKey] = merged;
        }
      }
    }
    return map.values.toList();
  }


  /// Drops any pending changes that reference a quest which has since been
  /// deleted (e.g. after a remote sync overwrote local state).
  void dropStaleChanges() {
    _pendingChanges.removeWhere(
          (c) => c is _QuestTargetedChange && (questSystem.maybeGetQuestById(c.questId)?.isDeleted ?? true),
    );
    notifyListeners();
  }
}

// ── Base ───────────────────────────────────────────────────────────────────

abstract class QuestChange {
  final String updateMessage;
  const QuestChange({required this.updateMessage});

  /// Key used to detect collapsible duplicates (e.g. two moves of quest 7).
  String get collapseKey;

  /// Apply this change to the local [QuestSystem].
  void applyLocally(QuestSystem system);

  /// Revert this change in the local [QuestSystem].
  void undoLocally(QuestSystem system);

  /// Push this change to the remote server via [repo].
  Future<void> push(QuestRepository repo);

  /// Merge [this] (older) with [newer] (same [collapseKey]).
  /// Returns the merged change, or `null` if they cancel out.
  /// Default: newer replaces older entirely.
  QuestChange? mergeWith(QuestChange newer) => newer;
}

/// Mixin marker for changes that target a specific quest by ID.
/// Used by [QuestChangeManager.dropStaleChanges].
abstract class _QuestTargetedChange extends QuestChange {
  int get questId;
  const _QuestTargetedChange({required super.updateMessage});
}

// ── Quest changes ──────────────────────────────────────────────────────────

/// Records the creation of a new quest.
class AddQuestChange extends _QuestTargetedChange {
  final Quest quest;

  const AddQuestChange({
    required this.quest,
    super.updateMessage = 'added quest',
  });

  @override
  int get questId => quest.id;

  @override
  String get collapseKey => 'quest:${quest.id}';

  @override
  void applyLocally(QuestSystem s) => s.upsertQuest(quest);

  @override
  void undoLocally(QuestSystem s) => s.removeQuest(quest.id);

  @override
  Future<void> push(QuestRepository repo) => repo.addQuest(quest, updateMessage);

  @override
  QuestChange? mergeWith(QuestChange newer) {
    if (newer is DeleteQuestChange && newer.quest.id == quest.id) {
      // Quest was added and immediately deleted → nothing to push.
      return null;
    }
    if (newer is UpdateQuestChange && newer.after.id == quest.id) {
      // Collapse into a single add with the final state.
      return AddQuestChange(quest: newer.after, updateMessage: newer.updateMessage);
    }
    return newer;
  }
}

/// Records an edit to an existing quest, preserving the previous state
/// so the change can be properly undone.
class UpdateQuestChange extends _QuestTargetedChange {
  /// Snapshot of the quest before this change was applied.
  final Quest before;

  /// Snapshot of the quest after this change was applied.
  final Quest after;

  const UpdateQuestChange({
    required this.before,
    required this.after,
    super.updateMessage = 'updated quest',
  });

  @override
  int get questId => after.id;

  @override
  String get collapseKey => 'quest:${after.id}';

  @override
  void applyLocally(QuestSystem s) => s.upsertQuest(after);

  @override
  void undoLocally(QuestSystem s) => s.upsertQuest(before);

  @override
  Future<void> push(QuestRepository repo) =>
      repo.updateQuest(after, updateMessage);

  @override
  QuestChange? mergeWith(QuestChange newer) {
    if (newer is UpdateQuestChange) {
      return UpdateQuestChange(
        before: before,
        after: newer.after,
        updateMessage: newer.updateMessage,
      );
    }
    if (newer is DeleteQuestChange) return newer;
    return newer;
  }
}

class DeleteQuestChange extends _QuestTargetedChange {
  final Quest quest;

  const DeleteQuestChange({
    required this.quest,
    super.updateMessage = 'deleted quest',
  });

  @override
  int get questId => quest.id;

  @override
  String get collapseKey => 'quest:${quest.id}';

  @override
  void applyLocally(QuestSystem s) => s.removeQuest(quest.id);

  @override
  void undoLocally(QuestSystem s) => s.upsertQuest(quest);

  @override
  Future<void> push(QuestRepository repo) => repo.deleteQuest(quest);
}


class AddConnectionChange extends QuestChange {
  final int fromId;
  final int toId;

  const AddConnectionChange({
    required this.fromId,
    required this.toId,
    super.updateMessage = 'connection added',
  });

  @override
  String get collapseKey => 'conn:${fromId}_$toId';

  @override
  void applyLocally(QuestSystem s) => s.addConnection(fromId, toId);

  @override
  void undoLocally(QuestSystem s) => s.removeConnection(fromId, toId);

  @override
  Future<void> push(QuestRepository repo) => repo.addConnection(fromId, toId);

  @override
  QuestChange? mergeWith(QuestChange newer) {
    if (newer is RemoveConnectionChange &&
        newer.fromId == fromId &&
        newer.toId == toId) {
      return null;
    }
    return newer;
  }
}


late QuestChangeManager changeManager;

/// Records removing a prerequisite connection from→to.
class RemoveConnectionChange extends QuestChange {
  final int fromId;
  final int toId;

  const RemoveConnectionChange({
    required this.fromId,
    required this.toId,
    super.updateMessage = 'connection removed',
  });

  @override
  String get collapseKey => 'conn:${fromId}_$toId';

  @override
  void applyLocally(QuestSystem s) => s.removeConnection(fromId, toId);

  @override
  void undoLocally(QuestSystem s) => s.addConnection(fromId, toId);

  @override
  Future<void> push(QuestRepository repo) => repo.removeConnection(fromId, toId);

  @override
  QuestChange? mergeWith(QuestChange newer) {
    if (newer is AddConnectionChange &&
        newer.fromId == fromId &&
        newer.toId == toId) {
      return null;
    }
    return newer;
  }
}