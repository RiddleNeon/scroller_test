import 'package:flutter/material.dart';

import '../quiz_models.dart';
import 'cappuccino_section_card.dart';

class QuizPreviewPlayer extends StatefulWidget {
  const QuizPreviewPlayer({
    required this.questions,
    required this.onSubmit,
    required this.busy,
    super.key,
  });

  final List<QuizQuestionDraft> questions;
  final ValueChanged<Map<String, dynamic>> onSubmit;
  final bool busy;

  @override
  State<QuizPreviewPlayer> createState() => _QuizPreviewPlayerState();
}

class _QuizPreviewPlayerState extends State<QuizPreviewPlayer> {
  final Map<String, dynamic> _answers = <String, dynamic>{};

  @override
  void didUpdateWidget(covariant QuizPreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questions != widget.questions) {
      _answers.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CappuccinoSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quiz preview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (widget.questions.isEmpty)
            const Text('No questions to show'),
          if (widget.questions.isNotEmpty)
            ...widget.questions.map((q) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _QuestionInput(
                    question: q,
                    onChanged: (value) {
                      _answers[q.id] = value;
                    },
                  ),
                )),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: widget.busy ? null : () => widget.onSubmit(Map<String, dynamic>.from(_answers)),
            icon: const Icon(Icons.play_arrow),
            label: const Text('solve task (solve_task_v2)'),
          ),
        ],
      ),
    );
  }
}

class _QuestionInput extends StatefulWidget {
  const _QuestionInput({required this.question, required this.onChanged});

  final QuizQuestionDraft question;
  final ValueChanged<dynamic> onChanged;

  @override
  State<_QuestionInput> createState() => _QuestionInputState();
}

class _QuestionInputState extends State<_QuestionInput> {
  final TextEditingController _textController = TextEditingController();
  String? _singleSelection;
  final Set<String> _multiSelection = <String>{};

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;

    switch (q.type) {
      case QuizQuestionType.singleChoice:
        return _choiceSingle(q);
      case QuizQuestionType.multiChoice:
        return _choiceMulti(q);
      case QuizQuestionType.number:
      case QuizQuestionType.text:
        return _textLike(q);
    }
  }

  Widget _textLike(QuizQuestionDraft q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(q.title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        TextField(
          controller: _textController,
          keyboardType: q.type == QuizQuestionType.number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          decoration: InputDecoration(hintText: q.placeholder ?? 'Insert answer here'),
          onChanged: (value) {
            if (q.type == QuizQuestionType.number) {
              widget.onChanged(double.tryParse(value) ?? value);
            } else {
              widget.onChanged(value);
            }
          },
        ),
      ],
    );
  }

  Widget _choiceSingle(QuizQuestionDraft q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(q.title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: q.options
              .map(
                (option) => ChoiceChip(
                  label: Text(option),
                  selected: _singleSelection == option,
                  onSelected: (selected) {
                    setState(() => _singleSelection = selected ? option : null);
                    widget.onChanged(_singleSelection ?? '');
                  },
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _choiceMulti(QuizQuestionDraft q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(q.title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        ...q.options.map(
          (option) => CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(option),
            value: _multiSelection.contains(option),
            onChanged: (checked) {
              setState(() {
                if (checked == true) {
                  _multiSelection.add(option);
                } else {
                  _multiSelection.remove(option);
                }
              });
              widget.onChanged(_multiSelection.toList(growable: false));
            },
          ),
        ),
      ],
    );
  }
}

