import 'package:flutter/material.dart';
import 'package:wurp/logic/quests/quest.dart';

class QuestDetailScreen extends StatelessWidget {
  final Quest quest;
  final bool debugMode;
  final bool editMode;
  final void Function(Quest updatedQuest)? onDoneEditing;

  const QuestDetailScreen({super.key, required this.quest, required this.debugMode, required this.editMode, this.onDoneEditing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          _QuestSliverAppBar(quest: quest, colorScheme: colorScheme, debugMode: debugMode),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _StatusRow(quest: quest, colorScheme: colorScheme),
                const SizedBox(height: 24),
                _SectionCard(
                  colorScheme: colorScheme,
                  child: _DescriptionSection(quest: quest, colorScheme: colorScheme, editMode: editMode),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  colorScheme: colorScheme,
                  child: _DifficultySection(quest: quest, colorScheme: colorScheme, editMode: editMode),
                ),
                if (quest.prerequisites.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    colorScheme: colorScheme,
                    child: _PrerequisitesSection(quest: quest, colorScheme: colorScheme, debugMode: debugMode, editMode: editMode),
                  ),
                ],
                const SizedBox(height: 16),
                if (debugMode)
                  _SectionCard(
                    colorScheme: colorScheme,
                    child: _MetaSection(quest: quest, colorScheme: colorScheme, editMode: editMode),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestSliverAppBar extends StatelessWidget {
  final Quest quest;
  final ColorScheme colorScheme;
  final bool debugMode;

  const _QuestSliverAppBar({required this.quest, required this.colorScheme, required this.debugMode});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      stretch: true,
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
        titlePadding: const EdgeInsets.fromLTRB(60, 0, 20, 16),
        title: Text(
          quest.name,
          style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: 20, height: 1.2),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorScheme.primaryContainer, colorScheme.secondaryContainer],
                ),
              ),
            ),
            CustomPaint(painter: _GridPatternPainter(colorScheme.onPrimaryContainer.withValues(alpha: 0.06))),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, colorScheme.primaryContainer.withValues(alpha: 0.85)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 60,
              right: 16,
              child: _SubjectBadge(subject: quest.subject, colorScheme: colorScheme),
            ),
            if (debugMode)
              Positioned(
                top: 64,
                left: 20,
                child: Text(
                  '#${quest.id}',
                  style: TextStyle(color: colorScheme.onPrimaryContainer.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  final Color color;

  _GridPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPatternPainter old) => old.color != color;
}

class _SubjectBadge extends StatelessWidget {
  final String subject;
  final ColorScheme colorScheme;

  const _SubjectBadge({required this.subject, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Text(
        subject.toUpperCase(),
        style: TextStyle(color: colorScheme.onPrimary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final Quest quest;
  final ColorScheme colorScheme;

  const _StatusRow({required this.quest, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final isCompleted = quest.isCompleted;

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isCompleted ? colorScheme.tertiaryContainer : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isCompleted ? colorScheme.tertiary : colorScheme.outline.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: isCompleted ? colorScheme.tertiary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                isCompleted ? 'Done' : 'Open',
                style: TextStyle(
                  color: isCompleted ? colorScheme.onTertiaryContainer : colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        if (quest.prerequisites.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 15, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  '${quest.prerequisites.length} Prerequisites${quest.prerequisites.length > 1 ? 'en' : ''}',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final ColorScheme colorScheme;

  const _SectionCard({required this.child, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  final Quest quest;
  final ColorScheme colorScheme;
  final bool editMode;

  const _DescriptionSection({required this.quest, required this.colorScheme, required this.editMode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'Description', colorScheme: colorScheme),
          const SizedBox(height: 10),
          _buildText(quest.description, editMode, TextStyle(color: colorScheme.onSurface, fontSize: 15, height: 1.6)),
        ],
      ),
    );
  }
}

// ── Difficulty ─────────────────────────────────────────────────────────────────

class _DifficultySection extends StatelessWidget {
  final Quest quest;
  final ColorScheme colorScheme;
  final bool editMode;

  const _DifficultySection({required this.quest, required this.colorScheme, required this.editMode});

  String _difficultyLabel(double d) {
    if (d < 0.2) return 'Beginner';
    if (d < 0.4) return 'novice';
    if (d < 0.6) return 'Intermediate';
    if (d < 0.8) return 'Advanced';
    return 'Expert';
  }

  Color _difficultyColor(double d, ColorScheme cs) {
    if (d < 0.4) return cs.tertiary;
    if (d < 0.7) return cs.primary;
    return cs.error;
  }

  @override
  Widget build(BuildContext context) {
    final d = quest.difficulty.clamp(0.0, 1.0);
    final color = _difficultyColor(d, colorScheme);
    const segments = 10;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionLabel(label: 'Difficulty', colorScheme: colorScheme),
              ),
              Text(
                _difficultyLabel(d),
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              Text('${(d * 100).round()}%', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(segments, (i) {
              final filled = i < (d * segments).round();
              return Expanded(
                child: Container(
                  height: 8,
                  margin: EdgeInsets.only(right: i < segments - 1 ? 4 : 0),
                  decoration: BoxDecoration(color: filled ? color : colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PrerequisitesSection extends StatelessWidget {
  final Quest quest;
  final ColorScheme colorScheme;
  final bool debugMode;
  final bool editMode;

  const _PrerequisitesSection({required this.quest, required this.colorScheme, required this.debugMode, required this.editMode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'Requirements', colorScheme: colorScheme),
          const SizedBox(height: 12),
          ...quest.prerequisites.asMap().entries.map((entry) {
            final prereq = entry.value;
            final isLast = entry.key == quest.prerequisites.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: prereq.isCompleted ? colorScheme.tertiaryContainer : colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      prereq.isCompleted ? Icons.check_rounded : Icons.hourglass_empty_rounded,
                      size: 16,
                      color: prereq.isCompleted ? colorScheme.tertiary : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prereq.name,
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        Text(prereq.subject, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                      ],
                    ),
                  ),
                  if(debugMode) 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '#${prereq.id}',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MetaSection extends StatelessWidget {
  final Quest quest;
  final ColorScheme colorScheme;
  final bool editMode;
  const _MetaSection({required this.quest, required this.colorScheme, required this.editMode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'Details', colorScheme: colorScheme),
          const SizedBox(height: 14),
          _MetaGrid(
            items: [
              _MetaItem(icon: Icons.tag_rounded, label: 'Quest ID', value: '#${quest.id}'),
              _MetaItem(icon: Icons.place_outlined, label: 'Position', value: '(${quest.posX.toStringAsFixed(0)}, ${quest.posY.toStringAsFixed(0)})'),
              _MetaItem(icon: Icons.aspect_ratio_rounded, label: 'Size', value: '${quest.sizeX.toStringAsFixed(0)} × ${quest.sizeY.toStringAsFixed(0)}'),
              _MetaItem(icon: Icons.subject_rounded, label: 'Subject', value: quest.subject),
            ],
            colorScheme: colorScheme,
            editMode: editMode,
          ),
        ],
      ),
    );
  }
}

class _MetaGrid extends StatelessWidget {
  final List<_MetaItem> items;
  final ColorScheme colorScheme;
  final bool editMode;

  const _MetaGrid({required this.items, required this.colorScheme, required this.editMode});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.6,
      children: items.map((item) => _MetaCell(item: item, colorScheme: colorScheme, editMode: editMode,)).toList(),
    );
  }
}

class _MetaItem {
  final IconData icon;
  final String label;
  final String value;

  const _MetaItem({required this.icon, required this.label, required this.value});
}

class _MetaCell extends StatelessWidget {
  final _MetaItem item;
  final ColorScheme colorScheme;
  final bool editMode;

  const _MetaCell({required this.item, required this.colorScheme, required this.editMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(item.icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
                _buildText(
                  item.value,
                  editMode,
                  TextStyle(color: colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w700),
                  TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Label ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;

  const _SectionLabel({required this.label, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return _buildText(label.toUpperCase(), false, TextStyle(color: colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4));
  }
}


Widget _buildText(String text, bool editMode, TextStyle style, [TextOverflow? overflow]) {
  if (editMode) {
    return TextField(
      controller: TextEditingController(text: text),
      style: style,
      maxLines: null,
      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
    );
  } else {
    return Text(text, style: style, overflow: overflow,);
  }
}