import 'dart:io';

import 'package:coach_core/coach_core.dart';
import 'package:test/test.dart';

const contentDir = '../../app/assets/content';

Library loadReal() {
  final notions = File('$contentDir/notions.json').readAsStringSync();
  final packs = Directory('$contentDir/packs')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .map((f) => f.readAsStringSync());
  return loadLibrary(notions, packs);
}

void main() {
  final lib = loadReal();

  test('le référentiel est complet', () {
    expect(lib.notions.length, 175);
    expect(lib.notions.where((n) => n.inProgramme).length, 163);
    expect(lib.byId['M-CV-X2']!.inProgramme, isFalse);
    expect(lib.byId['S-PR-08']!.status, NotionStatus.toDecide);
  });

  test('tout le contenu est valide (corrigés recalculés sur 50 tirages)', () {
    final issues = validate(lib);
    final errors = issues.where((i) => i.error).toList();
    // ignore: avoid_print
    print(report(lib, issues));
    expect(errors, isEmpty, reason: errors.join('\n'));
  });

  test('chaque pack listé dans index.json existe', () {
    final idx = File('$contentDir/index.json').readAsStringSync();
    for (final m in RegExp(r'"(packs/[^"]+)"').allMatches(idx)) {
      expect(File('$contentDir/${m.group(1)}').existsSync(), isTrue, reason: m.group(1));
    }
  });

  group('moteur d\'exercices', () {
    final ex = lib.exercise('X-EL-10-a')!;

    test('un même tirage donne le même énoncé', () {
      final a = generate(ex, 7), b = generate(ex, 7);
      expect(a.env.toString(), b.env.toString());
      expect(a.render(ex.statement.first.text), b.render(ex.statement.first.text));
    });

    test('les tirages varient', () {
      final s = {for (var i = 0; i < 30; i++) generate(ex, i).env['Z'].toString()};
      expect(s.length, greaterThan(5));
    });

    test('correction : valeur, unité, préfixe, tolérance', () {
      final inst = generate(ex, 3);
      final q = ex.questions.firstWhere((q) => q.id == 'q3'); // intensité en A
      final exp = inst.expected['q3']!.re;
      expect(check(q, inst.expected['q3']!, '${exp.toStringAsFixed(4).replaceAll('.', ',')} A').correct, isTrue);
      expect(check(q, inst.expected['q3']!, '${(exp * 1000).toStringAsFixed(1)} mA').correct, isTrue);
      expect(check(q, inst.expected['q3']!, '${exp * 1.5} A').correct, isFalse);
      expect(check(q, inst.expected['q3']!, '$exp V').correct, isFalse);
      expect(check(q, inst.expected['q3']!, '$exp').message, contains('unité'));
    });

    test('réponse complexe sous plusieurs formes', () {
      final x = lib.exercise('X-NC-04-b')!;
      final inst = generate(x, 1);
      final z = inst.expected['q1']!;
      final q = x.questions.first;
      expect(check(q, z, '${z.re} + (${z.im})j').correct, isTrue);
      expect(check(q, z, '${z.abs}∠${z.arg}').correct, isTrue);
      expect(check(q, z, '${z.re} - (${z.im})j').correct, isFalse);
    });

    test('modèles dans une formule : valeurs compatibles LaTeX', () {
      final env = {'R': const Complex(4700), 'x': const Complex(-2.5)};
      expect(renderTemplate(r'$R = [[R]]$', env, units: {'R': 'Ω'}), r'$R = 4{,}7\ k\Omega$');
      expect(renderTemplate('x vaut [[x]]', env), 'x vaut −2,5');
    });

    test('QCM : ordre mélangé mais reproductible', () {
      final x = lib.exercise('X-NC-01-a')!;
      final q = x.questions.firstWhere((q) => q.kind == 'choice');
      final orders = {for (var s = 0; s < 20; s++) choiceOrder(generate(x, s), q).join()};
      expect(orders.length, greaterThan(1));
      expect(choiceOrder(generate(x, 4), q), choiceOrder(generate(x, 4), q));
    });
  });

  group('couverture', () {
    test('le contenu de démonstration n\'est pas « conforme » (non relu)', () {
      final c = computeCoverage(lib);
      expect(c.total, 163);
      expect(c.count(CoverageState.conform), 0);
      expect(c.ratio, 0);
      final s = c.items.firstWhere((i) => i.notion.id == 'S-EL-10');
      expect(s.state, CoverageState.integrated);
    });

    test('jamais 100 % tant qu\'une ligne reste à vérifier', () {
      final notions = [
        Notion(id: 'A', subject: 'Mathématiques', domain: 'D', chapter: '', title: 'a', year: 1, status: 'Non développé',
            skills: '', formulas: '', prerequisites: const [], reference: '', inventoryChecked: false, remark: ''),
      ];
      final course = Course(id: 'c', notions: const ['A'], title: 't', blocks: [Block('text', {'text': 'x'})], validated: true);
      Exercise ex(String id) => Exercise(id: id, notions: const ['A'], title: id, difficulty: 1, params: const {}, vars: const [],
          constraints: const [], statement: const [], questions: const [], hint: '', method: '', solution: const [], validated: true);
      final lib2 = Library(notions, [ContentPack(id: 'p', courses: [course], examples: const [], exercises: [ex('1'), ex('2')])]);
      final c = computeCoverage(lib2);
      expect(c.items.single.state, CoverageState.integrated); // inventaire non vérifié
      expect(c.ratio, lessThan(1));
    });
  });

  group('progression et parcours', () {
    test('boîtes de révision et sauvegarde', () {
      final p = ProgressState();
      final ex = lib.exercise('X-NC-01-a')!;
      p.recordAttempt(ex, 1, true);
      p.recordAttempt(ex, 2, true);
      p.recordAttempt(ex, 3, false);
      expect(p.boxes['M-NC-01'], 1);
      final back = ProgressState.decode(p.encode());
      expect(back.boxes['M-NC-01'], 1);
      expect(back.attempts['X-NC-01-a']!.length, 3);
      expect(ProgressState.decode('{pas du json').boxes, isEmpty);
    });

    test('répartition : référentiel, défaut, choix de l\'utilisateur', () {
      final parcours = Parcours.fromJson({
        'defaults': {'Énergie et électricité': 1, 'Énergie et électricité / Transformateurs': 2}
      });
      expect(parcours.yearOf(lib.byId['M-SF-03']!), 2); // référentiel
      expect(parcours.yearOf(lib.byId['S-EL-10']!), 1); // défaut du domaine
      expect(parcours.yearOf(lib.byId['S-MO-05']!), 2); // défaut du chapitre
      parcours.overrides['Énergie et électricité'] = 2;
      expect(parcours.yearOf(lib.byId['S-EL-10']!), 2);
      expect(parcours.isDefaultGuess(lib.byId['M-SF-03']!), isFalse);
    });

    test('notion suivante conseillée', () {
      final parcours = Parcours.fromJson({'defaults': {'Énergie et électricité': 1}});
      final p = ProgressState();
      final first = p.nextNotion(lib, parcours)!;
      expect(lib.hasContent(first.id), isTrue);
      expect(parcours.yearOf(first), 1);
      p.boxes[first.id] = 3;
      final second = p.nextNotion(lib, parcours)!;
      expect(second.id, isNot(first.id));
      expect(lib.hasContent(second.id), isTrue);
    });
  });
}
