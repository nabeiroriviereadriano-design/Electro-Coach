import 'dart:convert';

import 'complex.dart';
import 'coverage.dart';
import 'expr.dart';
import 'generator.dart';
import 'models.dart';

/// Construit la bibliothèque à partir des textes JSON du référentiel et des packs.
Library loadLibrary(String notionsJson, Iterable<String> packsJson) {
  final n = jsonDecode(notionsJson) as Map<String, dynamic>;
  final notions = [for (final e in n['notions'] as List) Notion.fromJson(e as Map<String, dynamic>)];
  final packs = [for (final p in packsJson) ContentPack.fromJson(jsonDecode(p) as Map<String, dynamic>)];
  return Library(notions, packs);
}

class Issue {
  Issue(this.where, this.message, {this.error = true});
  final String where;
  final String message;
  final bool error;
  @override
  String toString() => '${error ? 'ERREUR' : 'alerte'} [$where] $message';
}

/// Termes hors périmètre (exigence 7) : leur présence dans le contenu est signalée.
const forbiddenTerms = [
  'TIA Portal',
  'Grafcet',
  'GRAFCET',
  'ladder',
  'Ladder',
  'câblage',
  'armoire électrique',
  'schéma de commande',
  'programmation d\'automate',
  'programmer l\'automate',
];

/// Vérifie tout le contenu : références au référentiel, modèles, et surtout
/// les corrigés, recalculés sur [seeds] tirages par exercice.
List<Issue> validate(Library lib, {int seeds = 50}) {
  final issues = <Issue>[];
  final ids = <String>{};
  for (final n in lib.notions) {
    if (!ids.add(n.id)) issues.add(Issue(n.id, 'identifiant de notion en double'));
    for (final p in n.prerequisites) {
      if (!lib.byId.containsKey(p)) issues.add(Issue(n.id, 'prérequis inconnu : $p'));
    }
  }

  final contentIds = <String>{};
  void checkNotions(String where, List<String> notions) {
    if (notions.isEmpty) issues.add(Issue(where, 'aucune notion du référentiel associée'));
    for (final id in notions) {
      final n = lib.byId[id];
      if (n == null) {
        issues.add(Issue(where, 'notion inconnue : $id'));
      } else if (!n.inProgramme) {
        issues.add(Issue(where, 'la notion $id est « ${n.status} » : contenu interdit par le référentiel'));
      }
    }
  }

  void checkBlocks(String where, List<Block> blocks, {bool templatesAllowed = false}) {
    for (final b in blocks) {
      if (!Block.types.contains(b.type)) issues.add(Issue(where, 'type de bloc inconnu : ${b.type}'));
      for (final s in b.strings) {
        for (final t in forbiddenTerms) {
          if (s.contains(t)) issues.add(Issue(where, 'terme hors périmètre « $t »', error: false));
        }
        if (!templatesAllowed && hasTemplate(s)) issues.add(Issue(where, 'modèle [[…]] hors d\'un exercice'));
        if (_dollarCount(s).isOdd) issues.add(Issue(where, 'formule \$…\$ non refermée : ${_short(s)}'));
      }
      if (b.type == 'plot') {
        final curves = b.data['curves'];
        if (curves is! List || curves.isEmpty) {
          issues.add(Issue(where, 'courbe sans tracé'));
        } else {
          for (final c in curves) {
            try {
              parseExpr((c as Map)['expr'] as String);
            } on ExprError catch (e) {
              issues.add(Issue(where, 'courbe illisible : ${e.message}'));
            }
          }
        }
      }
      if (b.type == 'circuit') {
        final parts = b.data['parts'];
        if (parts is! List || parts.isEmpty) issues.add(Issue(where, 'schéma sans composant'));
      }
    }
  }

  for (final c in lib.courses) {
    final w = 'cours ${c.id}';
    if (!contentIds.add(c.id)) issues.add(Issue(w, 'identifiant en double'));
    checkNotions(w, c.notions);
    if (c.blocks.isEmpty) issues.add(Issue(w, 'cours vide'));
    checkBlocks(w, c.blocks);
  }
  for (final e in lib.examples) {
    final w = 'exemple ${e.id}';
    if (!contentIds.add(e.id)) issues.add(Issue(w, 'identifiant en double'));
    checkNotions(w, e.notions);
    if (e.solution.isEmpty) issues.add(Issue(w, 'exemple sans corrigé'));
    checkBlocks(w, [...e.problem, ...e.solution]);
  }
  for (final x in lib.exercises) {
    final w = 'exercice ${x.id}';
    if (!contentIds.add(x.id)) issues.add(Issue(w, 'identifiant en double'));
    checkNotions(w, x.notions);
    if (x.questions.isEmpty) issues.add(Issue(w, 'aucune question'));
    if (x.solution.isEmpty) issues.add(Issue(w, 'pas de corrigé'));
    if (x.difficulty < 1 || x.difficulty > 3) issues.add(Issue(w, 'difficulté hors 1–3'));
    checkBlocks(w, [...x.statement, ...x.solution], templatesAllowed: true);
    for (final q in x.questions) {
      if (!Question.kinds.contains(q.kind)) issues.add(Issue(w, 'question ${q.id} : type inconnu ${q.kind}'));
      if (q.kind == 'choice') {
        if (q.choices.length < 2) issues.add(Issue(w, 'question ${q.id} : moins de 2 propositions'));
        if (q.correct == null || q.correct! < 0 || q.correct! >= q.choices.length) {
          issues.add(Issue(w, 'question ${q.id} : bonne proposition invalide'));
        }
        if (q.choices.toSet().length != q.choices.length) issues.add(Issue(w, 'question ${q.id} : propositions en double'));
      } else if (q.answer == null || q.answer!.trim().isEmpty) {
        issues.add(Issue(w, 'question ${q.id} : réponse attendue manquante'));
      }
    }
    // Tirages : chaque corrigé doit se calculer, chaque modèle se remplir.
    final seen = <String>{};
    final flagged = <String>{};
    for (var s = 0; s < seeds; s++) {
      try {
        final inst = generate(x, s);
        final texts = <String>[
          for (final b in [...x.statement, ...x.solution]) ...b.strings,
          x.hint,
          x.method,
          for (final q in x.questions) ...[q.prompt, ...q.choices],
        ];
        for (final t in texts) {
          final r = inst.render(t);
          if (hasTemplate(r)) issues.add(Issue(w, 'modèle non remplacé : ${_short(r)}'));
          if (r.contains('NaN') || r.contains('Infinity')) issues.add(Issue(w, 'valeur non définie dans : ${_short(r)}'));
        }
        for (final b in [...x.statement, ...x.solution]) {
          if (b.type == 'plot') _checkPlot(b, inst, w, issues);
        }
        for (final q in x.questions.where((q) => q.kind == 'choice')) {
          final rendered = [for (final c in q.choices) inst.render(c)];
          if (rendered.toSet().length != rendered.length) {
            issues.add(Issue(w, 'question ${q.id} : deux propositions identiques au tirage $s'));
          }
        }
        // corrigé auto-cohérent : la réponse attendue, saisie telle qu'affichée, est acceptée
        for (final q in x.questions.where((q) => q.kind != 'choice')) {
          final shown = formatExpected(q, inst.expected[q.id]!);
          final v = check(q, inst.expected[q.id]!, shown);
          if (!v.correct && flagged.add('refus-${q.id}')) {
            issues.add(Issue(w, 'question ${q.id} : la réponse affichée « $shown » serait refusée (tirage $s)'));
          }
        }
        seen.add(inst.env.entries.map((e) => '${e.key}=${e.value}').join(';'));
      } on Object catch (e) {
        issues.add(Issue(w, 'tirage $s impossible : $e'));
        break;
      }
    }
    if (x.params.isNotEmpty && seen.length < 3) {
      issues.add(Issue(w, 'moins de 3 énoncés différents sur $seeds tirages', error: false));
    }
  }
  // dédoublonne les messages répétés à chaque tirage
  final unique = <String, Issue>{};
  for (final i in issues) {
    unique.putIfAbsent('${i.where}|${i.message.replaceAll(RegExp(r'\(tirage \d+\)|au tirage \d+'), '')}', () => i);
  }
  return unique.values.toList();
}

void _checkPlot(Block b, ExerciseInstance inst, String w, List<Issue> issues) {
  final v = (b.data['var'] ?? 't') as String;
  final a = plotBound(b.data['from'], inst.env) ?? 0, z = plotBound(b.data['to'], inst.env);
  if (z == null || !(z > a)) {
    issues.add(Issue(w, 'courbe : intervalle invalide'));
    return;
  }
  for (final c in b.data['curves'] as List) {
    final e = parseExpr((c as Map)['expr'] as String);
    for (var k = 0; k <= 20; k++) {
      final t = a + (z - a) * k / 20;
      final y = e.eval({...inst.env, v: Complex(t)});
      if (!y.isFinite) {
        issues.add(Issue(w, 'courbe non définie en $v = $t'));
        return;
      }
    }
  }
}

/// Borne d'un tracé : nombre, ou expression des paramètres (ex. « 2/f »).
double? plotBound(Object? v, Map<String, Complex> env) {
  if (v is num) return v.toDouble();
  if (v is String) {
    try {
      return parseExpr(v).eval(env).re;
    } on ExprError {
      return null;
    }
  }
  return null;
}

int _dollarCount(String s) => RegExp(r'(?<!\\)\$').allMatches(s).length;
String _short(String s) => s.length > 70 ? '${s.substring(0, 70)}…' : s;

/// Rapport lisible : erreurs, alertes, couverture.
String report(Library lib, List<Issue> issues) {
  final cov = computeCoverage(lib);
  final b = StringBuffer();
  final errs = issues.where((i) => i.error).toList(), warns = issues.where((i) => !i.error).toList();
  b.writeln('Contenu : ${lib.courses.length} cours, ${lib.examples.length} exemples, ${lib.exercises.length} exercices');
  b.writeln('Référentiel : ${lib.notions.length} lignes, ${cov.total} notions au programme');
  for (final s in CoverageState.values) {
    b.writeln('  ${s.label.padRight(24)} ${cov.count(s)}');
  }
  b.writeln('  Inventaire à vérifier     ${cov.inventoryToCheck}');
  b.writeln('Couverture : ${(cov.ratio * 100).floor()} %');
  b.writeln('Erreurs : ${errs.length} · alertes : ${warns.length}');
  for (final i in [...errs, ...warns]) {
    b.writeln('  $i');
  }
  return b.toString();
}
