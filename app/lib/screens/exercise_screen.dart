import 'package:coach_core/coach_core.dart';
import 'package:flutter/material.dart';

import '../render/blocks.dart';
import '../render/rich_content.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Exercice tiré au sort : énoncé, réponses, indice, méthode, correction.
class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key, required this.exercise, this.seed});
  final Exercise exercise;

  /// Tirage imposé (tests, captures) ; sinon un nouveau tirage.
  final int? seed;

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  ExerciseInstance? inst;
  String? error;
  final controllers = <String, TextEditingController>{};
  final choices = <String, int?>{};
  Map<String, Verdict>? verdicts;
  bool showHint = false, showMethod = false, showSolution = false, recorded = false;
  int draws = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (inst == null && error == null) _draw(widget.seed);
  }

  void _draw(int? forced) {
    final s = AppScope.of(context);
    final seed = forced ?? s.nextSeed(widget.exercise) + draws * 104729;
    draws++;
    try {
      inst = generate(widget.exercise, seed);
      error = null;
    } on Object catch (e) {
      error = '$e';
    }
    for (final c in controllers.values) {
      c.dispose();
    }
    controllers
      ..clear()
      ..addAll({for (final q in widget.exercise.questions) if (q.kind != 'choice') q.id: TextEditingController()});
    choices.clear();
    verdicts = null;
    showHint = showMethod = showSolution = recorded = false;
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _validate() {
    final i = inst!;
    final v = <String, Verdict>{};
    for (final q in widget.exercise.questions) {
      final input = q.kind == 'choice' ? (choices[q.id]?.toString() ?? '') : controllers[q.id]!.text;
      v[q.id] = check(q, i.expected[q.id]!, input);
    }
    setState(() => verdicts = v);
    if (!recorded) {
      recorded = true;
      AppScope.of(context).recordAttempt(widget.exercise, i.seed, v.values.every((x) => x.correct));
    }
  }

  @override
  Widget build(BuildContext context) {
    final x = widget.exercise;
    final n = context.nn;
    if (error != null || inst == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text('Exercice indisponible : $error')));
    }
    final i = inst!;
    final allOk = verdicts != null && verdicts!.values.every((v) => v.correct);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercice', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Nouvel énoncé',
            icon: const Icon(Icons.casino_outlined),
            onPressed: () => setState(() => _draw(null)),
          ),
        ],
      ),
      body: PageBody(children: [
        Row(children: [
          Expanded(child: Text(x.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, height: 1.25))),
          Difficulty(x.difficulty),
        ]),
        const SizedBox(height: 14),
        BlockList(x.statement, render: i.render, env: i.env),
        for (final (k, q) in x.questions.indexed) ...[
          const SizedBox(height: 6),
          _QuestionCard(
            index: k + 1,
            question: q,
            inst: i,
            controller: controllers[q.id],
            selected: choices[q.id],
            onSelect: (c) => setState(() => choices[q.id] = c),
            verdict: verdicts?[q.id],
            reveal: showSolution,
          ),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (x.hint.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => setState(() => showHint = !showHint),
              icon: const Icon(Icons.lightbulb_outline, size: 18),
              label: const Text('Indice'),
            ),
          if (x.method.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => setState(() => showMethod = !showMethod),
              icon: const Icon(Icons.route_outlined, size: 18),
              label: const Text('Méthode'),
            ),
        ]),
        if (showHint) ...[const SizedBox(height: 12), BlockView(Block('tip', {'text': i.render(x.hint), 'title': 'Indice'}))],
        if (showMethod) ...[const SizedBox(height: 12), BlockView(Block('method', {'text': i.render(x.method)}))],
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: NColors.red, foregroundColor: Colors.white),
          onPressed: _validate,
          child: Text(verdicts == null ? 'Valider ma réponse' : 'Vérifier à nouveau'),
        ),
        if (verdicts != null) ...[
          const SizedBox(height: 14),
          AppCard(
            highlight: allOk,
            child: Row(children: [
              Icon(allOk ? Icons.check_circle : Icons.info_outline, color: allOk ? NColors.red : n.mid),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  allOk
                      ? 'Bravo, tout est juste !'
                      : '${verdicts!.values.where((v) => v.correct).length} / ${verdicts!.length} réponses justes. Corrige ou consulte le corrigé.',
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => showSolution = !showSolution),
                child: Text(showSolution ? 'Masquer le corrigé' : 'Voir le corrigé'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(onPressed: () => setState(() => _draw(null)), child: const Text('Nouvel énoncé')),
            ),
          ]),
        ],
        if (showSolution) ...[
          const SectionLabel('Corrigé'),
          BlockList(x.solution, render: i.render, env: i.env),
        ],
        if (!x.validated)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text('Exercice non encore relu par un enseignant.', style: TextStyle(fontSize: 12, color: n.mid)),
          ),
      ]),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.inst,
    required this.controller,
    required this.selected,
    required this.onSelect,
    required this.verdict,
    required this.reveal,
  });
  final int index;
  final Question question;
  final ExerciseInstance inst;
  final TextEditingController? controller;
  final int? selected;
  final void Function(int) onSelect;
  final Verdict? verdict;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    final n = context.nn;
    final q = question;
    final v = verdict;
    Widget input;
    if (q.kind == 'choice') {
      final order = choiceOrder(inst, q);
      input = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final c in order)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                side: BorderSide(color: selected == c ? NColors.red : n.line, width: selected == c ? 1.6 : 1),
                backgroundColor: selected == c ? NColors.red.withValues(alpha: 0.08) : null,
              ),
              onPressed: () => onSelect(c),
              child: RichContent(inst.render(q.choices[c]), style: const TextStyle(fontSize: 14.5)),
            ),
          ),
      ]);
    } else {
      input = Padding(
        padding: const EdgeInsets.only(top: 10),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.text,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontFamily: kFontMono, fontSize: 16),
          decoration: InputDecoration(
            hintText: q.kind == 'complex' ? 'ex. 3 + j4  ou  5∠53°' : (q.unit.isEmpty ? 'ta réponse' : 'ex. 12,5 ${q.unit}'),
            suffixText: q.unit.isEmpty ? null : q.unit,
          ),
        ),
      );
    }
    return AppCard(
      highlight: v?.correct ?? false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: n.line)),
            child: Text('$index', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(child: RichContent(inst.render(q.prompt))),
        ]),
        input,
        if (v != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Icon(v.correct ? Icons.check : Icons.close, size: 18, color: v.correct ? NColors.red : n.mid),
              const SizedBox(width: 6),
              Expanded(child: Text(v.message, style: TextStyle(fontSize: 13, color: v.correct ? n.fg : n.mid))),
            ]),
          ),
        if (reveal)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Réponse attendue : ${inst.render(formatExpected(q, inst.expected[q.id]!))}',
                style: const TextStyle(fontFamily: kFontMono, fontSize: 13)),
          ),
      ]),
    );
  }
}
