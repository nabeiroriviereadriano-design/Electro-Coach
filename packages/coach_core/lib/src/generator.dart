import 'dart:math' as math;

import 'complex.dart';
import 'expr.dart';
import 'models.dart';
import 'units.dart';

/// Un exercice tiré au sort : valeurs des paramètres et réponses attendues.
class ExerciseInstance {
  ExerciseInstance(this.exercise, this.seed, this.env, this.expected);
  final Exercise exercise;
  final int seed;

  /// Paramètres et grandeurs calculées.
  final Map<String, Complex> env;

  /// Réponse attendue par question (id → valeur ; pour un QCM, l'indice).
  final Map<String, Complex> expected;

  /// Remplace les modèles [[…]] d'un texte par leurs valeurs.
  String render(String text) => renderTemplate(text, env, units: _units);

  Map<String, String> get _units => {for (final e in exercise.params.entries) e.key: e.value.unit};
}

class GenerationError implements Exception {
  GenerationError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Tire les paramètres d'un exercice. Le même [seed] donne toujours le même
/// énoncé (reprise d'un exercice, vérification automatique des corrigés).
ExerciseInstance generate(Exercise ex, int seed, {int maxTries = 200}) {
  final rnd = math.Random(seed);
  final parsedVars = [for (final v in ex.vars) MapEntry(v.key, parseExpr(v.value))];
  final parsedConstraints = [for (final c in ex.constraints) _parseConstraint(c)];
  String? lastError;
  for (var attempt = 0; attempt < maxTries; attempt++) {
    final env = <String, Complex>{};
    ex.params.forEach((name, spec) => env[name] = Complex(_draw(spec, rnd, name)));
    try {
      for (final v in parsedVars) {
        env[v.key] = v.value.eval(env);
      }
      if (!parsedConstraints.every((c) => c(env))) {
        lastError = 'contraintes non respectées';
        continue;
      }
      final expected = <String, Complex>{};
      for (final q in ex.questions) {
        if (q.kind == 'choice') {
          final idx = q.correctExpr != null ? parseExpr(q.correctExpr!).eval(env).re.round() : (q.correct ?? -1);
          if (idx < 0 || idx >= q.choices.length) throw ExprError('bonne proposition hors liste pour ${q.id}');
          expected[q.id] = Complex(idx.toDouble());
        } else {
          final v = parseExpr(q.answer ?? '').eval(env);
          if (!v.isFinite) throw ExprError('réponse non finie pour ${q.id}');
          expected[q.id] = v;
        }
      }
      return ExerciseInstance(ex, seed, env, expected);
    } on ExprError catch (e) {
      lastError = e.message;
    }
  }
  throw GenerationError('${ex.id} : tirage impossible ($lastError)');
}

double _draw(ParamSpec s, math.Random rnd, String name) {
  if (s.values != null && s.values!.isNotEmpty) return s.values![rnd.nextInt(s.values!.length)];
  final lo = s.min, hi = s.max;
  if (lo == null || hi == null) throw GenerationError('paramètre $name sans valeurs');
  final step = s.step;
  if (step != null && step > 0) {
    final n = ((hi - lo) / step).floor();
    final v = lo + step * rnd.nextInt(n + 1);
    // supprime les erreurs d'arrondi binaires (0.1 + 0.2…)
    return double.parse(v.toStringAsPrecision(12));
  }
  return lo + (hi - lo) * rnd.nextDouble();
}

bool Function(Map<String, Complex>) _parseConstraint(String c) {
  for (final op in const ['>=', '<=', '!=', '>', '<', '==']) {
    final i = c.indexOf(op);
    if (i > 0) {
      final a = parseExpr(c.substring(0, i)), b = parseExpr(c.substring(i + op.length));
      return (env) {
        final x = a.eval(env).re, y = b.eval(env).re;
        switch (op) {
          case '>=':
            return x >= y;
          case '<=':
            return x <= y;
          case '!=':
            return (x - y).abs() > 1e-12 * math.max(1, x.abs());
          case '>':
            return x > y;
          case '<':
            return x < y;
          default:
            return (x - y).abs() <= 1e-12 * math.max(1, x.abs());
        }
      };
    }
  }
  throw ExprError('Contrainte illisible : $c');
}

final _tpl = RegExp(r'\[\[(=?)([^\[\]|]+?)(?::(\d+))?(?:\|([^\[\]]*))?\]\]');

/// Modèles reconnus dans les textes :
/// - `[[R]]` : valeur d'un paramètre (avec son unité si elle est déclarée) ;
/// - `[[=expr]]`, `[[=expr:3]]` : valeur calculée, 3 chiffres significatifs ;
/// - `[[=expr:3|Ω]]` : avec unité et préfixe SI ; `[[=expr|polar]]` : complexe en polaire ;
/// - `[[=expr|nu]]` : sans unité.
String renderTemplate(String text, Map<String, Complex> env, {Map<String, String> units = const {}}) {
  return text.replaceAllMapped(_tpl, (m) {
    final out = _renderOne(m, env, units);
    return _insideTex(text, m.start) ? texSafe(out) : out;
  });
}

/// Vrai si la position est entre deux \$ (formule en ligne).
bool _insideTex(String text, int pos) {
  var n = 0;
  for (var k = 0; k < pos; k++) {
    if (text[k] == r'$' && (k == 0 || text[k - 1] != '\\')) n++;
  }
  return n.isOdd;
}

/// Adapte une valeur mise en forme pour l'insérer dans du LaTeX.
String texSafe(String s) => s
    .replaceAll('−', '-')
    .replaceAll(',', '{,}')
    .replaceAll('\u202f', '\\,')
    .replaceAll('Ω', '\\Omega')
    .replaceAll('µ', '\\mu ')
    .replaceAll('°', '^{\\circ}')
    .replaceAll('∠', '\\angle ')
    .replaceAll('×', '\\times ')
    .replaceAll(' ', '\\ ');

String _renderOne(Match m, Map<String, Complex> env, Map<String, String> units) {
  {
    final computed = m.group(1) == '=';
    final src = m.group(2)!.trim();
    final sig = int.tryParse(m.group(3) ?? '') ?? 3;
    final opts = (m.group(4) ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final polar = opts.remove('polar');
    final noUnit = opts.remove('nu');
    final value = parseExpr(src).eval(env);
    if (opts.remove('bin')) return value.re.round().toRadixString(2);
    if (opts.remove('hex')) return value.re.round().toRadixString(16).toUpperCase();
    var unit = opts.isNotEmpty ? opts.first : '';
    if (!computed && unit.isEmpty && !noUnit) unit = units[src] ?? '';
    if (noUnit) unit = '';
    if (!value.isReal || polar) return formatComplex(value, sig: sig, polar: polar, unit: unit);
    return unit.isEmpty ? formatNumber(value.re, sig: sig) : formatEng(value.re, unit, sig: sig);
  }
}

/// Vrai si un texte contient encore un modèle non remplacé.
bool hasTemplate(String text) => _tpl.hasMatch(text) || text.contains('[[') || text.contains(']]');

/// Résultat de la correction d'une réponse.
class Verdict {
  Verdict(this.correct, this.message, {this.value});
  final bool correct;
  final String message;
  final Complex? value;
}

/// Corrige la saisie d'un étudiant pour une question.
Verdict check(Question q, Complex expected, String input) {
  final raw = input.trim();
  if (raw.isEmpty) return Verdict(false, 'Réponse vide.');
  if (q.kind == 'choice') {
    final i = int.tryParse(raw);
    final ok = i != null && i == expected.re.round();
    return Verdict(ok, ok ? 'Bonne réponse.' : 'Ce n\'est pas la bonne proposition.');
  }
  if (q.kind == 'base') {
    final digits = raw.replaceAll(RegExp(r'[\s\u202f\u00a0]'), '').replaceFirst(RegExp(r'^0[xXbB]'), '').replaceFirst(RegExp(r'[hH₂]$'), '');
    final v = int.tryParse(digits, radix: q.base);
    if (v == null) {
      return Verdict(false, q.base == 2 ? 'Écris uniquement des 0 et des 1.' : 'Écris un nombre hexadécimal (chiffres 0–9 et lettres A–F).');
    }
    final ok = v == expected.re.round();
    return Verdict(ok, ok ? 'Bonne réponse.' : 'Ce n\'est pas la valeur attendue.', value: Complex(v.toDouble()));
  }
  final split = splitUnit(raw, q.unit.isEmpty ? null : q.unit);
  if (split == null) return Verdict(false, 'Unité incorrecte : l\'unité attendue est « ${q.unit} ».');
  Complex v;
  try {
    v = parseExpr(split.numberPart, userInput: true).eval(const {});
  } on ExprError catch (e) {
    // sans unité demandée, on tolère une unité écrite à la fin (« 1500 kWh », « 12 € »)
    final stripped = q.unit.isEmpty ? split.numberPart.replaceFirst(RegExp(r'\s*[A-Za-zΩµ°€%/²³]+\s*$'), '') : '';
    Complex? retry;
    if (stripped.isNotEmpty && stripped != split.numberPart && !RegExp(r'[ji]\s*$').hasMatch(split.numberPart)) {
      try {
        retry = parseExpr(stripped, userInput: true).eval(const {});
      } on ExprError {
        retry = null;
      }
    }
    if (retry == null) return Verdict(false, 'Saisie illisible : ${e.message}.');
    v = retry;
  }
  if (!v.isFinite) return Verdict(false, 'Saisie illisible.');
  v = v.scale(split.factor);
  final tol = q.tolerance;
  bool close(Complex a, Complex b) {
    final scale = math.max(b.abs, 1e-300);
    return (a - b).abs <= tol * scale + 1e-15;
  }

  bool ok;
  if (q.kind == 'numeric') {
    if (!v.isReal) return Verdict(false, 'Une valeur réelle est attendue.', value: v);
    ok = close(v, Complex(expected.re));
    if (!ok && q.unit == '°') {
      // angles égaux à 360° près
      final d = ((v.re - expected.re) % 360 + 360) % 360;
      ok = d <= tol * math.max(expected.re.abs(), 1) || 360 - d <= tol * math.max(expected.re.abs(), 1);
    }
  } else {
    ok = close(v, expected);
  }
  final unitNote = (split.unitGiven == null && q.unit.isNotEmpty) ? ' Pense à écrire l\'unité (${q.unit}).' : '';
  if (ok) return Verdict(true, 'Bonne réponse.$unitNote', value: v);
  return Verdict(false, 'Ce n\'est pas la valeur attendue.$unitNote', value: v);
}

/// Réponse attendue mise en forme, pour l'affichage du corrigé.
String formatExpected(Question q, Complex v) {
  if (q.kind == 'choice') {
    final i = v.re.round();
    return i >= 0 && i < q.choices.length ? q.choices[i] : '?';
  }
  if (q.kind == 'base') return v.re.round().toRadixString(q.base).toUpperCase();
  if (q.kind == 'complex') return formatComplex(v, sig: q.sig, polar: q.polar, unit: q.unit);
  return q.unit.isEmpty ? formatNumber(v.re, sig: q.sig) : formatEng(v.re, q.unit, sig: q.sig);
}

/// Ordre d'affichage des propositions d'un QCM, mélangé de façon reproductible
/// pour un tirage donné (la bonne réponse n'est pas toujours la première).
List<int> choiceOrder(ExerciseInstance inst, Question q) {
  final order = List<int>.generate(q.choices.length, (i) => i);
  order.shuffle(math.Random(inst.seed * 31 + q.id.hashCode));
  return order;
}
