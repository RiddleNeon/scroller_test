import 'package:flutter/material.dart';

import 'cappuccino_section_card.dart';

class VersionActionsBar extends StatelessWidget {
  const VersionActionsBar({
    required this.myTasks,
    required this.versions,
    required this.selectedTaskId,
    required this.selectedVersionId,
    required this.onTaskSelected,
    required this.onVersionSelected,
    required this.onReload,
    required this.onCreateDraft,
    required this.onSaveDraft,
    required this.onCloneVersion,
    required this.onPublishVersion,
    required this.busy,
    super.key,
  });

  final List<Map<String, dynamic>> myTasks;
  final List<Map<String, dynamic>> versions;
  final int? selectedTaskId;
  final int? selectedVersionId;
  final ValueChanged<int?> onTaskSelected;
  final ValueChanged<int?> onVersionSelected;
  final VoidCallback onReload;
  final VoidCallback onCreateDraft;
  final VoidCallback onSaveDraft;
  final VoidCallback onCloneVersion;
  final VoidCallback onPublishVersion;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return CappuccinoSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedTaskId,
                  decoration: const InputDecoration(labelText: 'select task'),
                  items: myTasks
                      .map(
                        (task) => DropdownMenuItem<int>(
                          value: task['id'] as int,
                          child: Text('#${task['id']} - ${(task['title'] as String?) ?? 'Untitled'}'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: busy ? null : onTaskSelected,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Neu laden',
                onPressed: busy ? null : onReload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: selectedVersionId,
            decoration: const InputDecoration(labelText: 'select version'),
            items: versions
                .map(
                  (version) => DropdownMenuItem<int>(
                    value: version['id'] as int,
                    child: Text(
                      'v${version['version_no']} - ${version['status']} - ${(version['title'] as String?) ?? 'Draft'}',
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: busy ? null : onVersionSelected,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : onCreateDraft,
                icon: const Icon(Icons.note_add),
                label: const Text('create draft'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onSaveDraft,
                icon: const Icon(Icons.save),
                label: const Text('save draft'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onCloneVersion,
                icon: const Icon(Icons.copy),
                label: const Text('clone version'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : onPublishVersion,
                icon: const Icon(Icons.publish),
                label: const Text('publish'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

