// Captures d'écran de l'interface réelle (polices, icônes et formules chargées),
// générées en CI : flutter test --update-goldens screenshot_test/
import 'package:coach_core/coach_core.dart';
import 'package:electro_coach/screens/exercise_screen.dart';
import 'package:electro_coach/screens/home_shell.dart';
import 'package:electro_coach/screens/notion_screen.dart';
import 'package:electro_coach/screens/settings_screen.dart';
import 'package:electro_coach/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support.dart';

const phone = Size(412, 915);
const desktop = Size(1366, 860);

Future<void> shot(WidgetTester t, String name, Size size, Widget home, AppState s,
    {Brightness b = Brightness.dark, Future<void> Function(WidgetTester)? before}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  await t.pumpWidget(wrap(s, home, b: b));
  await t.pumpAndSettle();
  if (before != null) await before(t);
  await t.pumpAndSettle();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

void main() {
  late AppState s;
  setUpAll(loadFonts);
  setUp(() async {
    s = await realState();
    // un peu de progression pour des écrans vivants
    final ex = s.library.exercise('X-NC-01-a')!;
    s.progress.recordAttempt(ex, 1, true);
    s.progress.recordAttempt(ex, 2, true);
    s.progress.recordAttempt(s.library.exercise('X-NC-04-a')!, 1, true);
  });

  testWidgets('01-accueil', (t) => shot(t, '01-accueil', phone, const HomeShell(), s));
  testWidgets('02-parcours', (t) => shot(t, '02-parcours', phone, const HomeShell(), s, before: (t) async {
        await t.tap(find.text('Parcours').last);
      }));
  testWidgets('03-cours-complexes', (t) => shot(t, '03-cours-complexes', phone, NotionScreen(notion: s.library.byId['M-NC-01']!), s));
  testWidgets('04-cours-impedances', (t) => shot(t, '04-cours-impedances', phone, NotionScreen(notion: s.library.byId['S-EL-10']!), s,
          before: (t) async {
        await t.drag(find.byType(ListView).first, const Offset(0, -900));
      }));
  testWidgets('05-exercice', (t) => shot(t, '05-exercice', phone, ExerciseScreen(exercise: s.library.exercise('X-EL-10-a')!, seed: 3), s));
  testWidgets('06-exercice-corrige', (t) {
    final ex = s.library.exercise('X-NC-01-a')!;
    final inst = generate(ex, 5);
    return shot(t, '06-exercice-corrige', phone, ExerciseScreen(exercise: ex, seed: 5), s, before: (t) async {
      await t.enterText(find.byType(TextField).at(0), formatExpected(ex.questions[0], inst.expected['q1']!));
      await t.enterText(find.byType(TextField).at(1), '1 + j');
      await t.ensureVisible(find.text('Valider ma réponse'));
      await t.tap(find.text('Valider ma réponse'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Voir le corrigé'));
      await t.tap(find.text('Voir le corrigé'));
    });
  });
  testWidgets('07-progression', (t) => shot(t, '07-progression', phone, const HomeShell(), s, before: (t) async {
        await t.tap(find.text('Progression').last);
      }));
  testWidgets('08-reglages', (t) => shot(t, '08-reglages', phone, const SettingsScreen(), s));
  testWidgets('09-windows-cours', (t) => shot(t, '09-windows-cours', desktop, NotionScreen(notion: s.library.byId['S-EL-10']!), s));
  testWidgets('10-accueil-clair', (t) => shot(t, '10-accueil-clair', phone, const HomeShell(), s, b: Brightness.light));
}
