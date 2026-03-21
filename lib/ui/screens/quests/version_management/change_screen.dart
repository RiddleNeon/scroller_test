import 'dart:math';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:wurp/logic/quests/quest_change_manager.dart';

/// A screen that shows all locally recorded changes since the last push.
///
/// Pending changes are shown in a [ReorderableListView] so the user can
/// adjust the application order by dragging. Each change shows the time it
/// was recorded. Skipping a change undoes it locally via the sandwich pattern
/// in [QuestChangeManager.skipChange]. Conflicts are highlighted in red.
class QuestChangeScreen extends StatelessWidget {
  final QuestChangeManager changeManager;

  const QuestChangeScreen({super.key, required this.changeManager});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: changeManager,
      builder: (context, _) {
        final pending = changeManager.pendingChanges;
        final skipped = changeManager.skippedChanges;
        final undone = changeManager.redoChanges;

        final conflictedPending = changeManager.allConflictedPending;
        final conflictedSkipped = changeManager.allConflictedSkipped;
        final hasConflicts = conflictedPending.isNotEmpty || conflictedSkipped.isNotEmpty;

        final isEmpty = pending.isEmpty && skipped.isEmpty && undone.isEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text(pending.isEmpty ? 'No Pending Changes' : '${pending.length} Pending Change${pending.length == 1 ? '' : 's'}'),
            actions: [
              IconButton(tooltip: 'Undo last change', icon: const Icon(Icons.undo), onPressed: changeManager.canUndo ? changeManager.undo : null),
              IconButton(tooltip: 'Redo last undone change', icon: const Icon(Icons.redo), onPressed: changeManager.canRedo ? changeManager.redo : null),
            ],
          ),
          body: Column(
            children: [
              if (hasConflicts) _ConflictBanner(conflictCount: conflictedPending.length),

              Expanded(
                child: isEmpty
                    ? const _EmptyState()
                    : CustomScrollView(
                        slivers: [
                          if (pending.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: _SectionHeader(label: 'Pending', count: pending.length),
                            ),
                            SliverReorderableList(
                              itemCount: pending.length,
                              onReorder: changeManager.reorderPending,
                              itemBuilder: (context, index) {
                                final change = pending[index];
                                return ReorderableDragStartListener(
                                  key: ObjectKey(change),
                                  index: index,
                                  child: Material(
                                    child: _ChangeTile(
                                      change: change,
                                      timestamp: changeManager.recordedAt(change),
                                      state: conflictedPending.contains(change) ? _TileState.conflict : _TileState.active,
                                      conflictReason: conflictedPending.contains(change) ? _conflictReasonFor(change, changeManager.skippedChanges) : null,
                                      onToggle: () => changeManager.skipChange(change),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],

                          if (skipped.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: _SectionHeader(label: 'Skipped', count: skipped.length, subtitle: 'undone locally - not pushed'),
                            ),
                            SliverList.builder(
                              itemCount: skipped.length,
                              itemBuilder: (context, index) {
                                final change = skipped[index];
                                return _ChangeTile(
                                  key: ObjectKey(change),
                                  change: change,
                                  timestamp: changeManager.recordedAt(change),
                                  state: conflictedSkipped.contains(change) ? _TileState.conflictSkipped : _TileState.skipped,
                                  conflictReason: conflictedSkipped.contains(change) ? _conflictCauseFor(change, changeManager.conflictsOf(change)) : null,
                                  onToggle: () => changeManager.unskipChange(change),
                                );
                              },
                            ),
                          ],

                          if (undone.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: _SectionHeader(label: 'Undo', count: undone.length, subtitle: 'undo via ↺'),
                            ),
                            SliverList.builder(
                              itemCount: undone.length,
                              itemBuilder: (context, index) {
                                final change = undone[undone.length - 1 - index];
                                return _ChangeTile(
                                  key: ObjectKey(change),
                                  change: change,
                                  timestamp: changeManager.recordedAt(change),
                                  state: _TileState.undone,
                                  onToggle: null,
                                );
                              },
                            ),
                          ],
                          
                          const SliverToBoxAdapter(child: SizedBox(height: 80)),
                        ],
                      ),
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: hasConflicts ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error) : null,
                      icon: Transform.rotate(angle: pi / 2, child: const Icon(Icons.commit)),
                      label: Text(
                        hasConflicts
                            ? 'Resolve Conflicts First'
                            : pending.isNotEmpty
                            ? 'Push Changes to Server'
                            : 'Nothing to Push',
                      ),
                      onPressed: pending.isNotEmpty && !hasConflicts ? changeManager.push : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _conflictReasonFor(QuestChange change, List<QuestChange> skippedChanges) {
    for (final skipped in skippedChanges) {
      if (skipped is AddQuestChange) {
        final id = change.affectedQuestId;
        if (id != null && id == skipped.quest.id) {
          return 'Depends on "${skipped.updateMessage}", which was skipped.';
        }
      }
      if (skipped is AddConnectionChange && change is RemoveConnectionChange && change.fromId == skipped.fromId && change.toId == skipped.toId) {
        return 'Connection was skipped – Deletion not possible.';
      }
    }
    return 'dependency is missing through a skipped change.';
  }

  static String _conflictCauseFor(QuestChange skipped, List<QuestChange> conflicts) {
    if (conflicts.isEmpty) return '';
    final n = conflicts.length;
    final s = n == 1 ? '' : 's';
    if (skipped is AddQuestChange) {
      return '$n depending change$s reference this quest – please re-enable or skip the dependant change.';
    }
    if (skipped is AddConnectionChange) {
      return '$n Change$s depend on this connection.';
    }
    return '$n Conflict$s caused by this change.';
  }
}

enum _TileState { active, skipped, conflict, conflictSkipped, undone }

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final String? subtitle;

  const _SectionHeader({required this.label, required this.count, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, letterSpacing: 1.2, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                child: Text('$count', style: theme.textTheme.labelSmall),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  final int conflictCount;

  const _ConflictBanner({required this.conflictCount});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cs.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$conflictCount Change${conflictCount == 1 ? '' : 's'} '
              '${conflictCount == 1 ? 'has' : 'have'} Conflicts. '
              'Please resolve or skip the conflicting changes to proceed.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeTile extends StatelessWidget {
  final QuestChange change;
  final DateTime? timestamp;
  final _TileState state;
  final String? conflictReason;
  final VoidCallback? onToggle;

  const _ChangeTile({
    super.key,
    required this.change,
    required this.timestamp,
    required this.state,
    this.conflictReason,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isConflict = state == _TileState.conflict || state == _TileState.conflictSkipped;
    final isDimmed = state == _TileState.skipped || state == _TileState.undone;
    //final isSkippedVariant = state == _TileState.skipped || state == _TileState.conflictSkipped;

    final iconColor = isConflict
        ? cs.error
        : isDimmed
        ? cs.onSurface.withValues(alpha: 0.3)
        : cs.primary;

    final textColor = isConflict
        ? cs.error
        : isDimmed
        ? cs.onSurface.withValues(alpha: 0.4)
        : null;

    Widget? trailing = switch (state) {
      _TileState.undone => null,
      _TileState.active || _TileState.conflict => Tooltip(
        message: 'Skip (undo locally)',
        child: IconButton(
          icon: Icon(Icons.visibility_outlined, color: iconColor),
          onPressed: onToggle,
        ),
      ),
      _TileState.skipped || _TileState.conflictSkipped => Tooltip(
        message: isConflict ? 'Conflict! Unskip to see details' : 'Unskip (restore change)',
        child: IconButton(
          icon: Icon(Icons.visibility_off_outlined, color: isConflict ? cs.error : null),
          onPressed: onToggle,
        ),
      ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: isConflict ? cs.errorContainer.withValues(alpha: 0.3) : null,
      child: InkWell(
        onTap: () {
          print("change: ${change.updateMessage}, state: $state. change vals: ${change.toString()}");
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Transform.rotate(
                      angle: pi / 2,
                      child: Icon(Icons.commit, size: 16, color: iconColor),
                    ),
              title: Text(
                change.updateMessage,
                style: TextStyle(decoration: isDimmed ? TextDecoration.lineThrough : TextDecoration.none, decorationColor: textColor, color: textColor),
              ),
              subtitle: _buildSubtitle(theme, cs, isDimmed, textColor),
              trailing: trailing,
            ),
            if (isConflict && conflictReason != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(56, 0, 16, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 14, color: cs.error),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(conflictReason!, style: theme.textTheme.bodySmall?.copyWith(color: cs.error)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget? _buildSubtitle(ThemeData theme, ColorScheme cs, bool isDimmed, Color? textColor) {
    final parts = <String>[];

    if (timestamp != null) parts.add(_formatTimestamp(timestamp!));

    if (state == _TileState.undone) {
      parts.add('Undone – will not be pushed');
    }

    if (parts.isEmpty) return null;

    return Text(parts.join(' · '), style: theme.textTheme.bodySmall?.copyWith(color: textColor ?? cs.onSurfaceVariant));
  }

  static String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} Minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} Hours ago';

    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    if (dt.year == now.year) return '$day.$month.';
    return '$day.$month.${dt.year}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('Everything is up to date!', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('No pending changes', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
