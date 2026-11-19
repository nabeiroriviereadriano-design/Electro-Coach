import 'package:coach_core/coach_core.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'notion_screen.dart';

/// Onglet « Cours » : les deux matières et leurs domaines.
class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return PageBody(children: [
      const DotTitle('Cours', size: 26),
      for (final subject in Library.subjects) ...[
        SectionLabel(subject),
        for (final d in s.library.domains(subject)) _DomainTile(domain: d),
      ],
    ]);
  }
}

/// Une matière seule (depuis l'accueil).
class SubjectScreen extends StatelessWidget {
  const SubjectScreen({super.key, required this.subject});
  final String subject;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(subject)),
      body: PageBody(children: [for (final d in s.library.domains(subject)) _DomainTile(domain: d)]),
    );
  }
}

class _DomainTile extends StatelessWidget {
  const _DomainTile({required this.domain});
  final String domain;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final n = context.nn;
    final notions = s.library.notionsOf(domain);
    if (notions.isEmpty) return const SizedBox.shrink();
    final withContent = notions.where((x) => s.library.hasContent(x.id)).length;
    final m = s.progress.masteryOf(notions, s.library);
    final years = notions.map(s.parcours.yearOf).whereType<int>().toSet().toList()..sort();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DomainScreen(domain: domain))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(domain, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5))),
            for (final y in years)
              Padding(padding: const EdgeInsets.only(left: 6), child: Pill(y == 1 ? '1re' : '2e')),
          ]),
          const SizedBox(height: 4),
          Text('${notions.length} notions · $withContent avec contenu', style: TextStyle(color: n.mid, fontSize: 13)),
          const SizedBox(height: 10),
          ThinBar(value: m),
        ]),
      ),
    );
  }
}

/// Les notions d'un domaine, groupées par chapitre.
class DomainScreen extends StatelessWidget {
  const DomainScreen({super.key, required this.domain});
  final String domain;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final notions = s.library.notionsOf(domain);
    final chapters = <String, List<Notion>>{};
    for (final x in notions) {
      chapters.putIfAbsent(x.chapter, () => []).add(x);
    }
    return Scaffold(
      appBar: AppBar(title: Text(domain)),
      body: PageBody(children: [
        for (final e in chapters.entries) ...[
          SectionLabel(e.key),
          for (final x in e.value) NotionTile(notion: x),
        ],
      ]),
    );
  }
}

/// Ligne d'une notion : titre, maîtrise, contenu disponible.
class NotionTile extends StatelessWidget {
  const NotionTile({super.key, required this.notion, this.dense = false});
  final Notion notion;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final n = context.nn;
    final has = s.library.hasContent(notion.id);
    final m = s.progress.mastery(notion.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotionScreen(notion: notion))),
        child: Row(children: [
          RedDot(size: 10, color: has ? masteryColor(context, m) : n.line),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(notion.title, style: TextStyle(fontSize: 14.5, color: has ? n.fg : n.mid)),
              if (!has)
                Text('Contenu en préparation', style: TextStyle(fontSize: 12, color: n.mid))
              else
                Text('${s.library.coursesFor(notion.id).length} cours · ${s.library.exercisesFor(notion.id).length} exercices',
                    style: TextStyle(fontSize: 12, color: n.mid)),
            ]),
          ),
          if (notion.status == NotionStatus.toDecide) const Pill('à arbitrer'),
          Icon(Icons.chevron_right, color: n.mid),
        ]),
      ),
    );
  }
}
