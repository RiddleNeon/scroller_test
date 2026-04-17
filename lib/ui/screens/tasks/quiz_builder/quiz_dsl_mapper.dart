import 'dart:math';

import 'quiz_models.dart';

class QuizDslMapper {
  static Map<String, dynamic> toUiJson(QuizVersionDraft draft) {
    return <String, dynamic>{
      'version': '1.0',
      'theme': <String, dynamic>{'primary': draft.themePrimary},
      'screens': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'main',
          'animation': <String, dynamic>{'type': 'fade', 'duration_ms': 220},
          'elements': draft.questions
              .map((question) => <String, dynamic>{
                    'id': question.id,
                    'type': quizQuestionTypeToUi(question.type),
                    'props': <String, dynamic>{
                      'title': question.title,
                      if (question.options.isNotEmpty) 'options': question.options,
                      if ((question.placeholder ?? '').trim().isNotEmpty) 'placeholder': question.placeholder,
                    },
                    'bind': <String, dynamic>{
                      'answer_path': _answerPathForQuestion(question),
                    },
                  })
              .toList(growable: false),
        },
      ],
    };
  }

  static Map<String, dynamic> toLogicJson(QuizVersionDraft draft) {
    final List<Map<String, dynamic>> rules = <Map<String, dynamic>>[];

    for (final question in draft.questions) {
      rules.add(_buildQuestionRule(question));
    }

    return <String, dynamic>{
      'rules': rules,
      'pass': <String, dynamic>{
        'min_score': min(draft.passMinScore, draft.maxScore),
      },
    };
  }

  static QuizVersionDraft fromVersionRow(Map<String, dynamic> row) {
    final ui = row['ui'] is Map ? Map<String, dynamic>.from(row['ui'] as Map) : <String, dynamic>{};
    final logic = row['logic'] is Map ? Map<String, dynamic>.from(row['logic'] as Map) : <String, dynamic>{};

    final List<Map<String, dynamic>> elements = _extractElements(ui);
    final List<Map<String, dynamic>> rules = _extractRules(logic);

    final Map<String, Map<String, dynamic>> ruleByQuestionId = <String, Map<String, dynamic>>{};
    for (final rule in rules) {
      final String? id = rule['id'] as String?;
      if (id != null && id.endsWith('_correct')) {
        ruleByQuestionId[id.replaceFirst('_correct', '')] = rule;
      }
    }

    final List<QuizQuestionDraft> questions = <QuizQuestionDraft>[];
    for (final element in elements) {
      final String id = (element['id'] as String?) ?? 'q_${questions.length + 1}';
      final String typeRaw = (element['type'] as String?) ?? 'text_input';
      final props = element['props'] is Map ? Map<String, dynamic>.from(element['props'] as Map) : <String, dynamic>{};
      final bind = element['bind'] is Map ? Map<String, dynamic>.from(element['bind'] as Map) : <String, dynamic>{};
      final String answerPath = (bind['answer_path'] as String?) ?? '$id.value';
      final rule = ruleByQuestionId[id];

      final points = _readPointsFromRule(rule);
      final hardFail = _readHardFailFromRule(rule);

      questions.add(
        QuizQuestionDraft(
          id: id,
          type: quizQuestionTypeFromUi(typeRaw),
          title: (props['title'] as String?) ?? 'Question ${questions.length + 1}',
          points: points,
          options: (props['options'] as List?)?.map((e) => '$e').toList(growable: false) ?? const <String>[],
          correctAnswers: _readCorrectAnswersFromRule(rule, answerPath: answerPath),
          placeholder: props['placeholder'] as String?,
          hardFail: hardFail,
        ),
      );
    }

    final pass = logic['pass'] is Map ? Map<String, dynamic>.from(logic['pass'] as Map) : <String, dynamic>{};
    final passMinScore = _toDouble(pass['min_score']) ??
        questions.fold<double>(0, (sum, question) => sum + question.points);

    return QuizVersionDraft(
      title: (row['title'] as String?) ?? 'Draft',
      passMinScore: passMinScore,
      themePrimary: (ui['theme'] is Map ? (ui['theme'] as Map)['primary'] : null) as String? ?? '#6C5443',
      questions: questions,
    );
  }

  static Map<String, dynamic> buildAnswerPayload(Map<String, dynamic> rawAnswersByQuestionId) {
    final Map<String, dynamic> answers = <String, dynamic>{};
    rawAnswersByQuestionId.forEach((questionId, answer) {
      if (answer is List<String>) {
        answers[questionId] = <String, dynamic>{'selected': answer};
      } else {
        answers[questionId] = <String, dynamic>{'selected': answer};
      }
    });

    return <String, dynamic>{
      'answers': answers,
      'vars': <String, dynamic>{},
    };
  }

  static List<Map<String, dynamic>> _extractElements(Map<String, dynamic> ui) {
    final screens = ui['screens'];
    if (screens is! List) return <Map<String, dynamic>>[];

    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    for (final screen in screens) {
      if (screen is! Map) continue;
      final elements = screen['elements'];
      if (elements is! List) continue;
      for (final element in elements) {
        if (element is Map) {
          out.add(Map<String, dynamic>.from(element));
        }
      }
    }
    return out;
  }

  static List<Map<String, dynamic>> _extractRules(Map<String, dynamic> logic) {
    final rules = logic['rules'];
    if (rules is! List) return <Map<String, dynamic>>[];
    return rules.whereType<Map>().map((raw) => Map<String, dynamic>.from(raw)).toList(growable: false);
  }

  static Map<String, dynamic> _buildQuestionRule(QuizQuestionDraft question) {
    final then = <String, dynamic>{
      'add_score': question.points,
      'max_score': question.points,
    };
    final elseBranch = <String, dynamic>{
      'max_score': question.points,
      if (question.hardFail) 'fail': true,
    };

    return <String, dynamic>{
      'id': '${question.id}_correct',
      'when': _buildWhenCondition(question),
      'then': then,
      'else': elseBranch,
    };
  }

  static Map<String, dynamic> _buildWhenCondition(QuizQuestionDraft question) {
    final path = _answerPathForQuestion(question);
    if (question.type == QuizQuestionType.multiChoice) {
      final required = question.correctAnswers;
      return <String, dynamic>{
        'op': 'and',
        'args': required
            .map(
              (answer) => <String, dynamic>{
                'op': 'contains',
                'left': <String, dynamic>{'source': 'answers', 'path': path},
                'right': <String, dynamic>{'const': answer},
              },
            )
            .toList(growable: false),
      };
    }

    final correct = question.correctAnswers.isEmpty ? '' : question.correctAnswers.first;
    return <String, dynamic>{
      'op': 'eq',
      'left': <String, dynamic>{'source': 'answers', 'path': path},
      'right': <String, dynamic>{'const': question.type == QuizQuestionType.number ? (_toDouble(correct) ?? 0) : correct},
    };
  }

  static String _answerPathForQuestion(QuizQuestionDraft question) => '${question.id}.selected';

  static double _readPointsFromRule(Map<String, dynamic>? rule) {
    if (rule == null) return 1;
    final thenRaw = rule['then'] is Map ? Map<String, dynamic>.from(rule['then'] as Map) : <String, dynamic>{};
    return _toDouble(thenRaw['max_score']) ?? _toDouble(thenRaw['add_score']) ?? 1;
  }

  static bool _readHardFailFromRule(Map<String, dynamic>? rule) {
    if (rule == null) return false;
    final elseRaw = rule['else'] is Map ? Map<String, dynamic>.from(rule['else'] as Map) : <String, dynamic>{};
    return elseRaw['fail'] == true || '${elseRaw['fail']}'.toLowerCase() == 'true';
  }

  static List<String> _readCorrectAnswersFromRule(
    Map<String, dynamic>? rule, {
    required String answerPath,
  }) {
    if (rule == null) return const <String>[];

    final whenRaw = rule['when'] is Map ? Map<String, dynamic>.from(rule['when'] as Map) : <String, dynamic>{};
    final op = '${whenRaw['op'] ?? ''}'.toLowerCase();

    if (op == 'eq') {
      final right = whenRaw['right'] is Map ? Map<String, dynamic>.from(whenRaw['right'] as Map) : <String, dynamic>{};
      if (right.containsKey('const')) {
        return <String>['${right['const']}'];
      }
    }

    if (op == 'and') {
      final args = whenRaw['args'];
      if (args is! List) return const <String>[];
      final out = <String>[];
      for (final arg in args) {
        if (arg is! Map) continue;
        final argMap = Map<String, dynamic>.from(arg);
        if ('${argMap['op']}'.toLowerCase() != 'contains') continue;

        final left = argMap['left'] is Map ? Map<String, dynamic>.from(argMap['left'] as Map) : <String, dynamic>{};
        final leftPath = '${left['path'] ?? ''}';
        if (leftPath != answerPath) continue;

        final right = argMap['right'] is Map ? Map<String, dynamic>.from(argMap['right'] as Map) : <String, dynamic>{};
        if (right.containsKey('const')) {
          out.add('${right['const']}');
        }
      }
      return out;
    }

    return const <String>[];
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value == null) return null;
    return double.tryParse('$value');
  }
}

