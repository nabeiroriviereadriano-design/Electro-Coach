import 'models.dart';

/// État de couverture d'une notion du programme, déduit du contenu présent
/// (exigences 5 et 6 du cahier des charges).
enum CoverageState {
  /// Aucun contenu.
  notDeveloped('Non développé'),

  /// Il manque le cours ou il y a moins de 2 exercices.
  incomplete('Incomplet'),

  /// Cours + au moins 2 exercices, mais tout n'est pas relu et validé.
  integrated('Intégré – à vérifier'),

  /// Cours + au moins 2 exercices, tout validé, inventaire vérifié.
  conform('Conforme (vérifié)'),

  /// Notion dont le périmètre reste à trancher.
  toDecide('Périmètre à arbitrer');

  const CoverageState(this.label);
  final String label;
}

class NotionCoverage {
  NotionCoverage(this.notion, this.state, this.courses, this.examples, this.exercises);
  final Notion notion;
  final CoverageState state;
  final int courses, examples, exercises;
}

class CoverageReport {
  CoverageReport(this.items);
  final List<NotionCoverage> items;

  int count(CoverageState s) => items.where((i) => i.state == s).length;
  int get total => items.length;

  /// Lignes d'inventaire encore à vérifier sur le texte officiel.
  int get inventoryToCheck => items.where((i) => !i.notion.inventoryChecked).length;

  /// Part des notions conformes. Jamais 100 % tant qu'il reste une notion
  /// non conforme, une ligne d'inventaire à vérifier ou un périmètre à trancher.
  double get ratio {
    if (total == 0) return 0;
    final r = count(CoverageState.conform) / total;
    final blocked = inventoryToCheck > 0 || count(CoverageState.toDecide) > 0;
    if (r >= 1 && blocked) return 0.99;
    if (r >= 1) return 1;
    // 100 % affiché seulement quand tout est réellement conforme
    return r > 0.99 ? 0.99 : r;
  }

  /// Part des notions dont le cours et au moins 2 exercices sont écrits
  /// (vérifiés ou non). Plafonnée à 99 % tant qu'il manque quelque chose.
  double get integratedRatio {
    if (total == 0) return 0;
    final n = count(CoverageState.integrated) + count(CoverageState.conform);
    final r = n / total;
    return n < total && r > 0.99 ? 0.99 : r;
  }

  CoverageReport only(bool Function(Notion) keep) => CoverageReport([for (final i in items) if (keep(i.notion)) i]);
}

CoverageReport computeCoverage(Library lib) {
  final out = <NotionCoverage>[];
  for (final n in lib.notions) {
    if (!n.inProgramme) continue;
    final c = lib.coursesFor(n.id).toList();
    final ex = lib.examplesFor(n.id).toList();
    final x = lib.exercisesFor(n.id).toList();
    CoverageState s;
    if (n.status == NotionStatus.toDecide) {
      s = CoverageState.toDecide;
    } else if (c.isEmpty && ex.isEmpty && x.isEmpty) {
      s = CoverageState.notDeveloped;
    } else if (c.isEmpty || x.length < 2) {
      s = CoverageState.incomplete;
    } else {
      final allValidated = c.every((e) => e.validated) && ex.every((e) => e.validated) && x.every((e) => e.validated);
      s = allValidated && n.inventoryChecked ? CoverageState.conform : CoverageState.integrated;
    }
    out.add(NotionCoverage(n, s, c.length, ex.length, x.length));
  }
  return CoverageReport(out);
}
