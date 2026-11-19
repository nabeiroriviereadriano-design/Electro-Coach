import 'package:coach_core/coach_core.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'notion_screen.dart';

/// Parcours de l'année : les notions dans l'ordre, domaine par domaine.
class ParcoursScreen extends StatelessWidget {
  const ParcoursScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final n = context.nn;
    final notions = s.notionsOfYear(s.year);
    final bySubject = <String, Map<String, List<Notion>>>{};
    for (final x in notions) {
      bySubject.putIfAbsent(x.subject, () => {}).putIfAbsent(x.domain, () => []).add(x);
    }
    final next = s.progress.nextNotion(s.library, s.parcours);
    return PageBody(children: [
      const DotTitle('Mon parcours', size: 26),
      const SizedBox(height: 14),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 1, label: Text('1re année')),
          ButtonSegment(value: 2, label: Text('2e année')),
        ],
        selected: {s.year},
        showSelectedIcon: false,
        onSelectionChanged: (v) => s.setYear(v.first),
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: n.invertedBg,
          selectedForegroundColor: n.invertedFg,
          side: BorderSide(color: n.line),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        s.year == 1
            ? 'Reprise des prérequis, fondamentaux et premières notions du BTS.'
            : 'Approfondissement, problèmes contextualisés et entraînement aux épreuves.',
        style: TextStyle(color: n.mid, fontSize: 13),
      ),
      for (final subject in Library.subjects)
        if (bySubject[subject] != null) ...[
          SectionLabel(subject),
          for (final e in bySubject[subject]!.entries) _DomainTimeline(domain: e.key, notions: e.value, next: next),
        ],
      if (notions.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text('Aucune notion dans cette année. Vérifie la répartition dans les réglages.',
              textAlign: TextAlign.center, style: TextStyle(color: n.mid)),
        ),
    ]);
  }
}

class _DomainTimeline extends StatelessWidget {
  const _DomainTimeline({required this.domain, required this.notions, required this.next});
  final String domain;
  final List<Notion> notions;
  final Notion? next;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final n = context.nn;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(domain, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
          const SizedBox(height: 8),
          for (final (i, x) in notions.indexed)
            InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotionScreen(notion: x))),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    width: 22,
                    child: Column(children: [
                      Container(width: 1.5, height: 10, color: i == 0 ? Colors.transparent : n.line),
                      _Node(state: _stateOf(s, x), current: next?.id == x.id),
                      Expanded(child: Container(width: 1.5, color: i == notions.length - 1 ? Colors.transparent : n.line)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(
                        x.title,
                        style: TextStyle(
                          fontSize: 14,
                          color: s.library.hasContent(x.id) ? n.fg : n.mid,
                          fontWeight: next?.id == x.id ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  static int _stateOf(AppState s, Notion x) {
    if (!s.library.hasContent(x.id)) return 0;
    final m = s.progress.mastery(x.id);
    if (m >= 0.6) return 3;
    if (m > 0) return 2;
    return 1;
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.state, required this.current});
  final int state; // 0 sans contenu, 1 à faire, 2 en cours, 3 maîtrisé
  final bool current;
  @override
  Widget build(BuildContext context) {
    final n = context.nn;
    final size = current ? 16.0 : 12.0;
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: state == 3 ? NColors.red : (state == 2 ? n.fg : Colors.transparent),
        border: Border.all(color: current ? NColors.red : (state == 0 ? n.line : n.fg), width: current ? 2.5 : 1.5),
      ),
      child: state == 3 ? const Icon(Icons.check, size: 9, color: Colors.white) : null,
    );
  }
}
