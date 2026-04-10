import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wurp/ui/animations/slide_morph_transitions.dart';
import 'package:flutter/services.dart';
import 'package:wurp/logic/quests/quest.dart';
import 'package:wurp/logic/quests/quest_change_manager.dart';
import 'package:wurp/logic/quests/quest_system.dart';
import 'package:wurp/logic/repositories/quest_repository.dart';

class QuestDebugPanel extends StatefulWidget {
  final QuestSystem questSystem;
  final QuestChangeManager changeManager;

  const QuestDebugPanel({super.key, required this.onChanged, this.onFocusQuest, required this.questSystem, required this.changeManager});

  final VoidCallback onChanged;
  final void Function(Quest quest)? onFocusQuest;

  @override
  State<QuestDebugPanel> createState() => QuestDebugPanelState();
}

class QuestDebugPanelState extends State<QuestDebugPanel> with TickerProviderStateMixin {
  bool _isOpen = false;
  late final AnimationController _slideCtrl;
  late final Animation<double> _slideAnim;

  bool get isOpen => _isOpen;

  QuestSystem get questSystem => widget.questSystem;

  QuestChangeManager get changeManager => widget.changeManager;

  String _searchQuery = '';
  int? _expandedQuestId;
  final _listScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _slideAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _listScrollCtrl.dispose();
    super.dispose();
  }

  void inspectQuest(int questId) {
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToQuest(questId);
      print("scrolling to quest $questId");
      setState(() => _expandedQuestId = questId);
    });
    if (!_isOpen) {
      setState(() => _isOpen = true);
      _slideCtrl.forward();
    }
  }

  void _scrollToQuest(int questId) {
    final quests = _filteredQuests;
    final index = quests.indexWhere((q) => q.id == questId);
    if (index < 0 || !_listScrollCtrl.hasClients) return;
    // Approximate header height per tile
    const headerH = 42.0;
    final target = (index * headerH).clamp(0.0, _listScrollCtrl.position.maxScrollExtent);
    _listScrollCtrl.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    _isOpen ? _slideCtrl.forward() : _slideCtrl.reverse();
  }

  void _deleteQuest(int id) {
    changeManager.record(DeleteQuestChange(quest: questSystem.getQuestById(id)));
    questSystem.removeQuest(id);
    if (_expandedQuestId == id) _expandedQuestId = null;
    setState(() {});
    print("Deleted quest $id");
    widget.onChanged();
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (_) => _CreateQuestDialog(
        onCreated: (quest) {
          questSystem.upsertQuest(quest);
          setState(() => _expandedQuestId = quest.id);
          widget.onChanged();
        }, changeManager: changeManager,
      ),
    );
  }

  List<Quest> get _filteredQuests {
    final q = _searchQuery.toLowerCase();
    return questSystem.quests
        .where((quest) => q.isEmpty || quest.name.toLowerCase().contains(q) || quest.id.toString().contains(q) || quest.subject.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: _toggle,
              child: AnimatedBuilder(
                animation: _slideAnim,
                builder: (_, _) => Container(
                  width: 28,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Color.lerp(const Color(0xFF1E2D3D), const Color(0xFF0D2235), _slideAnim.value),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                    border: Border.all(color: Colors.cyan.withValues(alpha: 0.3 + 0.25 * _slideAnim.value)),
                    boxShadow: [BoxShadow(color: Colors.cyan.withValues(alpha: 0.08 + 0.18 * _slideAnim.value), blurRadius: 12, spreadRadius: 1)],
                  ),
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: Text(
                        'DEBUG',
                        style: TextStyle(
                          color: Colors.cyan.withValues(alpha: 0.65 + 0.3 * _slideAnim.value),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          AnimatedBuilder(
            animation: _slideAnim,
            builder: (_, child) => ClipRect(
              child: Align(alignment: Alignment.centerRight, widthFactor: _slideAnim.value, child: child),
            ),
            child: Container(
              width: 340,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                border: Border(left: BorderSide(color: Colors.cyan.withValues(alpha: 0.3))),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(-4, 0))],
              ),
              child: Column(
                children: [
                  _PanelHeader(onAddQuest: _showCreateDialog, questSystem: questSystem),
                  _SearchBar(onChanged: (v) => setState(() => _searchQuery = v)),
                  Expanded(child: _buildQuestList()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestList() {
    final quests = _filteredQuests;
    if (quests.isEmpty) {
      return const Center(
        child: Text('No quests found', style: TextStyle(color: Colors.white38, fontSize: 12)),
      );
    }
    return ListView.builder(
      controller: _listScrollCtrl,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: quests.length,
      itemBuilder: (_, i) {
        final quest = quests[i];
        final isExpanded = _expandedQuestId == quest.id;
        return _QuestListTile(
          key: ValueKey(quest.id),
          initialQuest: quest,
          questSystem: questSystem,
          isExpanded: isExpanded,
          allQuests: questSystem.quests,
          onToggle: () => setState(() => _expandedQuestId = isExpanded ? null : quest.id),
          onDelete: () => _deleteQuest(quest.id),
          onFocus: widget.onFocusQuest != null ? () => widget.onFocusQuest!(quest) : null,
          onChanged: () {
            setState(() {});
            widget.onChanged();
          }, changeManager: changeManager,
        );
      },
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.onAddQuest, required this.questSystem});

  final QuestSystem questSystem;
  final VoidCallback onAddQuest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF152232),
        border: Border(bottom: BorderSide(color: Colors.cyan.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          const Icon(Icons.bug_report, color: Colors.cyan, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Quest Debug',
            style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
          ),
          const Spacer(),
          Text('${questSystem.quests.length} quests', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 8),
          _DebugIconButton(
            icon: Icons.download,
            tooltip: 'print json',
            color: Colors.orangeAccent,
            onTap: () {
              String? result = questSystem.toJson();
              if (result != null) Clipboard.setData(ClipboardData(text: result));
              print(result ?? "error generating json");
            },
          ),
          const SizedBox(width: 8),
          _DebugIconButton(icon: Icons.add_circle_outline, tooltip: 'New quest', color: Colors.greenAccent, onTap: onAddQuest),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Search by name, id, subject…',
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
          prefixIcon: const Icon(Icons.search, color: Colors.white30, size: 16),
          filled: true,
          fillColor: const Color(0xFF1A2B3C),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

class _QuestListTile extends StatefulWidget {
  const _QuestListTile({
    super.key,
    required this.initialQuest,
    required this.isExpanded,
    required this.allQuests,
    required this.onToggle,
    required this.onDelete,
    required this.onChanged,
    this.onFocus,
    required this.questSystem,
    required this.changeManager,
  });

  final Quest initialQuest;
  final bool isExpanded;
  final List<Quest> allQuests;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final VoidCallback? onFocus;

  final QuestSystem questSystem;
  final QuestChangeManager changeManager;

  @override
  State<_QuestListTile> createState() => _QuestListTileState();
}

enum _SaveState { idle, saved }

class _QuestListTileState extends State<_QuestListTile> with SingleTickerProviderStateMixin {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _posXCtrl;
  late final TextEditingController _posYCtrl;
  late final TextEditingController _sizeXCtrl;
  late final TextEditingController _sizeYCtrl;
  late Quest quest;

  QuestSystem get questSystem => widget.questSystem;

  QuestChangeManager get changeManager => widget.changeManager;

  _QuestListTileState();

  double? _difficulty;

  _SaveState _saveState = _SaveState.idle;
  Timer? _saveTimer;

  late final AnimationController _chevronCtrl;
  late final Animation<double> _chevronAnim;

  @override
  void initState() {
    super.initState();

    quest = widget.initialQuest;

    _nameCtrl = TextEditingController(text: quest.name);
    _descCtrl = TextEditingController(text: quest.description);
    _subjectCtrl = TextEditingController(text: quest.subject);
    _posXCtrl = TextEditingController(text: quest.posX.toStringAsFixed(1));
    _posYCtrl = TextEditingController(text: quest.posY.toStringAsFixed(1));
    _sizeXCtrl = TextEditingController(text: quest.sizeX.toStringAsFixed(1));
    _sizeYCtrl = TextEditingController(text: quest.sizeY.toStringAsFixed(1));

    _chevronCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), value: widget.isExpanded ? 1.0 : 0.0);
    _chevronAnim = CurvedAnimation(parent: _chevronCtrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(_QuestListTile old) {
    super.didUpdateWidget(old);
    widget.isExpanded ? _chevronCtrl.forward() : _chevronCtrl.reverse();
    if (!widget.isExpanded) {
      _posXCtrl.text = quest.posX.toStringAsFixed(1);
      _posYCtrl.text = quest.posY.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _chevronCtrl.dispose();
    for (final c in [_nameCtrl, _descCtrl, _subjectCtrl, _posXCtrl, _posYCtrl, _sizeXCtrl, _sizeYCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyChanges() {
    QuestPatch before = QuestPatch(
      name: quest.name,
      description: quest.description,
      subject: quest.subject,
      posX: quest.posX,
      posY: quest.posY,
      sizeX: quest.sizeX,
      sizeY: quest.sizeY,
      difficulty: quest.difficulty,
    );

    String? newName = _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim();
    String? newDesc = _descCtrl.text.trim() == quest.description.trim() ? null : _descCtrl.text.trim();
    String? newSubject = _subjectCtrl.text.trim() == quest.subject.trim() ? null : _subjectCtrl.text.trim();

    double? newPosX = double.tryParse(_posXCtrl.text);
    double? newPosY = double.tryParse(_posYCtrl.text);
    double? newSizeX = double.tryParse(_sizeXCtrl.text);
    double? newSizeY = double.tryParse(_sizeYCtrl.text);

    double? newDifficulty = _difficulty == quest.difficulty ? null : _difficulty;

    QuestPatch after = QuestPatch(
      name: newName,
      description: newDesc,
      subject: newSubject,
      posX: newPosX,
      posY: newPosY,
      sizeX: newSizeX,
      sizeY: newSizeY,
      difficulty: newDifficulty,
    );

    quest = after.applyTo(quest);

    changeManager.record(UpdateQuestChange(questId: quest.id, patch: after, reversePatch: before));

    setState(() => _saveState = _SaveState.saved);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saveState = _SaveState.idle);
    });

    widget.onChanged();
  }

  Color get _subjectColor {
    const palette = [Colors.cyan, Colors.purple, Colors.orange, Colors.green, Colors.pink, Colors.teal, Colors.amber];
    return palette[quest.subject.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: widget.onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isExpanded ? const Color(0xFF1A2F44) : Colors.transparent,
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _subjectColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _subjectColor.withValues(alpha: 0.5)),
                  ),
                  child: Center(
                    child: Text(
                      '#${quest.id}',
                      style: TextStyle(color: _subjectColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.name,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${quest.subject}  •  '
                        '${quest.posX.toStringAsFixed(0)}, ${quest.posY.toStringAsFixed(0)}  •  '
                        '${(quest.difficulty * 100).round()}%',
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                if (widget.onFocus != null)
                  _DebugIconButton(icon: Icons.my_location, tooltip: 'Focus camera', color: Colors.lightBlueAccent, onTap: widget.onFocus!, size: 15),
                _DebugIconButton(icon: Icons.delete_outline, tooltip: 'Delete quest', color: Colors.redAccent, onTap: () => _confirmDelete(context), size: 15),
                RotationTransition(
                  turns: Tween(begin: 0.0, end: 0.5).animate(_chevronAnim),
                  child: const Icon(Icons.keyboard_arrow_down, color: Colors.white30, size: 16),
                ),
              ],
            ),
          ),
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: widget.isExpanded ? _buildEditor() : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return Container(
      color: const Color(0xFF111E2B),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldRow(label: 'Name', controller: _nameCtrl),
          _FieldRow(label: 'Subject', controller: _subjectCtrl),
          _FieldRow(label: 'Description', controller: _descCtrl, maxLines: 3),
          const SizedBox(height: 8),
          const _SectionLabel('Position & Size'),
          Row(
            children: [
              Expanded(
                child: _FieldRow(label: 'posX', controller: _posXCtrl, numeric: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FieldRow(label: 'posY', controller: _posYCtrl, numeric: true),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _FieldRow(label: 'sizeX', controller: _sizeXCtrl, numeric: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FieldRow(label: 'sizeY', controller: _sizeYCtrl, numeric: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SectionLabel('Difficulty  ${((_difficulty ?? quest.difficulty) * 100).round()}%'),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.cyan,
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.cyan,
              overlayColor: Colors.cyan.withValues(alpha: 0.15),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(value: _difficulty ?? quest.difficulty, min: 0, max: 1, divisions: 20, onChanged: (v) => setState(() => _difficulty = v)),
          ),
          const SizedBox(height: 8),
          const _SectionLabel('Prerequisites'),
          _PrerequisiteEditor(quest: quest, allQuests: widget.allQuests, onChanged: widget.onChanged, questSystem: questSystem),
          const SizedBox(height: 12),
          _ApplyButton(saveState: _saveState, onPressed: _applyChanges),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF152232),
        title: Text('Delete "${quest.name}"?', style: const TextStyle(color: Colors.white, fontSize: 14)),
        content: Text('Quest #${quest.id} will be permanently removed.', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
              print("Deleted quest ${quest.id}");
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.saveState, required this.onPressed});

  final _SaveState saveState;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isSaved = saveState == _SaveState.saved;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isSaved ? Colors.greenAccent.withValues(alpha: 0.7) : Colors.cyan.withValues(alpha: 0.5)),
        color: isSaved ? Colors.greenAccent.withValues(alpha: 0.15) : Colors.cyan.withValues(alpha: 0.12),
      ),
      child: InkWell(
        onTap: isSaved ? null : onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => SlideMorphTransitions.switcher(
              child,
              anim,
              beginOffset: const Offset(0, 0.35),
              beginScale: 0.9,
            ),
            child: isSaved
                ? const Row(
                    key: ValueKey('saved'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
                      SizedBox(width: 6),
                      Text(
                        'Saved!',
                        style: TextStyle(fontSize: 12, color: Colors.greenAccent, fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('apply'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check, size: 14, color: Colors.cyan.withValues(alpha: 0.9)),
                      const SizedBox(width: 6),
                      Text('Apply Changes', style: TextStyle(fontSize: 12, color: Colors.cyan.withValues(alpha: 0.9))),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PrerequisiteEditor extends StatefulWidget {
  const _PrerequisiteEditor({required this.quest, required this.allQuests, required this.onChanged, required this.questSystem});

  final Quest quest;
  final List<Quest> allQuests;
  final VoidCallback onChanged;
  final QuestSystem questSystem;

  @override
  State<_PrerequisiteEditor> createState() => _PrerequisiteEditorState();
}

class _PrerequisiteEditorState extends State<_PrerequisiteEditor> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _showList = false;
  String _query = '';

  QuestSystem get questSystem => widget.questSystem;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _showList = true);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<Quest> get _availableFiltered {
    final q = _query.toLowerCase();
    return widget.allQuests
        .where(
          (quest) =>
              quest.id != quest.id &&
              !questSystem.prerequisiteIds(quest.id).contains(quest.id) &&
              (q.isEmpty || quest.name.toLowerCase().contains(q) || quest.id.toString().contains(q) || quest.subject.toLowerCase().contains(q)),
        )
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  void _add(Quest prereq) async {
    print("Adding prerequisite #${prereq.id} to quest #${widget.quest.id}");
    await questRepo.addConnection(widget.quest.id, prereq.id);
    if (!mounted) return;
    setState(() {
      _searchCtrl.clear();
      _query = '';
      _focusNode.unfocus();
      _showList = false;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final available = _availableFiltered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (questSystem.prerequisitesOf(widget.quest.id).isEmpty)
          const Text('None', style: TextStyle(color: Colors.white30, fontSize: 11))
        else
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: questSystem.prerequisitesOf(widget.quest.id).map((prereq) {
              return Chip(
                label: Text('#${prereq.id} ${prereq.name}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: const Color(0xFF1E3344),
                side: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
                deleteIcon: const Icon(Icons.close, size: 12, color: Colors.redAccent),
                onDeleted: () async {
                  await questRepo.removeConnection(widget.quest.id, prereq.id);
                  setState(() {});
                  widget.onChanged();
                },
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        const SizedBox(height: 6),

        TextField(
          controller: _searchCtrl,
          focusNode: _focusNode,
          style: const TextStyle(color: Colors.white, fontSize: 11),
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Search to add prerequisite…',
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
            prefixIcon: const Icon(Icons.add_link, color: Colors.white30, size: 14),
            filled: true,
            fillColor: const Color(0xFF1A2B3C),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.cyan.withValues(alpha: 0.5)),
            ),
          ),
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _showList
              ? available.isNotEmpty
                    ? Container(
                        margin: const EdgeInsets.only(top: 2),
                        constraints: const BoxConstraints(maxHeight: 160),
                        decoration: BoxDecoration(
                          color: const Color(0xFF152232),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.cyan.withValues(alpha: 0.2)),
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: available.length,
                          itemBuilder: (_, i) {
                            final q = available[i];
                            return InkWell(
                              onTap: () => _add(q),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(color: Colors.cyan.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                                      child: Text(
                                        '#${q.id}',
                                        style: const TextStyle(color: Colors.cyan, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        q.name,
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(q.subject, style: const TextStyle(color: Colors.white30, fontSize: 10)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('No matches', style: TextStyle(color: Colors.white30, fontSize: 11)),
                      )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _CreateQuestDialog extends StatefulWidget {
  const _CreateQuestDialog({required this.onCreated, required this.changeManager});

  final void Function(Quest) onCreated;
  
  final QuestChangeManager changeManager;

  @override
  State<_CreateQuestDialog> createState() => _CreateQuestDialogState();
}

class _CreateQuestDialogState extends State<_CreateQuestDialog> {
  final _nameCtrl = TextEditingController(text: 'New Quest');
  final _descCtrl = TextEditingController(text: '');
  final _subjectCtrl = TextEditingController(text: 'General');
  final _posXCtrl = TextEditingController(text: '200');
  final _posYCtrl = TextEditingController(text: '200');
  final _sizeXCtrl = TextEditingController(text: '200');
  final _sizeYCtrl = TextEditingController(text: '100');
  double _difficulty = 0.5;
  
  QuestChangeManager get changeManager => widget.changeManager;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _descCtrl, _subjectCtrl, _posXCtrl, _posYCtrl, _sizeXCtrl, _sizeYCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _create() {
    final quest = Quest(
      id: DateTime.now().millisecondsSinceEpoch,
      name: _nameCtrl.text.trim().isEmpty ? 'Quest ${DateTime.now().millisecondsSinceEpoch}' : _nameCtrl.text.trim(),
      description: _descCtrl.text,
      subject: _subjectCtrl.text.trim().isEmpty ? 'General' : _subjectCtrl.text.trim(),
      posX: double.tryParse(_posXCtrl.text) ?? 200,
      posY: double.tryParse(_posYCtrl.text) ?? 200,
      sizeX: double.tryParse(_sizeXCtrl.text) ?? 200,
      sizeY: double.tryParse(_sizeYCtrl.text) ?? 100,
      difficulty: _difficulty,
    );
    changeManager.record(AddQuestChange(quest: quest, updateMessage: 'created quest'));
    Navigator.pop(context);
    widget.onCreated(quest);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D1B2A),
      title: const Row(
        children: [
          Icon(Icons.add_circle, color: Colors.greenAccent, size: 18),
          SizedBox(width: 8),
          Text('New Quest', style: TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FieldRow(label: 'Name', controller: _nameCtrl),
              _FieldRow(label: 'Subject', controller: _subjectCtrl),
              _FieldRow(label: 'Description', controller: _descCtrl, maxLines: 3),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _FieldRow(label: 'posX', controller: _posXCtrl, numeric: true),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FieldRow(label: 'posY', controller: _posYCtrl, numeric: true),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _FieldRow(label: 'sizeX', controller: _sizeXCtrl, numeric: true),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FieldRow(label: 'sizeY', controller: _sizeYCtrl, numeric: true),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SectionLabel('Difficulty  ${(_difficulty * 100).round()}%'),
              SliderTheme(
                data: SliderTheme.of(
                  context,
                ).copyWith(activeTrackColor: Colors.cyan, inactiveTrackColor: Colors.white12, thumbColor: Colors.cyan, trackHeight: 3),
                child: Slider(value: _difficulty, min: 0, max: 1, divisions: 20, onChanged: (v) => setState(() => _difficulty = v)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: _create,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.withValues(alpha: 0.2), foregroundColor: Colors.greenAccent),
          child: const Text('Create', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.controller, this.maxLines = 1, this.numeric = false});

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 2),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: numeric ? TextInputType.number : TextInputType.text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1A2B3C),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.cyan.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(color: Colors.cyan.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }
}

class _DebugIconButton extends StatelessWidget {
  const _DebugIconButton({required this.icon, required this.tooltip, required this.color, required this.onTap, this.size = 17});

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: color, size: size),
        ),
      ),
    );
  }
}
