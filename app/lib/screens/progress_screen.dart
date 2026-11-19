import 'package:coach_core/coach_core.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Progression de l'étudiant et couverture du programme par l'application.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final n = context.nn;
    final lib = s.library;
    final year = s.notionsOfYear(s.year);
    final cov = s.coverage;
    return PageBody(children: [
      const DotTitle('Progression', size: 26),
      const SizedBox(height: 14),
      AppCard(
        child: Row(children: [
          ProgressRing(value: s.progress.masteryOf(year, lib), size: 104, caption: 'maîtrise'),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final subject in Library.subjects) ...[
                Text(subject, style: TextStyle(color: n.mid, fontSize: 13)),
                const SizedBox(height: 6),
                ThinBar(value: s.progress.masteryOf(year.where((x) => x.subject == subject), lib)),
                const SizedBox(height: 12),
              ],
            ]),
          ),
        ]),
      ),
      SectionLabel('Par domaine — ${s.year == 1 ? '1re' : '2e'} année'),
      for (final subject in Library.subjects)
        for (final d in lib.domains(subject))
          if (year.any((x) => x.domain == d))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(d, style: const TextStyle(fontSize: 14))),
                  Text('${(s.progress.masteryOf(year.where((x) => x.domain == d), lib) * 100).round()} %',
                      style: TextStyle(color: n.mid, fontSize: 12.5, fontFamily: kFontMono)),
                ]),
                const SizedBox(height: 6),
                ThinBar(value: s.progress.masteryOf(year.where((x) => x.domain == d), lib)),
              ]),
            ),
      const SectionLabel('Couverture du programme officiel'),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ProgressRing(value: cov.ratio, size: 86, label: '${(cov.ratio * 100).floor()} %'),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Part des ${cov.total} notions au programme dont le cours et les exercices sont écrits et vérifiés. '
                'Ce chiffre n\'atteint jamais 100 % tant qu\'une notion reste incomplète ou à vérifier.',
                style: TextStyle(color: n.mid, fontSize: 13, height: 1.4),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          for (final st in CoverageState.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                RedDot(size: 8, color: st == CoverageState.conform ? NColors.red : (st == CoverageState.notDeveloped ? n.line : n.fg)),
                const SizedBox(width: 10),
                Expanded(child: Text(st.label, style: const TextStyle(fontSize: 13.5))),
                Text('${cov.count(st)}', style: const TextStyle(fontFamily: kFontMono, fontSize: 13.5)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              RedDot(size: 8, color: n.mid),
              const SizedBox(width: 10),
              const Expanded(child: Text('Inventaire à vérifier sur le texte officiel', style: TextStyle(fontSize: 13.5))),
              Text('${cov.inventoryToCheck}', style: const TextStyle(fontFamily: kFontMono, fontSize: 13.5)),
            ]),
          ),
        ]),
      ),
    ]);
  }
}
