import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:wurp/logic/repositories/task_repository.dart';

class TaskQuizEditorScreen extends StatefulWidget {
  const TaskQuizEditorScreen({super.key});

  @override
  State<TaskQuizEditorScreen> createState() => _TaskQuizEditorScreenState();
}

class _TaskQuizEditorScreenState extends State<TaskQuizEditorScreen> {
  final TextEditingController _taskTypeController = TextEditingController(text: 'quiz_dsl');
  final TextEditingController _taskTitleController = TextEditingController(text: 'Untitled DSL Quiz');
  final TextEditingController _subjectsController = TextEditingController(text: 'General');
  final TextEditingController _xpRewardController = TextEditingController(text: '0.1');
  final TextEditingController _xpPunishmentController = TextEditingController(text: '0');

  final TextEditingController _versionTitleController = TextEditingController(text: 'Draft v1');
  final TextEditingController _uiJsonController = TextEditingController(text: _defaultUiJson);
  final TextEditingController _logicJsonController = TextEditingController(text: _defaultLogicJson);
  final TextEditingController _answerJsonController = TextEditingController(text: _defaultAnswerJson);

  List<Map<String, dynamic>> _myTasks = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _versions = <Map<String, dynamic>>[];

  int? _selectedTaskId;
  int? _selectedVersionId;
  bool _busy = false;

  String _statusMessage = 'Ready';
  String _solveResult = '';

  @override
  void initState() {
    super.initState();
    _loadMyTasks();
  }

  @override
  void dispose() {
    _taskTypeController.dispose();
    _taskTitleController.dispose();
    _subjectsController.dispose();
    _xpRewardController.dispose();
    _xpPunishmentController.dispose();
    _versionTitleController.dispose();
    _uiJsonController.dispose();
    _logicJsonController.dispose();
    _answerJsonController.dispose();
    super.dispose();
  }

  Future<void> _runBusy(Future<void> Function() fn, {String? successMessage}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
      if (!mounted) return;
      setState(() => _statusMessage = successMessage ?? 'Done');
    } catch (e) {
      if (!mounted) return;
      print("Error during operation: $e");
      final message = 'Error: $e';
      setState(() => _statusMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadMyTasks() async {
    await _runBusy(() async {
      final tasks = await taskRepository.fetchMyTasks();
      _myTasks = tasks;
      if (_myTasks.isNotEmpty) {
        _selectedTaskId ??= _myTasks.first['id'] as int;
      } else {
        _selectedTaskId = null;
      }

      if (_selectedTaskId != null) {
        await _loadVersions(_selectedTaskId!);
      } else {
        _versions = <Map<String, dynamic>>[];
        _selectedVersionId = null;
      }
    }, successMessage: 'Tasks loaded');
  }

  Future<void> _loadVersions(int taskId) async {
    final versions = await taskRepository.fetchTaskVersions(taskId);
    _versions = versions;
    _selectedVersionId = versions.isNotEmpty ? versions.first['id'] as int : null;

    final selected = _versions.firstWhere(
      (v) => v['id'] == _selectedVersionId,
      orElse: () => <String, dynamic>{},
    );
    if (selected.isNotEmpty) {
      _versionTitleController.text = (selected['title'] as String?) ?? _versionTitleController.text;
      _uiJsonController.text = const JsonEncoder.withIndent('  ').convert(selected['ui']);
      _logicJsonController.text = const JsonEncoder.withIndent('  ').convert(selected['logic']);
    }
  }

  List<String> _parseSubjects() {
    return _subjectsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> _decodeObject(String raw, String fieldName) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw FormatException('$fieldName must be a JSON object');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _createTask() async {
    await _runBusy(() async {
      final created = await taskRepository.createTaskShell(
        type: _taskTypeController.text.trim().isEmpty ? 'quiz_dsl' : _taskTypeController.text.trim(),
        title: _taskTitleController.text.trim().isEmpty ? 'Untitled DSL Quiz' : _taskTitleController.text.trim(),
        subjects: _parseSubjects().isEmpty ? <String>['General'] : _parseSubjects(),
        xpReward: double.tryParse(_xpRewardController.text.trim()) ?? 0.1,
        xpPunishment: double.tryParse(_xpPunishmentController.text.trim()) ?? 0,
      );

      _selectedTaskId = created['id'] as int;
      await _loadMyTasks();
    }, successMessage: 'Task created');
  }

  Future<void> _createDraft() async {
    final taskId = _selectedTaskId;
    if (taskId == null) throw StateError('Select or create a task first');

    await _runBusy(() async {
      final ui = _decodeObject(_uiJsonController.text, 'UI JSON');
      final logic = _decodeObject(_logicJsonController.text, 'Logic JSON');

      final created = await taskRepository.createTaskDraftVersion(
        taskId: taskId,
        title: _versionTitleController.text.trim().isEmpty ? 'Draft' : _versionTitleController.text.trim(),
        ui: ui,
        logic: logic,
      );
      _selectedVersionId = created['id'] as int;
      await _loadVersions(taskId);
    }, successMessage: 'Draft created');
  }

  Future<void> _saveDraft() async {
    final versionId = _selectedVersionId;
    final taskId = _selectedTaskId;
    if (versionId == null || taskId == null) {
      throw StateError('Select a draft version first');
    }

    await _runBusy(() async {
      final ui = _decodeObject(_uiJsonController.text, 'UI JSON');
      final logic = _decodeObject(_logicJsonController.text, 'Logic JSON');

      await taskRepository.updateTaskDraftVersion(
        versionId: versionId,
        title: _versionTitleController.text.trim().isEmpty ? 'Draft' : _versionTitleController.text.trim(),
        ui: ui,
        logic: logic,
      );
      await _loadVersions(taskId);
    }, successMessage: 'Draft saved');
  }

  Future<void> _cloneVersion() async {
    final versionId = _selectedVersionId;
    final taskId = _selectedTaskId;
    if (versionId == null || taskId == null) {
      throw StateError('Select a version first');
    }

    await _runBusy(() async {
      final cloned = await taskRepository.cloneTaskVersion(
        taskId: taskId,
        sourceVersionId: versionId,
        newTitle: '${_versionTitleController.text.trim()} (copy)',
      );
      _selectedVersionId = cloned['id'] as int;
      await _loadVersions(taskId);
    }, successMessage: 'Version cloned');
  }

  Future<void> _publishVersion() async {
    final versionId = _selectedVersionId;
    final taskId = _selectedTaskId;
    if (versionId == null || taskId == null) {
      throw StateError('Select a version first');
    }

    await _runBusy(() async {
      await taskRepository.publishTaskVersion(taskId: taskId, versionId: versionId, makeCurrent: true);
      await _loadVersions(taskId);
    }, successMessage: 'Version published and set current');
  }

  Future<void> _solveTest() async {
    final taskId = _selectedTaskId;
    if (taskId == null) throw StateError('Select a task first');
    
    print("Running solve test with answer JSON: ${_answerJsonController.text}");

    await _runBusy(() async {
      // If no version is selected yet, create a draft from current editor content
      // and solve against that draft directly.
      if (_selectedVersionId == null) {
        final autoUi = _decodeObject(_uiJsonController.text, 'UI JSON');
        final autoLogic = _decodeObject(_logicJsonController.text, 'Logic JSON');
        final created = await taskRepository.createTaskDraftVersion(
          taskId: taskId,
          title: _versionTitleController.text.trim().isEmpty ? 'Auto Draft' : _versionTitleController.text.trim(),
          ui: autoUi,
          logic: autoLogic,
        );
        _selectedVersionId = created['id'] as int;
        await _loadVersions(taskId);
      }

      final versionId = _selectedVersionId;
      if (versionId == null) {
        throw StateError('No task version available. Create or select a version first.');
      }

      final answer = _decodeObject(_answerJsonController.text, 'Answer JSON');
      final result = await taskRepository.solveTaskDetailed(taskId, answer, versionId: versionId);
      _solveResult = const JsonEncoder.withIndent('  ').convert(result);
    }, successMessage: 'Solve test executed (using selected version)');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task DSL Quiz Editor'),
        actions: [
          IconButton(
            tooltip: 'Reload tasks',
            onPressed: _busy ? null : _loadMyTasks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: IgnorePointer(
        ignoring: _busy,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Task', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(controller: _taskTitleController, decoration: const InputDecoration(labelText: 'Task Title')), 
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(controller: _taskTypeController, decoration: const InputDecoration(labelText: 'Type')),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(controller: _subjectsController, decoration: const InputDecoration(labelText: 'Subjects (csv)')),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(controller: _xpRewardController, decoration: const InputDecoration(labelText: 'XP Reward')),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(controller: _xpPunishmentController, decoration: const InputDecoration(labelText: 'XP Punishment')),
                  ),
                  FilledButton.icon(
                    onPressed: _createTask,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Task'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _selectedTaskId,
                decoration: const InputDecoration(labelText: 'Select Task'),
                items: _myTasks
                    .map(
                      (task) => DropdownMenuItem<int>(
                        value: task['id'] as int,
                        child: Text('#${task['id']} - ${(task['title'] as String?) ?? 'Untitled'}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() {
                    _selectedTaskId = value;
                    _selectedVersionId = null;
                    _versions = <Map<String, dynamic>>[];
                  });
                  await _runBusy(() async {
                    await _loadVersions(value);
                  }, successMessage: 'Versions loaded');
                },
              ),
              const SizedBox(height: 20),
              Text('Versions', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _versions
                    .map(
                      (v) => ChoiceChip(
                        selected: _selectedVersionId == v['id'],
                        label: Text('v${v['version_no']} - ${v['status']}'),
                        onSelected: (selected) {
                          if (!selected) return;
                          setState(() {
                            _selectedVersionId = v['id'] as int;
                            _versionTitleController.text = (v['title'] as String?) ?? _versionTitleController.text;
                            _uiJsonController.text = const JsonEncoder.withIndent('  ').convert(v['ui']);
                            _logicJsonController.text = const JsonEncoder.withIndent('  ').convert(v['logic']);
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(onPressed: _createDraft, icon: const Icon(Icons.note_add), label: const Text('Create Draft')),
                  OutlinedButton.icon(onPressed: _saveDraft, icon: const Icon(Icons.save), label: const Text('Save Draft')),
                  OutlinedButton.icon(onPressed: _cloneVersion, icon: const Icon(Icons.copy), label: const Text('Clone Version')),
                  FilledButton.icon(onPressed: _publishVersion, icon: const Icon(Icons.publish), label: const Text('Publish Current')),
                ],
              ),
              const SizedBox(height: 14),
              TextField(controller: _versionTitleController, decoration: const InputDecoration(labelText: 'Version Title')),
              const SizedBox(height: 12),
              _LabeledJsonEditor(label: 'UI JSON', controller: _uiJsonController, minLines: 10),
              const SizedBox(height: 12),
              _LabeledJsonEditor(label: 'Logic JSON (DSL)', controller: _logicJsonController, minLines: 12),
              const SizedBox(height: 20),
              Text('Solve Tester', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _LabeledJsonEditor(label: 'Answer JSON', controller: _answerJsonController, minLines: 8),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(onPressed: _solveTest, icon: const Icon(Icons.play_arrow), label: const Text('Run solve_task')),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _runBusy(() async {
                        final schema = await taskRepository.fetchTaskUiSchemaV1();
                        _solveResult = const JsonEncoder.withIndent('  ').convert(schema);
                      }, successMessage: 'Loaded UI schema template');
                    },
                    icon: const Icon(Icons.schema),
                    label: const Text('Show UI Schema v1'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Status: $_statusMessage', style: TextStyle(color: cs.onSurfaceVariant)),
              if (_solveResult.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: SelectableText(
                    _solveResult,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledJsonEditor extends StatelessWidget {
  const _LabeledJsonEditor({required this.label, required this.controller, this.minLines = 8});

  final String label;
  final TextEditingController controller;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: null,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

const String _defaultUiJson = '''{
  "version": "1.0",
  "theme": {
    "primary": "#6750A4"
  },
  "screens": [
    {
      "id": "main",
      "animation": {
        "type": "fade",
        "duration_ms": 220
      },
      "elements": [
        {
          "id": "question_1",
          "type": "single_choice",
          "props": {
            "title": "What is 2 + 2?",
            "options": ["3", "4", "5"]
          },
          "bind": {
            "answer_path": "q1.selected"
          }
        }
      ]
    }
  ]
}''';

const String _defaultLogicJson = '''{
  "rules": [
    {
      "id": "q1_correct",
      "when": {
        "op": "eq",
        "left": {"source": "answers", "path": "q1.selected"},
        "right": {"const": "4"}
      },
      "then": {"add_score": 1, "max_score": 1}
    },
    {
      "id": "fast_bonus",
      "when": {
        "op": "lt",
        "left": {"source": "answers", "path": "meta.time_seconds"},
        "right": {"const": 20}
      },
      "then": {"add_score": 0.25}
    }
  ],
  "pass": {
    "min_score": 1
  }
}''';

const String _defaultAnswerJson = '''{
  "answers": {
    "q1": {"selected": "4"},
    "meta": {"time_seconds": 12}
  },
  "vars": {
    "attempt": {"seed": 1}
  }
}''';

