import 'package:coach_core/coach_core.dart';
import 'package:test/test.dart';

import 'content_test.dart' show loadReal;

void main() {
  final lib = loadReal();

  for (final kind in ExamKind.values) {
    test('épreuve ${kind.title} : sujets disponibles et reproductibles', () {
      expect(kind.available(lib), isTrue);
      expect(kind.problems(lib).length, greaterThanOrEqualTo(6));
      for (final p in kind.problems(lib)) {
        expect(p.difficulty, 3, reason: p.id);
        expect(p.notions.length, greaterThanOrEqualTo(2), reason: '${p.id} doit croiser plusieurs notions');
      }
      for (var seed = 0; seed < 30; seed++) {
        final a = drawExam(lib, kind, seed);
        final b = drawExam(lib, kind, seed);
        expect(a.parts.length, kind.parts);
        expect(a.parts.map((p) => p.exercise.id).toSet().length, kind.parts, reason: 'problèmes distincts');
        expect(a.parts.map((p) => p.exercise.id), b.parts.map((p) => p.exercise.id));
        expect(a.parts.map((p) => p.seed), b.parts.map((p) => p.seed));
      }
    });
  }

  test('notation sur 20', () {
    final d = drawExam(lib, ExamKind.maths, 3);
    // Copie parfaite : on répond la valeur attendue partout.
    final perfect = <String, Map<String, Verdict>>{
      for (final p in d.parts)
        p.exercise.id: {
          for (final q in p.exercise.questions) q.id: check(q, p.expected[q.id]!, _answer(q, p)),
        },
    };
    expect(scoreExam(d, perfect).on20, 20);
    expect(scoreExam(d, {}).on20, 0);

    // Premier problème juste, second vide : 10/20.
    final half = {d.parts.first.exercise.id: perfect[d.parts.first.exercise.id]!};
    expect(scoreExam(d, half).on20, 10);
    expect(formatMark(13.5), '13,5');
    expect(formatMark(12), '12');
  });
}

String _answer(Question q, ExerciseInstance p) {
  final v = p.expected[q.id]!;
  if (q.kind == 'choice') return '${v.re.round()}';
  return formatExpected(q, v);
}
