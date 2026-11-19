import 'dart:convert';

import 'models.dart';

/// Répartition des notions entre 1re et 2e année (exigence 4 : configurable).
///
/// Ordre de priorité : réglage de l'utilisateur pour le chapitre, puis pour le
/// domaine ; année du référentiel ; répartition par défaut du contenu
/// (`parcours.json`) ; sinon « non classé ».
class Parcours {
  Parcours({Map<String, int>? defaults, Map<String, int>? overrides})
      : defaults = defaults ?? {},
        overrides = overrides ?? {};

  /// Clés « domaine » ou « domaine / chapitre » → 1 ou 2.
  final Map<String, int> defaults;
  final Map<String, int> overrides;

  static String key(String domain, [String? chapter]) => chapter == null || chapter.isEmpty ? domain : '$domain / $chapter';

  int? yearOf(Notion n) {
    final kc = key(n.domain, n.chapter), kd = key(n.domain);
    return overrides[kc] ?? overrides[kd] ?? n.year ?? defaults[kc] ?? defaults[kd];
  }

  /// Vrai si l'année vient d'une répartition proposée (pas du référentiel).
  bool isDefaultGuess(Notion n) =>
      n.year == null && !overrides.containsKey(key(n.domain, n.chapter)) && !overrides.containsKey(key(n.domain));

  List<Notion> notionsForYear(Library lib, int year) =>
      [for (final n in lib.notions) if (n.inProgramme && yearOf(n) == year) n];

  factory Parcours.fromJson(Map<String, dynamic> j) =>
      Parcours(defaults: {for (final e in (j['defaults'] as Map<String, dynamic>? ?? const {}).entries) e.key: e.value as int});
}

class Attempt {
  Attempt(this.seed, this.correct, this.at);
  final int seed;
  final bool correct;
  final DateTime at;

  Map<String, dynamic> toJson() => {'seed': seed, 'ok': correct, 'at': at.toIso8601String()};
  factory Attempt.fromJson(Map<String, dynamic> j) =>
      Attempt(j['seed'] as int, j['ok'] as bool, DateTime.parse(j['at'] as String));
}

/// Progression locale de l'étudiant (aucun compte, aucun serveur).
class ProgressState {
  ProgressState();

  /// Boîte de révision (0 à 5) par notion : réussite → +1, échec → −1.
  final Map<String, int> boxes = {};
  final Map<String, List<Attempt>> attempts = {};
  final Set<String> coursesRead = {};

  /// Année suivie (1 ou 2).
  int year = 1;

  /// Répartition choisie par l'utilisateur (domaine ou chapitre → année).
  final Map<String, int> yearOverrides = {};
  String? lastNotion;

  /// Réglages de l'interface (thème…).
  final Map<String, String> settings = {};

  static const maxBox = 5;

  double mastery(String notionId) => (boxes[notionId] ?? 0) / maxBox;

  void recordAttempt(Exercise ex, int seed, bool correct, {DateTime? now}) {
    final t = now ?? DateTime.now();
    attempts.putIfAbsent(ex.id, () => []).add(Attempt(seed, correct, t));
    for (final n in ex.notions) {
      final b = boxes[n] ?? 0;
      boxes[n] = correct ? (b + 1).clamp(0, maxBox) : (b - 1).clamp(0, maxBox);
      lastNotion = n;
    }
  }

  void markCourseRead(Course c) {
    coursesRead.add(c.id);
    if (c.notions.isNotEmpty) lastNotion = c.notions.first;
  }

  int solvedCount() => attempts.values.where((l) => l.any((a) => a.correct)).length;

  /// Maîtrise moyenne sur un ensemble de notions qui ont du contenu.
  double masteryOf(Iterable<Notion> notions, Library lib) {
    final withContent = notions.where((n) => lib.exercisesFor(n.id).isNotEmpty).toList();
    if (withContent.isEmpty) return 0;
    return withContent.map((n) => mastery(n.id)).reduce((a, b) => a + b) / withContent.length;
  }

  /// Prochaine notion conseillée : première du parcours de l'année qui a des
  /// exercices et n'est pas encore maîtrisée (boîte < 3), prérequis d'abord.
  Notion? nextNotion(Library lib, Parcours parcours) {
    final list = parcours.notionsForYear(lib, year).where((n) => lib.hasContent(n.id)).toList();
    for (final n in list) {
      final pending = n.prerequisites.where((p) {
        final pn = lib.byId[p];
        return pn != null && lib.hasContent(p) && (boxes[p] ?? 0) < 3;
      });
      if (pending.isNotEmpty) {
        final first = lib.byId[pending.first];
        if (first != null && first.inProgramme) return first;
      }
      if ((boxes[n.id] ?? 0) < 3) return n;
    }
    return list.isEmpty ? null : list.first;
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'year': year,
        'boxes': boxes,
        'attempts': {for (final e in attempts.entries) e.key: [for (final a in e.value) a.toJson()]},
        'coursesRead': coursesRead.toList(),
        'yearOverrides': yearOverrides,
        'lastNotion': lastNotion,
        'settings': settings,
      };

  String encode() => const JsonEncoder.withIndent(' ').convert(toJson());

  factory ProgressState.fromJson(Map<String, dynamic> j) {
    final s = ProgressState();
    s.year = (j['year'] ?? 1) as int;
    (j['boxes'] as Map<String, dynamic>? ?? const {}).forEach((k, v) => s.boxes[k] = v as int);
    (j['attempts'] as Map<String, dynamic>? ?? const {}).forEach((k, v) {
      s.attempts[k] = [for (final a in v as List) Attempt.fromJson(a as Map<String, dynamic>)];
    });
    s.coursesRead.addAll([for (final c in (j['coursesRead'] as List? ?? const [])) c as String]);
    (j['yearOverrides'] as Map<String, dynamic>? ?? const {}).forEach((k, v) => s.yearOverrides[k] = v as int);
    s.lastNotion = j['lastNotion'] as String?;
    (j['settings'] as Map<String, dynamic>? ?? const {}).forEach((k, v) => s.settings[k] = '$v');
    return s;
  }

  static ProgressState decode(String? src) {
    if (src == null || src.trim().isEmpty) return ProgressState();
    try {
      return ProgressState.fromJson(jsonDecode(src) as Map<String, dynamic>);
    } catch (_) {
      return ProgressState();
    }
  }
}
