/// Modèles du contenu pédagogique et du référentiel.
///
/// Tout le contenu est en JSON (dossier `app/assets/content/`) : le référentiel
/// (`notions.json`, exporté du classeur de couverture) et des « packs » de
/// cours, exemples corrigés et exercices.
library;

/// Statuts d'inventaire repris du classeur de couverture.
class NotionStatus {
  static const notDeveloped = 'Non développé';
  static const incomplete = 'Incomplet';
  static const integrated = 'Intégré – à vérifier';
  static const conform = 'Conforme (vérifié)';
  static const toDecide = 'Périmètre à arbitrer';
  static const outOfScope = 'Hors programme';
  static const notRequired = 'Non exigible';

  /// Statuts qui sortent une ligne du programme à couvrir.
  static const excluded = {outOfScope, notRequired};
}

class Notion {
  Notion({
    required this.id,
    required this.subject,
    required this.domain,
    required this.chapter,
    required this.title,
    required this.year,
    required this.status,
    required this.skills,
    required this.formulas,
    required this.prerequisites,
    required this.reference,
    required this.inventoryChecked,
    required this.remark,
  });

  final String id;

  /// « Mathématiques » ou « Sciences appliquées ».
  final String subject;
  final String domain;
  final String chapter;
  final String title;

  /// 1, 2, ou null quand le référentiel ne précise pas l'année.
  final int? year;

  /// Statut d'inventaire (ex. « Hors programme », « Périmètre à arbitrer »).
  final String status;
  final String skills;
  final String formulas;
  final List<String> prerequisites;
  final String reference;

  /// Faux si la ligne d'inventaire reste « À vérifier sur le texte intégral ».
  final bool inventoryChecked;
  final String remark;

  bool get inProgramme => !NotionStatus.excluded.contains(status);
  bool get isMaths => subject == 'Mathématiques';

  factory Notion.fromJson(Map<String, dynamic> j) => Notion(
        id: j['id'] as String,
        subject: j['subject'] as String,
        domain: j['domain'] as String,
        chapter: (j['chapter'] ?? '') as String,
        title: j['title'] as String,
        year: j['year'] as int?,
        status: (j['status'] ?? NotionStatus.notDeveloped) as String,
        skills: (j['skills'] ?? '') as String,
        formulas: (j['formulas'] ?? '') as String,
        prerequisites: [for (final p in (j['prerequisites'] as List? ?? const [])) p as String],
        reference: (j['reference'] ?? '') as String,
        inventoryChecked: (j['inventoryChecked'] ?? true) as bool,
        remark: (j['remark'] ?? '') as String,
      );
}

/// Bloc de contenu affichable : texte (avec $…$ pour les formules en ligne),
/// formule centrée, encadré, courbe, schéma de circuit.
class Block {
  Block(this.type, this.data);
  final String type;
  final Map<String, dynamic> data;

  String get text => (data['text'] ?? '') as String;
  String get tex => (data['tex'] ?? '') as String;

  static const types = {'text', 'tex', 'formula', 'tip', 'warning', 'method', 'plot', 'circuit', 'table'};

  factory Block.fromJson(Map<String, dynamic> j) => Block(j['type'] as String, j);

  /// Textes de ce bloc (pour les vérifications de périmètre et de modèles).
  Iterable<String> get strings sync* {
    for (final k in const ['text', 'tex', 'title', 'caption', 'xLabel', 'yLabel']) {
      final v = data[k];
      if (v is String) yield v;
    }
    final rows = data['rows'];
    if (rows is List) {
      for (final r in rows) {
        if (r is List) {
          for (final c in r) {
            if (c is String) yield c;
          }
        }
      }
    }
    final curves = data['curves'];
    if (curves is List) {
      for (final c in curves) {
        if (c is Map && c['label'] is String) yield c['label'] as String;
      }
    }
  }
}

List<Block> _blocks(Object? v) => [for (final b in (v as List? ?? const [])) Block.fromJson(b as Map<String, dynamic>)];
List<String> _strs(Object? v) => [for (final s in (v as List? ?? const [])) s as String];

class Course {
  Course({required this.id, required this.notions, required this.title, required this.blocks, required this.validated});
  final String id;
  final List<String> notions;
  final String title;
  final List<Block> blocks;

  /// Contenu relu et déclaré conforme au référentiel.
  final bool validated;

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['id'] as String,
        notions: _strs(j['notions']),
        title: j['title'] as String,
        blocks: _blocks(j['blocks']),
        validated: (j['validated'] ?? false) as bool,
      );
}

class WorkedExample {
  WorkedExample({
    required this.id,
    required this.notions,
    required this.title,
    required this.problem,
    required this.solution,
    required this.validated,
  });
  final String id;
  final List<String> notions;
  final String title;
  final List<Block> problem;
  final List<Block> solution;
  final bool validated;

  factory WorkedExample.fromJson(Map<String, dynamic> j) => WorkedExample(
        id: j['id'] as String,
        notions: _strs(j['notions']),
        title: j['title'] as String,
        problem: _blocks(j['problem']),
        solution: _blocks(j['solution']),
        validated: (j['validated'] ?? false) as bool,
      );
}

/// Paramètre tiré au hasard : intervalle avec pas, ou liste de valeurs.
class ParamSpec {
  ParamSpec({this.min, this.max, this.step, this.values, this.unit = ''});
  final double? min, max, step;
  final List<double>? values;
  final String unit;

  factory ParamSpec.fromJson(Map<String, dynamic> j) => ParamSpec(
        min: (j['min'] as num?)?.toDouble(),
        max: (j['max'] as num?)?.toDouble(),
        step: (j['step'] as num?)?.toDouble(),
        values: (j['values'] as List?)?.map((e) => (e as num).toDouble()).toList(),
        unit: (j['unit'] ?? '') as String,
      );
}

class Question {
  Question({
    required this.id,
    required this.kind,
    required this.prompt,
    this.answer,
    this.unit = '',
    this.tolerance = 0.02,
    this.sig = 3,
    this.choices = const [],
    this.correct,
    this.polar = false,
    this.base = 10,
    this.correctExpr,
  });

  final String id;

  /// « numeric » (réel avec unité), « complex », « choice ».
  final String kind;
  final String prompt;

  /// Expression de la bonne réponse en fonction des paramètres.
  final String? answer;
  final String unit;

  /// Tolérance relative (0,02 = 2 %).
  final double tolerance;
  final int sig;
  final List<String> choices;
  final int? correct;

  /// Pour « complex » : afficher la réponse attendue en polaire.
  final bool polar;

  /// Pour « base » : entier à écrire en base 2 ou 16.
  final int base;

  /// Pour un QCM dont la bonne proposition dépend du tirage : expression qui
  /// donne son indice (ex. « 1 - lt(a, 0) »).
  final String? correctExpr;

  static const kinds = {'numeric', 'complex', 'choice', 'base'};

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as String,
        kind: j['kind'] as String,
        prompt: j['prompt'] as String,
        answer: j['answer'] as String?,
        unit: (j['unit'] ?? '') as String,
        tolerance: ((j['tolerance'] ?? 0.02) as num).toDouble(),
        sig: (j['sig'] ?? 3) as int,
        choices: _strs(j['choices']),
        correct: j['correct'] as int?,
        polar: (j['polar'] ?? false) as bool,
        base: (j['base'] ?? 10) as int,
        correctExpr: j['correctExpr'] as String?,
      );
}

class Exercise {
  Exercise({
    required this.id,
    required this.notions,
    required this.title,
    required this.difficulty,
    required this.params,
    required this.vars,
    required this.constraints,
    required this.statement,
    required this.questions,
    required this.hint,
    required this.method,
    required this.solution,
    required this.validated,
  });

  final String id;
  final List<String> notions;
  final String title;

  /// 1 (application directe) à 3 (problème contextualisé).
  final int difficulty;
  final Map<String, ParamSpec> params;

  /// Grandeurs calculées à partir des paramètres, dans l'ordre (ex. w = 2*pi*f).
  final List<MapEntry<String, String>> vars;

  /// Conditions à respecter par le tirage (ex. « L*w > 1/(C*w) »).
  final List<String> constraints;
  final List<Block> statement;
  final List<Question> questions;
  final String hint;
  final String method;
  final List<Block> solution;
  final bool validated;

  factory Exercise.fromJson(Map<String, dynamic> j) {
    final p = (j['params'] as Map<String, dynamic>? ?? const {});
    final v = (j['vars'] as Map<String, dynamic>? ?? const {});
    return Exercise(
      id: j['id'] as String,
      notions: _strs(j['notions']),
      title: j['title'] as String,
      difficulty: (j['difficulty'] ?? 1) as int,
      params: {for (final e in p.entries) e.key: ParamSpec.fromJson(e.value as Map<String, dynamic>)},
      vars: [for (final e in v.entries) MapEntry(e.key, e.value as String)],
      constraints: _strs(j['constraints']),
      statement: _blocks(j['statement']),
      questions: [for (final q in (j['questions'] as List? ?? const [])) Question.fromJson(q as Map<String, dynamic>)],
      hint: (j['hint'] ?? '') as String,
      method: (j['method'] ?? '') as String,
      solution: _blocks(j['solution']),
      validated: (j['validated'] ?? false) as bool,
    );
  }
}

class ContentPack {
  ContentPack({required this.id, required this.courses, required this.examples, required this.exercises});
  final String id;
  final List<Course> courses;
  final List<WorkedExample> examples;
  final List<Exercise> exercises;

  factory ContentPack.fromJson(Map<String, dynamic> j) => ContentPack(
        id: j['id'] as String,
        courses: [for (final c in (j['courses'] as List? ?? const [])) Course.fromJson(c as Map<String, dynamic>)],
        examples: [for (final c in (j['examples'] as List? ?? const [])) WorkedExample.fromJson(c as Map<String, dynamic>)],
        exercises: [for (final c in (j['exercises'] as List? ?? const [])) Exercise.fromJson(c as Map<String, dynamic>)],
      );
}

/// Référentiel + contenu, avec index par notion.
class Library {
  Library(this.notions, List<ContentPack> packs)
      : courses = [for (final p in packs) ...p.courses],
        examples = [for (final p in packs) ...p.examples],
        exercises = [for (final p in packs) ...p.exercises] {
    for (final n in notions) {
      byId[n.id] = n;
    }
  }

  final List<Notion> notions;
  final List<Course> courses;
  final List<WorkedExample> examples;
  final List<Exercise> exercises;
  final Map<String, Notion> byId = {};

  Iterable<Course> coursesFor(String notionId) => courses.where((c) => c.notions.contains(notionId));
  Iterable<WorkedExample> examplesFor(String notionId) => examples.where((c) => c.notions.contains(notionId));
  Iterable<Exercise> exercisesFor(String notionId) => exercises.where((c) => c.notions.contains(notionId));

  bool hasContent(String notionId) =>
      coursesFor(notionId).isNotEmpty || examplesFor(notionId).isNotEmpty || exercisesFor(notionId).isNotEmpty;

  Exercise? exercise(String id) {
    for (final e in exercises) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Domaines dans l'ordre du référentiel, pour une matière.
  List<String> domains(String subject) {
    final out = <String>[];
    for (final n in notions) {
      if (n.subject == subject && !out.contains(n.domain)) out.add(n.domain);
    }
    return out;
  }

  List<Notion> notionsOf(String domain, {bool onlyProgramme = true}) =>
      [for (final n in notions) if (n.domain == domain && (!onlyProgramme || n.inProgramme)) n];

  static const subjects = ['Mathématiques', 'Sciences appliquées'];
}
