import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:lumox/logic/dictionary/dictionary_entry.dart';

class DictionaryLinkifiedSelectableText extends StatefulWidget {
  final String text;
  final TextStyle baseStyle;
  final Color linkColor;
  final Map<String, DictionaryEntry> entriesByTitle;
  final void Function(DictionaryEntry entry) onDictionaryTap;
  final void Function(String route) onRouteTap;

  const DictionaryLinkifiedSelectableText({
    super.key,
    required this.text,
    required this.baseStyle,
    required this.linkColor,
    required this.entriesByTitle,
    required this.onDictionaryTap,
    required this.onRouteTap,
  });

  @override
  State<DictionaryLinkifiedSelectableText> createState() => _DictionaryLinkifiedSelectableTextState();
}

class _DictionaryLinkifiedSelectableTextState extends State<DictionaryLinkifiedSelectableText> {
  final List<TapGestureRecognizer> _recognizers = [];
  List<InlineSpan> _spans = const [];

  @override
  void initState() {
    super.initState();
    _rebuildSpans();
  }

  @override
  void didUpdateWidget(covariant DictionaryLinkifiedSelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.baseStyle != widget.baseStyle || oldWidget.linkColor != widget.linkColor || oldWidget.entriesByTitle != widget.entriesByTitle) {
      _rebuildSpans();
    }
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  void _rebuildSpans() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final matches = _findMatches(widget.text, widget.entriesByTitle);
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start), style: widget.baseStyle));
      }

      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (match.entry != null) {
            widget.onDictionaryTap(match.entry!);
          } else if (match.route != null) {
            widget.onRouteTap(match.route!);
          }
        };
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: widget.text.substring(match.start, match.end),
          style: widget.baseStyle.copyWith(
            color: widget.linkColor,
            decoration: TextDecoration.underline,
            decorationColor: widget.linkColor,
          ),
          recognizer: recognizer,
        ),
      );
      cursor = match.end;
    }

    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor), style: widget.baseStyle));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: '', style: widget.baseStyle));
    }

    setState(() => _spans = spans);
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(TextSpan(children: _spans), selectionColor: Theme.of(context).colorScheme.tertiary);
  }
}

class DictionaryMarkdownBody extends StatelessWidget {
  final String data;
  final List<DictionaryEntry> entries;
  final MarkdownStyleSheet? styleSheet;
  final void Function(DictionaryEntry entry) onTapEntry;
  final Color? linkColor;

  const DictionaryMarkdownBody({
    super.key,
    required this.data,
    required this.entries,
    required this.onTapEntry,
    this.styleSheet,
    this.linkColor,
  });

  @override
  Widget build(BuildContext context) {
    final entriesByTitle = <String, DictionaryEntry>{
      for (final entry in entries)
        if (entry.normalizedTitle.isNotEmpty) entry.normalizedTitle: entry,
    };

    if (entriesByTitle.isEmpty) {
      return MarkdownBody(data: data, styleSheet: styleSheet);
    }

    return MarkdownBody(
      data: data,
      styleSheet: styleSheet,
      inlineSyntaxes: <md.InlineSyntax>[
        _DictionaryInlineSyntax(entriesByTitle: entriesByTitle),
      ],
      builders: <String, MarkdownElementBuilder>{
        'dictionary-entry': _DictionaryEntryBuilder(
          entriesByTitle: entriesByTitle,
          onTapEntry: onTapEntry,
          linkColor: linkColor,
        ),
      },
    );
  }
}

class DictionaryEntryPreviewSheet extends StatelessWidget {
  final DictionaryEntry entry;
  final VoidCallback onOpenDictionary;
  final VoidCallback? onOpenQuest;
  final VoidCallback? onCopyRoute;
  final VoidCallback? onSendToChat;

  const DictionaryEntryPreviewSheet({
    super.key,
    required this.entry,
    required this.onOpenDictionary,
    this.onOpenQuest,
    this.onCopyRoute,
    this.onSendToChat,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sheetStyle = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: TextStyle(color: cs.onSurface, fontSize: 14, height: 1.55),
      listBullet: TextStyle(color: cs.onSurface, fontSize: 14),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.title, style: TextStyle(color: cs.onSurface, fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(entry.subject, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copy dictionary link',
                  onPressed: onCopyRoute,
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: SingleChildScrollView(
                child: MarkdownBody(
                  data: entry.description,
                  styleSheet: sheetStyle,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (onSendToChat != null)
                  FilledButton.icon(
                    onPressed: onSendToChat,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Send in chat'),
                  ),
                if (onSendToChat != null) const SizedBox(height: 10),
                if (onOpenQuest != null) ...[
                  FilledButton.icon(
                    onPressed: onOpenQuest,
                    icon: const Icon(Icons.center_focus_strong_rounded),
                    label: const Text('Open quest'),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: onOpenDictionary,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Open dictionary'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showDictionaryEntryPreviewSheet(
  BuildContext context, {
  required DictionaryEntry entry,
  required VoidCallback onOpenDictionary,
  VoidCallback? onOpenQuest,
  VoidCallback? onSendToChat,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      void closeThen(VoidCallback action) {
        Navigator.of(ctx).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          action();
        });
      }

      return DictionaryEntryPreviewSheet(
        entry: entry,
        onOpenDictionary: () => closeThen(onOpenDictionary),
        onOpenQuest: onOpenQuest == null ? null : () => closeThen(onOpenQuest),
        onSendToChat: onSendToChat == null ? null : () => closeThen(onSendToChat),
        onCopyRoute: () {
          Clipboard.setData(ClipboardData(text: entry.route));
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('Copied ${entry.title} link')),
          );
        },
      );
    },
  );
}

class _DictionaryInlineSyntax extends md.InlineSyntax {
  final Map<String, DictionaryEntry> entriesByTitle;

  _DictionaryInlineSyntax({required this.entriesByTitle}) : super(_buildPattern(entriesByTitle.keys.toList()), caseSensitive: false);

  static String _buildPattern(List<String> titles) {
    final terms = titles.where((t) => t.trim().isNotEmpty).map(RegExp.escape).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (terms.isEmpty) return r'(?!x)x';
    return r'(?<!\w)(' + terms.join('|') + r')(?!\w)';
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final matched = match.group(0) ?? '';
    final entry = entriesByTitle[matched.trim().toLowerCase()];
    if (entry == null) {
      return false;
    }

    parser.addNode(
      md.Element('dictionary-entry', <md.Node>[md.Element.text('span', matched)])
        ..attributes['href'] = entry.route,
    );
    return true;
  }
}

class _DictionaryEntryBuilder extends MarkdownElementBuilder {
  final Map<String, DictionaryEntry> entriesByTitle;
  final void Function(DictionaryEntry entry) onTapEntry;
  final Color? linkColor;

  _DictionaryEntryBuilder({required this.entriesByTitle, required this.onTapEntry, this.linkColor});

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final href = element.attributes['href'];
    if (href == null) {
      return Text(element.textContent, style: preferredStyle);
    }

    final uri = Uri.tryParse(href);
    if (uri == null) {
      return Text(element.textContent, style: preferredStyle);
    }

    final questId = int.tryParse(uri.queryParameters['id'] ?? '');
    final subject = uri.queryParameters['subject']?.trim().toLowerCase();
    DictionaryEntry? entry;
    if (questId != null) {
      for (final candidate in entriesByTitle.values) {
        if (candidate.questId == questId && (subject == null || candidate.subject.toLowerCase() == subject)) {
          entry = candidate;
          break;
        }
      }
    }
    entry ??= entriesByTitle[element.textContent.trim().toLowerCase()];
    if (entry == null) {
      return Text(element.textContent, style: preferredStyle);
    }

    final style = (preferredStyle ?? const TextStyle()).copyWith(
      color: linkColor ?? preferredStyle?.color,
      decoration: TextDecoration.underline,
      decorationColor: linkColor ?? preferredStyle?.color,
    );

    return GestureDetector(
      onTap: () => onTapEntry(entry!),
      child: Text(element.textContent, style: style),
    );
  }
}

class _TextMatch {
  final int start;
  final int end;
  final DictionaryEntry? entry;
  final String? route;

  const _TextMatch({required this.start, required this.end, this.entry, this.route});
}

List<_TextMatch> _findMatches(String text, Map<String, DictionaryEntry> entriesByTitle) {
  final matches = <_TextMatch>[];

  final routeRegex = RegExp(r'(?<!\S)(/\S+)');
  for (final match in routeRegex.allMatches(text)) {
    final raw = match.group(1);
    if (raw == null || raw.isEmpty) continue;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.path.isEmpty) continue;
    if (!_isSupportedRoute(uri.path)) continue;
    matches.add(_TextMatch(start: match.start, end: match.end, route: raw));
  }

  final dictRegex = RegExp(
    _buildDictionaryPattern(entriesByTitle.keys.toList()),
    multiLine: true,
    caseSensitive: false,
  );
  for (final match in dictRegex.allMatches(text)) {
    final matched = match.group(0) ?? '';
    final entry = entriesByTitle[matched.trim().toLowerCase()];
    if (entry == null) continue;
    matches.add(_TextMatch(start: match.start, end: match.end, entry: entry));
  }

  matches.sort((a, b) {
    final startCompare = a.start.compareTo(b.start);
    if (startCompare != 0) return startCompare;
    return b.end.compareTo(a.end);
  });

  final filtered = <_TextMatch>[];
  var lastEnd = -1;
  for (final match in matches) {
    if (match.start < lastEnd) continue;
    filtered.add(match);
    lastEnd = match.end;
  }
  return filtered;
}

String _buildDictionaryPattern(List<String> titles) {
  final terms = titles.where((t) => t.trim().isNotEmpty).map(RegExp.escape).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (terms.isEmpty) return r'(?!x)x';
  return r'(?<!\w)(' + terms.join('|') + r')(?!\w)';
}

bool _isSupportedRoute(String path) {
  return path.startsWith('/feed/') || path == '/quests' || path.startsWith('/chat') || path == '/search' || path == '/dictionary' || path.startsWith('/themes');
}

