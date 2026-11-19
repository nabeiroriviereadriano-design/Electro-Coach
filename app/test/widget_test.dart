import 'package:coach_core/coach_core.dart';
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
    expect(find.text('Couverture du programme officiel'.toUpperCase()), findsOneWidget);
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

  testWidgets('notion sans contenu : référentiel affiché', (t) async {
    await phone(t);
    await t.pumpWidget(wrap(s, NotionScreen(notion: s.library.byId['S-QE-03']!)));
    await t.pumpAndSettle();
    expect(find.text('Le cours de cette notion est en préparation.'), findsOneWidget);
    expect(find.text('Ce que demande le référentiel'), findsOneWidget);
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
    await t.ensureVisible(find.text('Valider ma réponse'));
    await t.tap(find.text('Valider ma réponse'));
    await t.pumpAndSettle();
    expect(find.text('Bravo, tout est juste !'), findsOneWidget);
    expect(s.progress.boxes['S-EL-10'], 1);
    await t.ensureVisible(find.text('Voir le corrigé'));
    await t.tap(find.text('Voir le corrigé'));
    await t.pumpAndSettle();
    expect(find.textContaining('Réponse attendue'), findsNWidgets(3));
  });

  testWidgets('exercice : mauvaise unité signalée', (t) async {
    await phone(t);
    final ex = s.library.exercise('X-EL-10-a')!;
    await t.pumpWidget(wrap(s, ExerciseScreen(exercise: ex, seed: 3)));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, '12 V');
    await t.ensureVisible(find.text('Valider ma réponse'));
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
    await t.ensureVisible(find.text('en retard'));
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
