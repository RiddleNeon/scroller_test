import 'package:flutter/material.dart';

import '../quiz_models.dart';
import 'cappuccino_section_card.dart';

class TaskMetadataForm extends StatelessWidget {
  const TaskMetadataForm({
    required this.meta,
    required this.onMetaChanged,
    required this.onCreateTask,
    required this.busy,
    super.key,
  });

  final QuizTaskMetaDraft meta;
  final ValueChanged<QuizTaskMetaDraft> onMetaChanged;
  final VoidCallback onCreateTask;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CappuccinoSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('create task', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 220,
                child: TextFormField(
                  initialValue: meta.taskTitle,
                  decoration: const InputDecoration(labelText: 'Title'),
                  onChanged: (value) {
                    final next = QuizTaskMetaDraft()
                      ..taskTitle = value
                      ..taskType = meta.taskType
                      ..subjects = List<String>.from(meta.subjects)
                      ..xpReward = meta.xpReward
                      ..xpPunishment = meta.xpPunishment;
                    onMetaChanged(next);
                  },
                ),
              ),
              SizedBox(
                width: 140,
                child: TextFormField(
                  initialValue: meta.taskType,
                  decoration: const InputDecoration(labelText: 'Typ'),
                  onChanged: (value) {
                    final next = QuizTaskMetaDraft()
                      ..taskTitle = meta.taskTitle
                      ..taskType = value
                      ..subjects = List<String>.from(meta.subjects)
                      ..xpReward = meta.xpReward
                      ..xpPunishment = meta.xpPunishment;
                    onMetaChanged(next);
                  },
                ),
              ),
              SizedBox(
                width: 250,
                child: TextFormField(
                  initialValue: meta.subjects.join(', '),
                  decoration: const InputDecoration(labelText: 'Subjects (CSV)'),
                  onChanged: (value) {
                    final next = QuizTaskMetaDraft()
                      ..taskTitle = meta.taskTitle
                      ..taskType = meta.taskType
                      ..subjects = value
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(growable: false)
                      ..xpReward = meta.xpReward
                      ..xpPunishment = meta.xpPunishment;
                    onMetaChanged(next);
                  },
                ),
              ),
              SizedBox(
                width: 120,
                child: TextFormField(
                  initialValue: meta.xpReward.toString(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'XP Reward'),
                  onChanged: (value) {
                    final next = QuizTaskMetaDraft()
                      ..taskTitle = meta.taskTitle
                      ..taskType = meta.taskType
                      ..subjects = List<String>.from(meta.subjects)
                      ..xpReward = double.tryParse(value) ?? meta.xpReward
                      ..xpPunishment = meta.xpPunishment;
                    onMetaChanged(next);
                  },
                ),
              ),
              SizedBox(
                width: 140,
                child: TextFormField(
                  initialValue: meta.xpPunishment.toString(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'XP Punishment'),
                  onChanged: (value) {
                    final next = QuizTaskMetaDraft()
                      ..taskTitle = meta.taskTitle
                      ..taskType = meta.taskType
                      ..subjects = List<String>.from(meta.subjects)
                      ..xpReward = meta.xpReward
                      ..xpPunishment = double.tryParse(value) ?? meta.xpPunishment;
                    onMetaChanged(next);
                  },
                ),
              ),
              FilledButton.icon(
                onPressed: busy ? null : onCreateTask,
                icon: const Icon(Icons.add),
                label: const Text('create task'),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

