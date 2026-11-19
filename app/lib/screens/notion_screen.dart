import 'package:coach_core/coach_core.dart';
import 'package:flutter/material.dart';

import '../render/blocks.dart';
import '../render/rich_content.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'exercise_screen.dart';

/// Une notion du référentiel : cours, exemples corrigés, exercices.
class NotionScreen extends StatelessWidget {
  const NotionScreen({super.key, required this.notion});
  final Notion notion;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final lib = s.library;
    final courses = lib.coursesFor(notion.id).toList();
    final examples = lib.examplesFor(notion.id).toList();
    final exercises = lib.exercisesFor(notion.id).toList();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(notion.domain, style: const TextStyle(fontSize: 16)),
          bottom: TabBar(
            indicatorColor: NColors.red,
            labelColor: context.nn.fg,
            unselectedLabelColor: context.nn.mid,
            dividerColor: context.nn.line,
            tabs: [
              Tab(text: 'Cours${courses.isEmpty ? '' : ' (${courses.length})'}'),
              Tab(text: 'Exemples${examples.isEmpty ? '' : ' (${examples.length})'}'),
              Tab(text: 'Exercices${exercises.isEmpty ? '' : ' (${exercises.length})'}'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _CoursesTab(notion: notion, courses: courses),
          _ExamplesTab(notion: notion, examples: examples),
          _ExercisesTab(notion: notion, exercises: exercises),
        ]),
      ),
    );
  }
}

/// Ce que dit le référentiel (toujours visible, même sans contenu).
class ReferentielCard extends StatelessWidget {
  const ReferentielCard({super.key, required this.notion});
  final Notion notion;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final n = context.nn;
    final y = s.parcours.yearOf(notion);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(notion.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, height: 1.3)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Pill(notion.id),
          Pill(y == null ? 'année à choisir' : (y == 1 ? '1re année' : '2e année')),
          if (y != null && s.parcours.isDefaultGuess(notion)) const Pill('répartition proposée'),
          if (notion.status == NotionStatus.toDecide) const Pill('périmètre à arbitrer', color: NColors.red),
        ]),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 6),
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text('Ce que demande le référentiel', style: TextStyle(fontSize: 13.5, color: n.mid)),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notion.skills.isNotEmpty) RichContent(notion.skills, style: const TextStyle(fontSize: 14, height: 1.45)),
            if (notion.formulas.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(notion.formulas, style: const TextStyle(fontFamily: kFontMono, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            Text(notion.reference, style: TextStyle(fontSize: 12, color: n.mid)),
            if (notion.remark.isNotEmpty) Text(notion.remark, style: TextStyle(fontSize: 12, color: n.mid)),
          ],
        ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Icon(Icons.edit_note, size: 40, color: context.nn.mid),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.nn.mid)),
        ]),
      );
}

class _CoursesTab extends StatefulWidget {
  const _CoursesTab({required this.notion, required this.courses});
  final Notion notion;
  final List<Course> courses;
  @override
  State<_CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<_CoursesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = AppScope.of(context);
      for (final c in widget.courses) {
        s.markRead(c);
      }
    });
  }

  @override
  Widget build(BuildContext context) => PageBody(children: [
        ReferentielCard(notion: widget.notion),
        const SizedBox(height: 18),
        if (widget.courses.isEmpty) const _Empty('Le cours de cette notion est en préparation.'),
        for (final c in widget.courses) ...[
          Text(c.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, height: 1.25)),
          if (!c.validated)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text('Cours non encore relu', style: TextStyle(fontSize: 12, color: context.nn.mid)),
            ),
          const SizedBox(height: 12),
          BlockList(c.blocks),
          const SizedBox(height: 18),
        ],
      ]);
}

class _ExamplesTab extends StatelessWidget {
  const _ExamplesTab({required this.notion, required this.examples});
  final Notion notion;
  final List<WorkedExample> examples;
  @override
  Widget build(BuildContext context) => PageBody(children: [
        if (examples.isEmpty) const _Empty('Pas encore d\'exemple corrigé pour cette notion.'),
        for (final e in examples) Padding(padding: const EdgeInsets.only(bottom: 14), child: ExampleCard(example: e)),
      ]);
}

class ExampleCard extends StatefulWidget {
  const ExampleCard({super.key, required this.example});
  final WorkedExample example;
  @override
  State<ExampleCard> createState() => _ExampleCardState();
}

class _ExampleCardState extends State<ExampleCard> {
  bool open = false;
  @override
  Widget build(BuildContext context) {
    final e = widget.example;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 10),
        BlockList(e.problem),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => open = !open),
            icon: Icon(open ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
            label: Text(open ? 'Masquer le corrigé' : 'Voir le corrigé'),
          ),
        ),
        if (open) ...[const SizedBox(height: 14), BlockList(e.solution)],
      ]),
    );
  }
}

class _ExercisesTab extends StatelessWidget {
  const _ExercisesTab({required this.notion, required this.exercises});
  final Notion notion;
  final List<Exercise> exercises;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final n = context.nn;
    return PageBody(children: [
      if (exercises.isEmpty) const _Empty('Pas encore d\'exercice pour cette notion.'),
      for (final x in exercises)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExerciseScreen(exercise: x))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(x.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Difficulty(x.difficulty),
                    const SizedBox(width: 10),
                    Text('${x.questions.length} question${x.questions.length > 1 ? 's' : ''}',
                        style: TextStyle(color: n.mid, fontSize: 12.5)),
                  ]),
                ]),
              ),
              if (s.progress.attempts[x.id]?.any((a) => a.correct) ?? false)
                const Icon(Icons.check_circle, color: NColors.red)
              else
                Icon(Icons.chevron_right, color: n.mid),
            ]),
          ),
        ),
    ]);
  }
}
