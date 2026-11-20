import 'package:coach_core/coach_core.dart';
import 'package:electro_coach/screens/exam_screen.dart';
import 'package:electro_coach/screens/exercise_screen.dart';
import 'package:electro_coach/screens/home_shell.dart';
import 'package:electro_coach/screens/notion_screen.dart';
import 'package:electro_coach/screens/settings_screen.dart';
import 'package:electro_coach/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  late AppState s;
  setUp(() async => s = await realState());

  Future<void> phone(WidgetTester t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(412, 915);
    addTearDown(t.view.reset);
  }

  testWidgets('accueil : reprise du parcours et matières', (t) async {
    await phone(t);
    await t.pumpWidget(wrap(s, const HomeShell()));
    await t.pumpAndSettle();
    expect(find.text('Reprendre mon parcours'), findsOneWidget);
    expect(find.text('Maths'), findsOneWidget);
    expect(find.textContaining('Sciences'), findsWidgets);
  });

  testWidgets('les quatre onglets s\'affichent sans erreur', (t) async {
    await phone(t);
    await t.pumpWidget(wrap(s, const HomeShell()));
    await t.pumpAndSettle();
    for (final tab in ['Parcours', 'Cours', 'Progression', 'Accueil']) {
      await t.tap(find.text(tab).last);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: tab);
    }
    await t.tap(find.text('Progression').last);
    await t.pumpAndSettle();
    final label = find.text('Couverture du programme officiel'.toUpperCase());
    await t.scrollUntilVisible(label, 200, scrollable: find.byType(Scrollable).hitTestable().first, maxScrolls: 60);
    expect(label, findsOneWidget);
  });

  testWidgets('parcours : changement d\'année', (t) async {
    await phone(t);
    await t.pumpWidget(wrap(s, const HomeShell()));
    await t.pumpAndSettle();
    await t.tap(find.text('Parcours').last);
    await t.pumpAndSettle();
    await t.tap(find.text('2e année').first);
    await t.pumpAndSettle();
    expect(s.year, 2);
    expect(find.text('Séries de Fourier'), findsOneWidget);
  });

  testWidgets('cours : tableau, schéma et courbe se dessinent', (t) async {
    await phone(t);
    await t.pumpWidget(wrap(s, NotionScreen(notion: s.library.byId['S-EL-10']!)));
    await t.pumpAndSettle();
    expect(find.text('Impédances en régime sinusoïdal'), findsOneWidget);
    await t.drag(find.byType(ListView).first, const Offset(0, -2500));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(s.progress.coursesRead, contains('C-EL-10'));
  });

  testWidgets('notion hors programme : référentiel affiché sans cours', (t) async {
    await phone(t);
    await t.pumpWidget(wrap(s, NotionScreen(notion: s.library.byId['M-CV-X1']!)));
    await t.pumpAndSettle();
    expect(find.text('Le cours de cette notion est en préparation.'), findsOneWidget);
    expect(find.text('Ce que demande le référentiel'), findsOneWidget);
  });

  testWidgets('toutes les notions au programme ont un cours qui s\'affiche', (t) async {
    await phone(t);
    for (final id in ['S-QE-03', 'S-PR-07', 'S-MO-06', 'S-CH-03', 'M-SF-03']) {
      await t.pumpWidget(wrap(s, NotionScreen(notion: s.library.byId[id]!)));
      await t.pumpAndSettle();
      expect(find.text('Le cours de cette notion est en préparation.'), findsNothing, reason: id);
      expect(t.takeException(), isNull, reason: id);
    }
  });

  testWidgets('examen blanc : accueil des épreuves', (t) async {
    await phone(t);
    await t.pumpWidget(wrap(s, const ExamHomeScreen()));
    await t.pumpAndSettle();
    expect(find.text('Mathématiques'), findsOneWidget);
    expect(find.text('Commencer l\'épreuve'), findsNWidgets(2));
  });

  testWidgets('examen blanc : copie parfaite → 20/20 enregistré', (t) async {
    await phone(t);
    final d = drawExam(s.library, ExamKind.maths, 7);
    await t.pumpWidget(wrap(s, const ExamRunScreen(kind: ExamKind.maths, seed: 7, timed: false)));
    await t.pumpAndSettle();
    // On remplit la copie par l'état de l'écran (la liste est paresseuse).
    final st = t.state(find.byType(ExamRunScreen)) as dynamic;
    for (final p in d.parts) {
      for (final q in p.exercise.questions) {
        final key = '${p.exercise.id}/${q.id}';
        final v = p.expected[q.id]!;
        if (q.kind == 'choice') {
          st.choices[key] = v.re.round();
        } else {
          (st.controllers[key] as TextEditingController).text = formatExpected(q, v);
        }
      }
    }
    await reveal(t, find.text('Rendre ma copie'));
    await t.tap(find.text('Rendre ma copie'));
    await t.pumpAndSettle();
    await t.tap(find.text('Rendre'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(s.examLast(ExamKind.maths), 20, reason: 'copie parfaite');
    expect(s.examCount(ExamKind.maths), 1);
    expect((st.score as ExamScore).on20, 20);
  });

  testWidgets('examen blanc : copie blanche → 0/20 et corrigés visibles', (t) async {
    await phone(t);
    await t.pumpWidget(wrap(s, const ExamRunScreen(kind: ExamKind.sciences, seed: 2, timed: false)));
    await t.pumpAndSettle();
    await reveal(t, find.text('Rendre ma copie'));
    await t.tap(find.text('Rendre ma copie'));
    await t.pumpAndSettle();
    expect(find.textContaining('sans réponse'), findsOneWidget);
    await t.tap(find.text('Rendre'));
    await t.pumpAndSettle();
    expect(s.examLast(ExamKind.sciences), 0);
    expect(find.textContaining('Réponse attendue'), findsWidgets);
  });

  testWidgets('examen blanc chronométré : le temps défile', (t) async {
    await phone(t);
    await t.pumpWidget(wrap(s, const ExamRunScreen(kind: ExamKind.maths, seed: 1)));
    await t.pump();
    expect(find.text('2:00:00'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(find.text('1:59:57'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('exercice : bonnes réponses saisies → réussite enregistrée', (t) async {
    await phone(t);
    final ex = s.library.exercise('X-EL-10-a')!;
    final inst = generate(ex, 3);
    await t.pumpWidget(wrap(s, ExerciseScreen(exercise: ex, seed: 3)));
    await t.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    for (final (i, q) in ex.questions.indexed) {
      await t.enterText(fields.at(i), formatExpected(q, inst.expected[q.id]!));
    }
    await reveal(t, find.text('Valider ma réponse'));
    await t.tap(find.text('Valider ma réponse'));
    await t.pumpAndSettle();
    final messages = [
      for (final w in t.widgetList<Text>(find.byType(Text)))
        if ((w.data ?? '').contains('réponse') || (w.data ?? '').contains('attendue') || (w.data ?? '').contains('Unité')) w.data
    ];
    final typed = [for (final w in t.widgetList<TextField>(find.byType(TextField))) w.controller?.text];
    expect(s.progress.attempts['X-EL-10-a']?.last.correct, isTrue, reason: 'saisies $typed → $messages');
    expect(s.progress.boxes['S-EL-10'], 1);
    await reveal(t, find.text('Bravo, tout est juste !'));
    expect(find.text('Bravo, tout est juste !'), findsOneWidget);
    await reveal(t, find.text('Voir le corrigé'));
    await t.tap(find.text('Voir le corrigé'));
    await t.pumpAndSettle();
    expect(find.textContaining('Réponse attendue'), findsWidgets);
  });

  testWidgets('exercice : mauvaise unité signalée', (t) async {
    await phone(t);
    final ex = s.library.exercise('X-EL-10-a')!;
    await t.pumpWidget(wrap(s, ExerciseScreen(exercise: ex, seed: 3)));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, '12 V');
    await reveal(t, find.text('Valider ma réponse'));
    await t.tap(find.text('Valider ma réponse'));
    await t.pumpAndSettle();
    expect(find.textContaining('Unité incorrecte'), findsOneWidget);
    expect(s.progress.boxes['S-EL-10'] ?? 0, 0);
  });

  testWidgets('exercice à QCM : choix puis validation', (t) async {
    await phone(t);
    final ex = s.library.exercise('X-EL-10-b')!;
    await t.pumpWidget(wrap(s, ExerciseScreen(exercise: ex, seed: 1)));
    await t.pumpAndSettle();
    await reveal(t, find.text('en retard'));
    await t.tap(find.text('en retard'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('réglages : répartition modifiable', (t) async {
    await phone(t);
    await t.pumpWidget(wrap(s, const SplitScreen()));
    await t.pumpAndSettle();
    expect(find.text('Calcul et numération'), findsOneWidget);
    await s.setYearFor('Maîtrise des procédés', 1);
    expect(s.parcours.yearOf(s.library.byId['S-PR-01']!), 1);
  });
}
