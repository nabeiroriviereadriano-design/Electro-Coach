import 'package:coach_core/coach_core.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'notion_screen.dart';
import 'settings_screen.dart';
import 'subjects_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenTab});
  final void Function(int) onOpenTab;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final n = context.nn;
    final lib = s.library;
    final yearNotions = s.notionsOfYear(s.year);
    final mastery = s.progress.masteryOf(yearNotions, lib);
    final next = s.progress.nextNotion(lib, s.parcours);
    final solved = s.progress.solvedCount();
    return PageBody(children: [
      Row(children: [
        const DotTitle('Accueil', size: 26),
        const SizedBox(width: 6),
        const RedDot(),
        const Spacer(),
        IconButton(
          tooltip: 'Réglages',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ]),
      const SizedBox(height: 14),
      AppCard(
        child: Row(children: [
          ProgressRing(value: mastery, size: 112, caption: s.year == 1 ? 'maîtrise\n1re année' : 'maîtrise\n2e année'),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Exercices réussis', style: TextStyle(color: n.mid, fontSize: 13)),
              Text('$solved', style: const TextStyle(fontFamily: kFontDot, fontWeight: FontWeight.w900, fontSize: 34)),
              const SizedBox(height: 6),
              Text('${yearNotions.length} notions au programme cette année', style: TextStyle(color: n.mid, fontSize: 13)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      if (next != null)
        AppCard(
          highlight: true,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotionScreen(notion: next))),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: NColors.red, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Reprendre mon parcours', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(next.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: n.mid, fontSize: 13)),
                const SizedBox(height: 8),
                ThinBar(value: s.progress.mastery(next.id)),
              ]),
            ),
          ]),
        ),
      const SectionLabel('Matières'),
      Row(children: [
        for (final subject in Library.subjects) ...[
          Expanded(
            child: AppCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SubjectScreen(subject: subject))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(subject == 'Mathématiques' ? Icons.functions : Icons.bolt, size: 30),
                const SizedBox(height: 18),
                Text(subject == 'Mathématiques' ? 'Maths' : 'Sciences\nappliquées',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, height: 1.2)),
                const SizedBox(height: 10),
                ThinBar(value: s.progress.masteryOf(lib.notions.where((x) => x.subject == subject && x.inProgramme), lib)),
              ]),
            ),
          ),
          if (subject != Library.subjects.last) const SizedBox(width: 12),
        ],
      ]),
      const SizedBox(height: 18),
      AppCard(
        onTap: () => onOpenTab(3),
        child: Row(children: [
          Icon(Icons.fact_check_outlined, color: n.mid),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Contenu en cours de rédaction : ${lib.courses.length} cours et ${lib.exercises.length} exercices pour l\'instant. '
              'Voir la couverture du programme.',
              style: TextStyle(color: n.mid, fontSize: 13),
            ),
          ),
          Icon(Icons.chevron_right, color: n.mid),
        ]),
      ),
    ]);
  }
}
