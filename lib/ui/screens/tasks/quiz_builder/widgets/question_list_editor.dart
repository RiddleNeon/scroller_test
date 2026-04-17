import 'package:flutter/material.dart';

import '../quiz_models.dart';
import 'cappuccino_section_card.dart';

class QuestionListEditor extends StatelessWidget {
  const QuestionListEditor({
    required this.versionTitle,
    required this.passMinScore,
    required this.questions,
    required this.onVersionTitleChanged,
    required this.onPassMinScoreChanged,
    required this.onQuestionsChanged,
    required this.busy,
    super.key,
  });

  final String versionTitle;
  final double passMinScore;
  final List<QuizQuestionDraft> questions;
  final ValueChanged<String> onVersionTitleChanged;
  final ValueChanged<double> onPassMinScoreChanged;
  final ValueChanged<List<QuizQuestionDraft>> onQuestionsChanged;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final maxScore = questions.fold<double>(0, (sum, q) => sum + q.points);

    return CappuccinoSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quiz Builder', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 260,
                child: TextFormField(
                  initialValue: versionTitle,
                  decoration: const InputDecoration(labelText: 'Version title'),
                  onChanged: onVersionTitleChanged,
                ),
              ),
              SizedBox(
                width: 160,
                child: TextFormField(
                  initialValue: passMinScore.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Pass min_score (max ${maxScore.toStringAsFixed(2)})'),
                  onChanged: (value) {
                    onPassMinScoreChanged(double.tryParse(value) ?? passMinScore);
                  },
                ),
              ),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final created = await showDialog<QuizQuestionDraft>(
                          context: context,
                          builder: (_) => const _QuestionDialog(),
                        );
                        if (created == null) return;
                        onQuestionsChanged(<QuizQuestionDraft>[...questions, created]);
                      },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add question'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (questions.isEmpty)
            const Text('No questions added yet. Use the button above to add your first question.'),
          if (questions.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final question = questions[index];
                return _QuestionTile(
                  index: index,
                  question: question,
                  onMoveUp: index == 0
                      ? null
                      : () {
                          final list = <QuizQuestionDraft>[...questions];
                          final swap = list[index - 1];
                          list[index - 1] = list[index];
                          list[index] = swap;
                          onQuestionsChanged(list);
                        },
                  onMoveDown: index == questions.length - 1
                      ? null
                      : () {
                          final list = <QuizQuestionDraft>[...questions];
                          final swap = list[index + 1];
                          list[index + 1] = list[index];
                          list[index] = swap;
                          onQuestionsChanged(list);
                        },
                  onDelete: () {
                    final list = <QuizQuestionDraft>[...questions]..removeAt(index);
                    onQuestionsChanged(list);
                  },
                  onEdit: () async {
                    final edited = await showDialog<QuizQuestionDraft>(
                      context: context,
                      builder: (_) => _QuestionDialog(initial: question),
                    );
                    if (edited == null) return;
                    final list = <QuizQuestionDraft>[...questions];
                    list[index] = edited;
                    onQuestionsChanged(list);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({
    required this.index,
    required this.question,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final QuizQuestionDraft question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${index + 1}. ${question.title}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(onPressed: onMoveUp, icon: const Icon(Icons.keyboard_arrow_up)),
              IconButton(onPressed: onMoveDown, icon: const Icon(Icons.keyboard_arrow_down)),
              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
            ],
          ),
          Text(_typeLabel(question.type)),
          const SizedBox(height: 4),
          Text('Points: ${question.points.toStringAsFixed(2)} | Hard-Fail: ${question.hardFail ? 'yes' : 'no'}'),
          if (question.options.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Options: ${question.options.join(', ')}'),
          ],
          const SizedBox(height: 4),
          Text('Correct Answer: ${question.correctAnswers.join(', ')}'),
        ],
      ),
    );
  }

  static String _typeLabel(QuizQuestionType type) {
    switch (type) {
      case QuizQuestionType.singleChoice:
        return 'Single Choice';
      case QuizQuestionType.multiChoice:
        return 'Multiple Choice';
      case QuizQuestionType.text:
        return 'Text';
      case QuizQuestionType.number:
        return 'Number';
    }
  }
}

class _QuestionDialog extends StatefulWidget {
  const _QuestionDialog({this.initial});

  final QuizQuestionDraft? initial;

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  late QuizQuestionType _type;
  late TextEditingController _titleController;
  late TextEditingController _pointsController;
  late TextEditingController _optionsController;
  late TextEditingController _correctController;
  late TextEditingController _placeholderController;
  bool _hardFail = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _type = initial?.type ?? QuizQuestionType.singleChoice;
    _titleController = TextEditingController(text: initial?.title ?? 'New Question');
    _pointsController = TextEditingController(text: (initial?.points ?? 1).toString());
    _optionsController = TextEditingController(text: initial?.options.join(', ') ?? '');
    _correctController = TextEditingController(text: initial?.correctAnswers.join(', ') ?? '');
    _placeholderController = TextEditingController(text: initial?.placeholder ?? '');
    _hardFail = initial?.hardFail ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pointsController.dispose();
    _optionsController.dispose();
    _correctController.dispose();
    _placeholderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add Question' : 'Edit Question'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<QuizQuestionType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Question Type'),
                items: QuizQuestionType.values
                    .map(
                      (type) => DropdownMenuItem<QuizQuestionType>(
                        value: type,
                        child: Text(_QuestionTile._typeLabel(type)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (type) {
                  if (type == null) return;
                  setState(() => _type = type);
                },
              ),
              const SizedBox(height: 10),
              TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Question Title')),
              const SizedBox(height: 10),
              TextField(
                controller: _pointsController,
                decoration: const InputDecoration(labelText: 'points'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              if (_type == QuizQuestionType.singleChoice || _type == QuizQuestionType.multiChoice)
                TextField(
                  controller: _optionsController,
                  decoration: const InputDecoration(labelText: 'Options (CSV)'),
                ),
              if (_type == QuizQuestionType.text || _type == QuizQuestionType.number)
                TextField(
                  controller: _placeholderController,
                  decoration: const InputDecoration(labelText: 'Placeholder (optional)'),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _correctController,
                decoration: InputDecoration(
                  labelText: _type == QuizQuestionType.multiChoice ? 'Correct answers (CSV)' : 'correct answer',
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hard Fail on wrong answer'),
                value: _hardFail,
                onChanged: (value) => setState(() => _hardFail = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final answers = _correctController.text
                .split(',')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList(growable: false);

            final options = _optionsController.text
                .split(',')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList(growable: false);

            final id = widget.initial?.id ?? 'q_${DateTime.now().millisecondsSinceEpoch}';
            Navigator.of(context).pop(
              QuizQuestionDraft(
                id: id,
                type: _type,
                title: _titleController.text.trim().isEmpty ? 'Question' : _titleController.text.trim(),
                points: double.tryParse(_pointsController.text.trim()) ?? 1,
                options: options,
                correctAnswers: answers,
                placeholder: _placeholderController.text.trim().isEmpty ? null : _placeholderController.text.trim(),
                hardFail: _hardFail,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

