import 'package:flutter/material.dart';
import 'package:wurp/logic/quests/quest_change_manager.dart';
import 'package:wurp/logic/quests/quest_connection.dart';
import 'package:wurp/logic/quests/quest_system.dart';

///a screen for editing a quest connection (type, xp requirement, etc.)
class QuestConnectionEditScreen extends StatelessWidget {
  final QuestConnection connection;
  final QuestSystem questSystem;

  const QuestConnectionEditScreen({super.key, required this.connection, required this.questSystem});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.6,
      widthFactor: 0.6,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTypeField("type:", connection.type, (value) {
              questSystem.changeManager.record(
                UpdateConnectionChange(
                  fromId: connection.fromQuestId,
                  toId: connection.toQuestId,
                  patch: QuestConnectionPatch(type: value),
                  reversePatch: QuestConnectionPatch(type: connection.type),
                ),
              );
              print("Updated connection type to: $value");
            }),
            const SizedBox(height: 16),
            _buildTypeField("xp requirements:", connection.xpRequirement.toString(), (value) {
              print("Trying to parse xp requirement: $value");
              double? parsedValue = double.tryParse(value);
              if (parsedValue == null) {
                // Show an error message if the input is not a valid number
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid number for XP requirement.")),
                );
                return;
              }
              
              questSystem.changeManager.record(
                UpdateConnectionChange(
                  fromId: connection.fromQuestId,
                  toId: connection.toQuestId,
                  patch: QuestConnectionPatch(xpRequirement: double.tryParse(value)),
                  reversePatch: QuestConnectionPatch(xpRequirement: connection.xpRequirement),
                ),
              );
              print("Updated connection XP requirement to: $parsedValue");
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeField(String label, String initialValue, void Function(String) onSubmitted) {
    return Row(
      mainAxisSize: .max,
      mainAxisAlignment: .spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(
          width: 264,
          height: 48,
          child: TextFormField(
            initialValue: initialValue,
            keyboardType: const .numberWithOptions(signed: false, decimal: true),
            decoration: InputDecoration(labelText: label),
            onFieldSubmitted: onSubmitted,
          ),
        ),
      ],
    );
  }
}
