enum QuizQuestionType {
  singleChoice,
  multiChoice,
  text,
  number,
}

QuizQuestionType quizQuestionTypeFromUi(String raw) {
  switch (raw) {
    case 'single_choice':
      return QuizQuestionType.singleChoice;
    case 'multi_choice':
      return QuizQuestionType.multiChoice;
    case 'number_input':
      return QuizQuestionType.number;
    case 'text_input':
    default:
      return QuizQuestionType.text;
  }
}

String quizQuestionTypeToUi(QuizQuestionType type) {
  switch (type) {
    case QuizQuestionType.singleChoice:
      return 'single_choice';
    case QuizQuestionType.multiChoice:
      return 'multi_choice';
    case QuizQuestionType.number:
      return 'number_input';
    case QuizQuestionType.text:
      return 'text_input';
  }
}

class QuizQuestionDraft {
  QuizQuestionDraft({
    required this.id,
    required this.type,
    required this.title,
    required this.points,
    this.options = const <String>[],
    this.correctAnswers = const <String>[],
    this.placeholder,
    this.hardFail = false,
  });

  final String id;
  QuizQuestionType type;
  String title;
  double points;
  List<String> options;
  List<String> correctAnswers;
  String? placeholder;
  bool hardFail;

  QuizQuestionDraft copyWith({
    String? id,
    QuizQuestionType? type,
    String? title,
    double? points,
    List<String>? options,
    List<String>? correctAnswers,
    String? placeholder,
    bool? hardFail,
  }) {
    return QuizQuestionDraft(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      points: points ?? this.points,
      options: options ?? List<String>.from(this.options),
      correctAnswers: correctAnswers ?? List<String>.from(this.correctAnswers),
      placeholder: placeholder ?? this.placeholder,
      hardFail: hardFail ?? this.hardFail,
    );
  }
}

class QuizVersionDraft {
  QuizVersionDraft({
    required this.title,
    required this.passMinScore,
    this.themePrimary = '#6C5443',
    this.questions = const <QuizQuestionDraft>[],
  });

  String title;
  double passMinScore;
  String themePrimary;
  List<QuizQuestionDraft> questions;

  double get maxScore =>
      questions.fold<double>(0, (sum, question) => sum + question.points);

  QuizVersionDraft copyWith({
    String? title,
    double? passMinScore,
    String? themePrimary,
    List<QuizQuestionDraft>? questions,
  }) {
    return QuizVersionDraft(
      title: title ?? this.title,
      passMinScore: passMinScore ?? this.passMinScore,
      themePrimary: themePrimary ?? this.themePrimary,
      questions: questions ?? List<QuizQuestionDraft>.from(this.questions),
    );
  }
}

class QuizTaskMetaDraft {
  QuizTaskMetaDraft({
    this.taskType = 'quiz_dsl',
    this.taskTitle = 'Untitled DSL Quiz',
    this.subjects = const <String>['General'],
    this.xpReward = 0.1,
    this.xpPunishment = 0,
  });

  String taskType;
  String taskTitle;
  List<String> subjects;
  double xpReward;
  double xpPunishment;
}

