//test app for the quest screen

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lumox/logic/repositories/quest_repository.dart';
import 'package:lumox/logic/quests/quest.dart';
import 'package:lumox/logic/quests/quest_system.dart';
import 'package:lumox/tools/quest_generator.dart';
import 'package:lumox/ui/screens/quests/core/pan.dart';
import 'package:lumox/ui/screens/quests/version_management/change_screen.dart';

class QuestScreen extends StatefulWidget {
  final String subject;
  final List<int> focusQuestIds;
  final bool zoomOutIfNeeded;

  const QuestScreen({
    super.key,
    required this.subject,
    this.focusQuestIds = const [],
    this.zoomOutIfNeeded = true,
  });

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  final GlobalKey<PanWidgetState> _panKey = GlobalKey<PanWidgetState>();
  bool debugMode = false;
  bool hasPendingChanges = false;
  bool isSubjectMenuOpen = false;
  final Set<String> expandedSubjectGroups = {};
  final Set<String> locallyCreatedSubjects = {};
  late Future<List<String>> subjectFuture;

  @override
  initState() {
    super.initState();
    print("Initializing TestQuestScreen with subject: ${widget.subject}");
    questSystemFuture = loadQuestSystem();
    subjectFuture = questRepo.fetchQuestSubjects();
  }

  Future<QuestSystem> loadQuestSystem() async {
    QuestSystem questSystem = QuestSystem();
    print("-- Loading quests for subject: ${widget.subject}");
    await questSystem.loadFromServer(widget.subject);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (!mounted) return;
      setState(() {
        final focusQuests = widget.focusQuestIds
            .map((id) => questSystem.maybeGetQuestById(id))
            .whereType<Quest>()
            .toList();

        if (focusQuests.isEmpty) {
          _panKey.currentState?.centerOnAllQuests(context.size?.width ?? 1000, context.size?.height ?? 1000);
          return;
        }

        final panState = _panKey.currentState;
        if (panState == null) return;
        (panState as dynamic).focusOnQuests(
          focusQuests,
          context.size?.width ?? 1000,
          context.size?.height ?? 1000,
          zoomOutIfNeeded: widget.zoomOutIfNeeded,
        );
      });
    });

    questSystem.changeManager.addListener(() {
      if (!mounted) return;
      if (questSystem.changeManager.hasPendingChanges != hasPendingChanges) {
        setState(() {
          hasPendingChanges = questSystem.changeManager.hasPendingChanges;
        });
      }
    });
    return questSystem;
  }

  late Future<QuestSystem> questSystemFuture;

  @override
  void didUpdateWidget(covariant QuestScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subject != widget.subject) {
      questSystemFuture = loadQuestSystem();
      setState(() {});
    }
  }

  Future<void> _showCreateSubjectDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create subject'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. General/Test'),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Create')),
        ],
      ),
    );

    final raw = result?.trim() ?? '';
    if (raw.isEmpty) return;

    setState(() {
      locallyCreatedSubjects.add(raw);
      isSubjectMenuOpen = false;
    });

    final uri = Uri(path: '/quests', queryParameters: {'subject': raw});
    if (!mounted) return;
    context.go(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: questSystemFuture,
      builder: (context, asyncSnapshot) {
        final loaded = asyncSnapshot.hasData;
        final questSystem = asyncSnapshot.data;
        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => setState(() => isSubjectMenuOpen = !isSubjectMenuOpen),
              tooltip: 'Subjects',
            ),
            title: InkWell(
              onTap: () {
                debugMode = !debugMode;
                _panKey.currentState?.debugMode = debugMode;
                setState(() {});
              },
              child: const Text('Quest Screen'),
            ),
            centerTitle: true,
          ),
          body: Stack(
            children: [
              loaded
                  ? SizedBox.expand(
                      child: PanWidget(key: _panKey, questSystem: questSystem!),
                    )
                  : const Center(child: CircularProgressIndicator()),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !isSubjectMenuOpen,
                  child: AnimatedOpacity(
                    opacity: isSubjectMenuOpen ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: GestureDetector(
                      onTap: () => setState(() => isSubjectMenuOpen = false),
                      child: Container(color: Colors.black.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              ),
              _SubjectMenu(
                isOpen: isSubjectMenuOpen,
                currentSubject: widget.subject,
                subjectFuture: subjectFuture,
                expandedGroups: expandedSubjectGroups,
                colorScheme: colorScheme,
                createdSubjects: locallyCreatedSubjects,
                onToggleOpen: () => setState(() => isSubjectMenuOpen = !isSubjectMenuOpen),
                onCreateSubject: _showCreateSubjectDialog,
                onToggleGroup: (group, expanded) {
                  setState(() {
                    if (expanded) {
                      expandedSubjectGroups.add(group);
                    } else {
                      expandedSubjectGroups.remove(group);
                    }
                  });
                },
                onSelectSubject: (subject) {
                  if (subject == widget.subject) {
                    setState(() => isSubjectMenuOpen = false);
                    return;
                  }
                  setState(() => isSubjectMenuOpen = false);
                  final uri = Uri(path: '/quests', queryParameters: {'subject': subject});
                  context.go(uri.toString());
                },
              ),
            ],
          ),
          floatingActionButton: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedSlide(
                offset: debugMode && loaded ? Offset.zero : const Offset(0, 2),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCirc,
                child: FloatingActionButton(
                  heroTag: null,
                  clipBehavior: Clip.none,
                  child: const Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.upload_file),
                    ],
                  ),
                  onPressed: () {
                    showDialog(
                      context: context, // shows a small screen for you to type in a path of a json file to import quests from, then calls the import function from quest_generator.dart with that path
                      builder: (context) => AlertDialog(
                        title: const Text("Import Quests from JSON"),
                        content: TextField(
                          decoration: const InputDecoration(hintText: "Enter file path"),
                          onSubmitted: (value) async {
                            Navigator.of(context).pop();
                            await importQuestsFromJson(value);
                          },
                        ),
                      ),
                    ); //show change screen
                  },
                ),
              ),
              AnimatedSlide(
                offset: debugMode && loaded ? Offset.zero : const Offset(0, 2),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCirc,
                child: FloatingActionButton(
                  heroTag: null,
                  clipBehavior: Clip.none,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.commit),
                      if (loaded)
                        Positioned(
                          top: -kFloatingActionButtonMargin * 1.5,
                          right: -kFloatingActionButtonMargin * 1.5,
                          child: AnimatedScale(
                            scale: questSystem!.changeManager.hasPendingChanges ? 1 : 0,
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeOutBack,
                            child: AnimatedSlide(
                              offset: questSystem.changeManager.hasPendingChanges ? Offset.zero : const Offset(0, 0.35),
                              duration: const Duration(milliseconds: 420),
                              curve: Curves.easeOutCubic,
                              child: const Icon(Icons.circle, color: Colors.red), //red dot
                            ),
                          ), //red dot to indicate changes
                        ),
                    ],
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => QuestChangeScreen(changeManager: questSystem!.changeManager),
                    ); //show change screen
                  },
                ),
              ),
              const SizedBox(width: 16), //space between buttons
              FloatingActionButton(
                heroTag: null,
                child: const Icon(Icons.filter_center_focus),
                onPressed: () {
                  _panKey.currentState?.centerOnAllQuests(context.size?.width ?? 100, context.size?.height ?? 100, autoZoom: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SubjectNode {
  _SubjectNode({required this.name, required this.path});

  final String name;
  final String path;
  final Map<String, _SubjectNode> children = {};
  bool isSelectable = false;
}

class _SubjectMenu extends StatelessWidget {
  const _SubjectMenu({
    required this.isOpen,
    required this.currentSubject,
    required this.subjectFuture,
    required this.expandedGroups,
    required this.colorScheme,
    required this.createdSubjects,
    required this.onToggleOpen,
    required this.onCreateSubject,
    required this.onToggleGroup,
    required this.onSelectSubject,
  });

  static const double menuWidth = 280;

  final bool isOpen;
  final String currentSubject;
  final Future<List<String>> subjectFuture;
  final Set<String> expandedGroups;
  final ColorScheme colorScheme;
  final Set<String> createdSubjects;
  final VoidCallback onToggleOpen;
  final VoidCallback onCreateSubject;
  final void Function(String group, bool expanded) onToggleGroup;
  final void Function(String subject) onSelectSubject;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      top: 0,
      bottom: 0,
      left: isOpen ? 0 : -menuWidth,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: IgnorePointer(
        ignoring: !isOpen,
        child: SizedBox(
          width: menuWidth,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 18, offset: const Offset(4, 0))],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Subjects',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          tooltip: 'Create subject',
                          onPressed: onCreateSubject,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: onToggleOpen,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<String>>(
                      future: subjectFuture,
                      builder: (context, snapshot) {
                        final subjects = <String>{...createdSubjects, ...?(snapshot.data ?? [])};
                        if (currentSubject.trim().isNotEmpty) subjects.add(currentSubject.trim());
                        final list = subjects.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                        final root = _buildSubjectTree(list);

                        return ListView(
                          padding: const EdgeInsets.only(bottom: 16),
                          children: _buildSubjectNodes(
                            context,
                            root,
                            0,
                            currentSubject,
                            expandedGroups,
                            colorScheme,
                            onToggleGroup,
                            onSelectSubject,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

_SubjectNode _buildSubjectTree(List<String> subjects) {
  final root = _SubjectNode(name: '', path: '');

  for (final subject in subjects) {
    final parts = subject.split('/').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) continue;

    var node = root;
    final pathParts = <String>[];

    for (final part in parts) {
      pathParts.add(part);
      node = node.children.putIfAbsent(part, () => _SubjectNode(name: part, path: pathParts.join('/')));
    }

    node.isSelectable = true;
  }

  return root;
}

List<Widget> _buildSubjectNodes(
  BuildContext context,
  _SubjectNode node,
  int depth,
  String currentSubject,
  Set<String> expandedGroups,
  ColorScheme colorScheme,
  void Function(String group, bool expanded) onToggleGroup,
  void Function(String subject) onSelectSubject,
) {
  final children = node.children.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return children.map((child) {
    final isSelected = child.path.toLowerCase() == currentSubject.toLowerCase();
    final hasChildren = child.children.isNotEmpty;
    final titleStyle = TextStyle(
      color: isSelected ? colorScheme.primary : colorScheme.onSurface,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
    );

    if (hasChildren) {
      return ExpansionTile(
        key: PageStorageKey<String>('subject:${child.path}'),
        initiallyExpanded: expandedGroups.contains(child.path),
        tilePadding: EdgeInsets.only(left: 12 + depth * 14.0, right: 12),
        childrenPadding: EdgeInsets.only(left: 8 + depth * 14.0, right: 12),
        onExpansionChanged: (expanded) => onToggleGroup(child.path, expanded),
        title: Row(
          children: [
            Expanded(child: Text(child.name, style: titleStyle)),
            if (child.isSelectable)
              TextButton(
                onPressed: () => onSelectSubject(child.path),
                child: const Text('Open'),
              ),
          ],
        ),
        children: _buildSubjectNodes(
          context,
          child,
          depth + 1,
          currentSubject,
          expandedGroups,
          colorScheme,
          onToggleGroup,
          onSelectSubject,
        ),
      );
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(left: 20 + depth * 14.0, right: 12),
      title: Text(child.name, style: titleStyle),
      onTap: () => onSelectSubject(child.path),
    );
  }).toList();
}
