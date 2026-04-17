import 'package:flutter/material.dart';
import 'package:wurp/logic/repositories/task_repository.dart';
import 'package:wurp/ui/screens/tasks/quiz_builder/quiz_dsl_mapper.dart';
import 'package:wurp/ui/screens/tasks/quiz_builder/quiz_models.dart';
import 'package:wurp/ui/screens/tasks/quiz_builder/widgets/question_list_editor.dart';
import 'package:wurp/ui/screens/tasks/quiz_builder/widgets/quiz_preview_player.dart';
import 'package:wurp/ui/screens/tasks/quiz_builder/widgets/solve_result_view.dart';
import 'package:wurp/ui/screens/tasks/quiz_builder/widgets/task_metadata_form.dart';
import 'package:wurp/ui/screens/tasks/quiz_builder/widgets/version_actions_bar.dart';

class TaskQuizWorkspaceScreen extends StatefulWidget {
  const TaskQuizWorkspaceScreen({super.key});

  @override
  State<TaskQuizWorkspaceScreen> createState() => _TaskQuizWorkspaceScreenState();
}

class _TaskQuizWorkspaceScreenState extends State<TaskQuizWorkspaceScreen> {
  QuizTaskMetaDraft _meta = QuizTaskMetaDraft();
  QuizVersionDraft _draft = QuizVersionDraft(
    title: 'Draft v1',
    passMinScore: 1,
    questions: <QuizQuestionDraft>[
      QuizQuestionDraft(
        id: 'q_1',
        type: QuizQuestionType.singleChoice,
        title: 'what is 2 + 2?',
        points: 1,
        options: const <String>['3', '4', '5'],
        correctAnswers: const <String>['4'],
      ),
    ],
  );

  List<Map<String, dynamic>> _myTasks = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _versions = <Map<String, dynamic>>[];

  int? _selectedTaskId;
  int? _selectedVersionId;

  bool _busy = false;
  String _statusMessage = 'Ready';
  Map<String, dynamic>? _solveResult;

  @override
  void initState() {
    super.initState();
    _loadMyTasks();
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
      _selectedTaskId ??= _myTasks.isNotEmpty ? _myTasks.first['id'] as int : null;

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

    if (_selectedVersionId != null) {
      final selected = _versions.firstWhere(
        (row) => row['id'] == _selectedVersionId,
        orElse: () => <String, dynamic>{},
      );
      if (selected.isNotEmpty) {
        _draft = QuizDslMapper.fromVersionRow(selected);
      }
    }
  }

  Future<void> _createTask() async {
    await _runBusy(() async {
      final created = await taskRepository.createTaskShell(
        type: _meta.taskType.trim().isEmpty ? 'quiz_dsl' : _meta.taskType.trim(),
        title: _meta.taskTitle.trim().isEmpty ? 'Untitled DSL Quiz' : _meta.taskTitle.trim(),
        subjects: _meta.subjects.isEmpty ? <String>['General'] : _meta.subjects,
        xpReward: _meta.xpReward,
        xpPunishment: _meta.xpPunishment,
      );

      _selectedTaskId = created['id'] as int;
      await _loadMyTasks();
    }, successMessage: 'Task created');
  }

  Future<void> _createDraft() async {
    final taskId = _selectedTaskId;
    if (taskId == null) throw StateError('Please select a task first!');

    await _runBusy(() async {
      final created = await taskRepository.createTaskDraftVersion(
        taskId: taskId,
        title: _draft.title.trim().isEmpty ? 'Draft' : _draft.title.trim(),
        ui: QuizDslMapper.toUiJson(_draft),
        logic: QuizDslMapper.toLogicJson(_draft),
      );
      _selectedVersionId = created['id'] as int;
      await _loadVersions(taskId);
    }, successMessage: 'Draft created');
  }

  Future<void> _saveDraft() async {
    final taskId = _selectedTaskId;
    final versionId = _selectedVersionId;
    if (taskId == null || versionId == null) {
      throw StateError('Please select a draft version to save first!');
    }

    await _runBusy(() async {
      await taskRepository.updateTaskDraftVersion(
        versionId: versionId,
        title: _draft.title.trim().isEmpty ? 'Draft' : _draft.title.trim(),
        ui: QuizDslMapper.toUiJson(_draft),
        logic: QuizDslMapper.toLogicJson(_draft),
      );
      await _loadVersions(taskId);
    }, successMessage: 'Draft saved');
  }

  Future<void> _cloneVersion() async {
    final taskId = _selectedTaskId;
    final versionId = _selectedVersionId;
    if (taskId == null || versionId == null) {
      throw StateError('Please select a version to clone first!');
    }

    await _runBusy(() async {
      final cloned = await taskRepository.cloneTaskVersion(
        taskId: taskId,
        sourceVersionId: versionId,
        newTitle: '${_draft.title.trim()} (copy)',
      );
      _selectedVersionId = cloned['id'] as int;
      await _loadVersions(taskId);
    }, successMessage: 'Version cloned');
  }

  Future<void> _publishVersion() async {
    final taskId = _selectedTaskId;
    final versionId = _selectedVersionId;
    if (taskId == null || versionId == null) {
      throw StateError('Please select a version to publish first!');
    }

    await _runBusy(() async {
      await taskRepository.publishTaskVersion(taskId: taskId, versionId: versionId, makeCurrent: true);
      await _loadVersions(taskId);
    }, successMessage: 'Version published');
  }

  Future<void> _solvePreview(Map<String, dynamic> rawAnswersByQuestion) async {
    final taskId = _selectedTaskId;
    if (taskId == null) {
      throw StateError('Please select a task first!');
    }

    await _runBusy(() async {
      if (_selectedVersionId == null) {
        final created = await taskRepository.createTaskDraftVersion(
          taskId: taskId,
          title: _draft.title.trim().isEmpty ? 'Auto Draft' : _draft.title.trim(),
          ui: QuizDslMapper.toUiJson(_draft),
          logic: QuizDslMapper.toLogicJson(_draft),
        );
        _selectedVersionId = created['id'] as int;
        await _loadVersions(taskId);
      }

      final versionId = _selectedVersionId;
      if (versionId == null) {
        throw StateError('No version available');
      }

      final answerPayload = QuizDslMapper.buildAnswerPayload(rawAnswersByQuestion);
      final result = await taskRepository.solveTaskDetailed(taskId, answerPayload, versionId: versionId);
      _solveResult = result;
    }, successMessage: 'Quiz solved');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Studio'),
        actions: [
          IconButton(
            tooltip: 'Show UI Schema in Console',
            onPressed: _busy
                ? null
                : () async {
                    await _runBusy(() async {
                      _solveResult = await taskRepository.fetchTaskUiSchemaV1();
                    }, successMessage: 'UI Schema loaded');
                  },
            icon: const Icon(Icons.schema),
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
              TaskMetadataForm(
                meta: _meta,
                onMetaChanged: (value) => setState(() => _meta = value),
                onCreateTask: _createTask,
                busy: _busy,
              ),
              const SizedBox(height: 12),
              VersionActionsBar(
                key: ValueKey('task_${_selectedTaskId}_version_${_selectedVersionId}_${_versions.length}'),
                myTasks: _myTasks,
                versions: _versions,
                selectedTaskId: _selectedTaskId,
                selectedVersionId: _selectedVersionId,
                onTaskSelected: (value) async {
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
                onVersionSelected: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedVersionId = value;
                    final selected = _versions.firstWhere(
                      (row) => row['id'] == value,
                      orElse: () => <String, dynamic>{},
                    );
                    if (selected.isNotEmpty) {
                      _draft = QuizDslMapper.fromVersionRow(selected);
                    }
                  });
                },
                onReload: _loadMyTasks,
                onCreateDraft: _createDraft,
                onSaveDraft: _saveDraft,
                onCloneVersion: _cloneVersion,
                onPublishVersion: _publishVersion,
                busy: _busy,
              ),
              const SizedBox(height: 12),
              QuestionListEditor(
                key: ValueKey('builder_${_selectedVersionId ?? 'new'}'),
                versionTitle: _draft.title,
                passMinScore: _draft.passMinScore,
                questions: _draft.questions,
                onVersionTitleChanged: (value) => setState(() {
                  _draft = _draft.copyWith(title: value);
                }),
                onPassMinScoreChanged: (value) => setState(() {
                  _draft = _draft.copyWith(passMinScore: value);
                }),
                onQuestionsChanged: (value) => setState(() {
                  _draft = _draft.copyWith(questions: value);
                  if (_draft.passMinScore > _draft.maxScore) {
                    _draft = _draft.copyWith(passMinScore: _draft.maxScore);
                  }
                }),
                busy: _busy,
              ),
              const SizedBox(height: 12),
              QuizPreviewPlayer(
                questions: _draft.questions,
                onSubmit: _solvePreview,
                busy: _busy,
              ),
              const SizedBox(height: 12),
              SolveResultView(statusMessage: _statusMessage, solveResult: _solveResult),
            ],
          ),
        ),
      ),
    );
  }
}

