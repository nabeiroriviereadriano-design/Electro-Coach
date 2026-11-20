import 'dart:math' as math;

import 'generator.dart';
import 'models.dart';

/// Épreuves blanches proposées par l'application.
enum ExamKind {
  maths('Mathématiques', 'Format E3 : deux problèmes, 2 heures, notés sur 20.', 'PB-M-', 2, Duration(hours: 2)),
  sciences('Sciences appliquées', 'Deux problèmes contextualisés de 2e année, 2 heures, notés sur 20.', 'PB-S-', 2, Duration(hours: 2));

  const ExamKind(this.title, this.rules, this.prefix, this.parts, this.duration);
  final String title;
  final String rules;

  /// Préfixe des identifiants des problèmes de cette épreuve.
  final String prefix;
  final int parts;
  final Duration duration;

  /// Problèmes disponibles pour cette épreuve, triés par identifiant.
  List<Exercise> problems(Library lib) =>
      lib.exercises.where((e) => e.id.startsWith(prefix)).toList()..sort((a, b) => a.id.compareTo(b.id));

  /// Assez de problèmes pour composer un sujet ?
  bool available(Library lib) => problems(lib).length >= parts;
}

/// Sujet tiré au sort : [ExamKind.parts] problèmes distincts, chacun avec son tirage.
class ExamDraw {
  ExamDraw(this.kind, this.seed, this.parts);
  final ExamKind kind;
  final int seed;
  final List<ExerciseInstance> parts;

  int get questionCount => parts.fold(0, (n, p) => n + p.exercise.questions.length);
}

/// Compose un sujet reproductible à partir d'une graine.
ExamDraw drawExam(Library lib, ExamKind kind, int seed) {
  final pool = kind.problems(lib);
  if (pool.length < kind.parts) {
    throw StateError('Pas assez de problèmes pour l\'épreuve ${kind.title} (${pool.length}/${kind.parts}).');
  }
  final rnd = math.Random(seed);
  pool.shuffle(rnd);
  final parts = <ExerciseInstance>[];
  for (var i = 0; i < kind.parts; i++) {
    parts.add(generate(pool[i], seed * 31 + i * 7919));
  }
  return ExamDraw(kind, seed, parts);
}

/// Note d'une copie : chaque problème vaut 20/parts points, répartis à parts
/// égales entre ses questions.
class ExamScore {
  ExamScore(this.perPart, this.maxPerPart);
  final List<double> perPart;
  final double maxPerPart;

  double get total => perPart.fold(0.0, (a, b) => a + b);
  double get max => maxPerPart * perPart.length;

  /// Note sur 20 arrondie au demi-point.
  double get on20 => max == 0 ? 0 : (total / max * 40).round() / 2;
}

ExamScore scoreExam(ExamDraw draw, Map<String, Map<String, Verdict>> verdicts) {
  final maxPerPart = 20 / draw.parts.length;
  final per = <double>[];
  for (final p in draw.parts) {
    final qs = p.exercise.questions;
    final v = verdicts[p.exercise.id] ?? const {};
    final ok = qs.where((q) => v[q.id]?.correct ?? false).length;
    per.add(qs.isEmpty ? 0 : maxPerPart * ok / qs.length);
  }
  return ExamScore(per, maxPerPart);
}

/// Formate une note à la française (« 13,5 »).
String formatMark(double v) {
  final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return s.replaceAll('.', ',');
}
