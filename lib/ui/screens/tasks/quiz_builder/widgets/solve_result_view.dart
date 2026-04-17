import 'dart:convert';

import 'package:flutter/material.dart';

import 'cappuccino_section_card.dart';

class SolveResultView extends StatelessWidget {
  const SolveResultView({required this.statusMessage, required this.solveResult, super.key});

  final String statusMessage;
  final Map<String, dynamic>? solveResult;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pretty = solveResult == null ? '' : const JsonEncoder.withIndent('  ').convert(solveResult);

    return CappuccinoSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(statusMessage, style: TextStyle(color: cs.onSurfaceVariant)),
          if (solveResult != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: SelectableText(
                pretty,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

