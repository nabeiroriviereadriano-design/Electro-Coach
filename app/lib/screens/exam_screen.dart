import 'dart:async';
import 'dart:math' as math;

import 'package:coach_core/coach_core.dart';
import 'package:flutter/material.dart';

import '../render/blocks.dart';
import '../render/rich_content.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'exercise_screen.dart';

/// Choix de l'épreuve blanche.
class ExamHomeScreen extends StatefulWidget {
  const ExamHomeScreen({super.key});

  @override
  State<ExamHomeScreen> createState() => _ExamHomeScreenState();
}

class _ExamHomeScreenState extends State<ExamHomeScreen> {
  bool timed = true;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final n = context.nn;
    return Scaffold(
      appBar: AppBar(title: const Text('Examen blanc', style: TextStyle(fontSize: 16))),
      body: PageBody(children: [
        const Row(children: [DotTitle('Examen blanc', size: 24), SizedBox(width: 6), RedDot()]),
        const SizedBox(height: 8),
        Text(
          'Un sujet complet tiré au sort parmi les problèmes de 2e année, à traiter dans les conditions de l\'épreuve. '
          'Les corrigés et la note s\'affichent quand tu rends ta copie.',
          style: TextStyle(color: n.mid, fontSize: 13.5, height: 1.4),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Chronométré'),
          subtitle: Text('Copie ramassée automatiquement à la fin du temps', style: TextStyle(color: n.mid, fontSize: 12.5)),
          value: timed,
          onChanged: (v) => setState(() => timed = v),
        ),
        for (final kind in ExamKind.values) ...[
          const SizedBox(height: 10),
          _ExamCard(kind: kind, timed: timed, state: s),
        ],
      ]),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.kind, required this.timed, required this.state});
  final ExamKind kind;
  final bool timed;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final n = context.nn;
    final lib = state.library;
    final ok = kind.available(lib);
    final last = state.examLast(kind), best = state.examBest(kind), count = state.examCount(kind);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(kind == ExamKind.maths ? Icons.functions : Icons.bolt, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text(kind.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5))),
          Text('${kind.duration.inHours} h', style: const TextStyle(fontFamily: kFontMono, fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        Text(kind.rules, style: TextStyle(color: n.mid, fontSize: 13, height: 1.35)),
        const SizedBox(height: 4),
        Text('${kind.problems(lib).length} problèmes dans la banque de sujets', style: TextStyle(color: n.mid, fontSize: 12.5)),
        if (count > 0) ...[
          const SizedBox(height: 8),
          Text('Dernière note : ${formatMark(last!)} / 20 · meilleure : ${formatMark(best!)} / 20 · $count sujet(s) traité(s)',
              style: const TextStyle(fontSize: 13)),
        ],
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: NColors.red, foregroundColor: Colors.white),
          onPressed: ok
              ? () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ExamRunScreen(kind: kind, seed: DateTime.now().millisecondsSinceEpoch % 1000000, timed: timed),
                  ))
              : null,
          child: Text(ok ? 'Commencer l\'épreuve' : 'Sujets en préparation'),
        ),
      ]),
    );
  }
}

/// Composition en cours puis copie corrigée.
class ExamRunScreen extends StatefulWidget {
  const ExamRunScreen({super.key, required this.kind, required this.seed, this.timed = true});
  final ExamKind kind;
  final int seed;

  /// Avec chronomètre : la copie est rendue automatiquement à la fin du temps.
  final bool timed;

  @override
  State<ExamRunScreen> createState() => _ExamRunScreenState();
}

class _ExamRunScreenState extends State<ExamRunScreen> {
  ExamDraw? draw;
  String? error;
  final controllers = <String, TextEditingController>{};
  final choices = <String, int?>{};
  Map<String, Map<String, Verdict>>? verdicts;
  ExamScore? score;
  Timer? timer;
  late Duration left = widget.kind.duration;

  String _key(ExerciseInstance p, Question q) => '${p.exercise.id}/${q.id}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (draw != null || error != null) return;
    try {
      draw = drawExam(AppScope.of(context).library, widget.kind, widget.seed);
      for (final p in draw!.parts) {
        for (final q in p.exercise.questions) {
          if (q.kind != 'choice') controllers[_key(p, q)] = TextEditingController();
        }
      }
      if (widget.timed) {
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted || score != null) return;
          setState(() => left -= const Duration(seconds: 1));
          if (left <= Duration.zero) _submit();
        });
      }
    } on Object catch (e) {
      error = '$e';
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final d = draw!;
    timer?.cancel();
    final v = <String, Map<String, Verdict>>{};
    for (final p in d.parts) {
      v[p.exercise.id] = {
        for (final q in p.exercise.questions)
          q.id: check(q, p.expected[q.id]!, q.kind == 'choice' ? (choices[_key(p, q)]?.toString() ?? '') : controllers[_key(p, q)]!.text),
      };
    }
    final sc = scoreExam(d, v);
    setState(() {
      verdicts = v;
      score = sc;
    });
    final s = AppScope.of(context);
    for (final p in d.parts) {
      s.recordAttempt(p.exercise, p.seed, v[p.exercise.id]!.values.every((x) => x.correct));
    }
    s.recordExam(widget.kind, sc.on20);
  }

  Future<void> _confirmSubmit() async {
    final empty = [
      for (final p in draw!.parts)
        for (final q in p.exercise.questions)
          if (q.kind == 'choice' ? choices[_key(p, q)] == null : controllers[_key(p, q)]!.text.trim().isEmpty) q,
    ].length;
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rendre ta copie ?'),
        content: Text(empty == 0 ? 'Toutes les questions ont une réponse.' : '$empty question(s) sans réponse.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Continuer')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Rendre')),
        ],
      ),
    );
    if (go == true && mounted && score == null) _submit();
  }

  String _clock(Duration d) {
    final t = d.isNegative ? Duration.zero : d;
    final h = t.inHours, m = t.inMinutes % 60, sec = t.inSeconds % 60;
    return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final n = context.nn;
    if (error != null || draw == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text('Sujet indisponible : $error')));
    }
    final d = draw!;
    final done = score != null;
    final perPart = 20 / d.parts.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(done ? 'Copie corrigée' : widget.kind.title, style: const TextStyle(fontSize: 16)),
        actions: [
          if (widget.timed && !done)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(_clock(left),
                    style: TextStyle(
                        fontFamily: kFontMono, fontSize: 15, color: left.inMinutes < 10 ? NColors.red : null)),
              ),
            ),
        ],
      ),
      body: PageBody(children: [
        if (done) _Result(score: score!, draw: d) else ...[
          Text('Sujet n° ${d.seed}', style: TextStyle(color: n.mid, fontSize: 12.5, fontFamily: kFontMono)),
          const SizedBox(height: 4),
          Text(
            '${d.parts.length} problèmes indépendants, ${formatMark(perPart)} points chacun. '
            'Calculatrice autorisée. Les réponses numériques acceptent la virgule et les unités.',
            style: TextStyle(color: n.mid, fontSize: 13, height: 1.4),
          ),
        ],
        for (final (k, p) in d.parts.indexed) ...[
          SectionLabel('Problème ${k + 1} · ${formatMark(perPart)} points'),
          Row(children: [
            Expanded(
              child: Text(p.exercise.title.replaceFirst('Problème — ', ''),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.25)),
            ),
            if (done)
              Text('${formatMark(score!.perPart[k])} / ${formatMark(perPart)}',
                  style: const TextStyle(fontFamily: kFontMono, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          BlockList(p.exercise.statement, render: p.render, env: p.env),
          for (final (i, q) in p.exercise.questions.indexed) ...[
            const SizedBox(height: 6),
            QuestionCard(
              index: i + 1,
              question: q,
              inst: p,
              controller: controllers[_key(p, q)],
              selected: choices[_key(p, q)],
              onSelect: (c) {
                if (!done) setState(() => choices[_key(p, q)] = c);
              },
              verdict: verdicts?[p.exercise.id]?[q.id],
              reveal: done,
            ),
          ],
          if (done) ...[
            const SizedBox(height: 10),
            if (p.exercise.method.isNotEmpty) BlockView(Block('method', {'text': p.render(p.exercise.method)})),
            const SizedBox(height: 8),
            BlockList(p.exercise.solution, render: p.render, env: p.env),
          ],
        ],
        const SizedBox(height: 22),
        if (!done)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NColors.red, foregroundColor: Colors.white),
            onPressed: _confirmSubmit,
            child: const Text('Rendre ma copie'),
          )
        else
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Terminer')),
      ]),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.score, required this.draw});
  final ExamScore score;
  final ExamDraw draw;

  @override
  Widget build(BuildContext context) {
    final n = context.nn;
    final mark = score.on20;
    final comment = mark >= 16
        ? 'Excellent : tu es prêt pour l\'épreuve.'
        : mark >= 12
            ? 'Bon travail. Revois les questions manquées dans le corrigé.'
            : mark >= 8
                ? 'Des bases solides, mais des notions à reprendre : regarde les méthodes ci-dessous.'
                : 'Reprends les cours des notions concernées avant un nouveau sujet.';
    return AppCard(
      highlight: mark >= 10,
      child: Row(children: [
        ProgressRing(value: math.min(1, mark / 20), size: 96, caption: 'note'),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${formatMark(mark)} / 20', style: const TextStyle(fontFamily: kFontDot, fontWeight: FontWeight.w900, fontSize: 32)),
            const SizedBox(height: 4),
            RichContent(comment, style: TextStyle(color: n.mid, fontSize: 13, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}
