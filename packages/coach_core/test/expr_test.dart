import 'dart:math' as math;

import 'package:coach_core/coach_core.dart';
import 'package:test/test.dart';

Complex ev(String s, [Map<String, Complex> env = const {}]) => evalExpr(s, env);
Complex user(String s) => parseExpr(s, userInput: true).eval(const {});

void main() {
  group('évaluateur (contenu)', () {
    test('priorités et puissances', () {
      expect(ev('2+3*4').re, 14);
      expect(ev('2^3^2').re, 512);
      expect(ev('-2^2').re, -4);
      expect(ev('(1+2)*(3+4)').re, 21);
      expect(ev('2pi').re, closeTo(2 * math.pi, 1e-12));
    });
    test('fonctions', () {
      expect(ev('sqrt(16)').re, 4);
      expect(ev('deg(atan(1))').re, closeTo(45, 1e-9));
      expect(ev('log(1000)').re, closeTo(3, 1e-12));
      expect(ev('ln(e)').re, closeTo(1, 1e-12));
      expect(ev('atan2(1, -1)').re, closeTo(3 * math.pi / 4, 1e-12));
      expect(ev('C(5, 2)').re, 10);
      expect(ev('max(2, 7, 3)').re, 7);
    });
    test('complexes', () {
      final z = ev('(3+2j)*(1-j)');
      expect(z.re, closeTo(5, 1e-12));
      expect(z.im, closeTo(-1, 1e-12));
      final q = ev('(3+2*j)/(1-j)');
      expect(q.re, closeTo(0.5, 1e-12));
      expect(q.im, closeTo(2.5, 1e-12));
      expect(ev('abs(3+4j)').re, closeTo(5, 1e-12));
      expect(ev('j^2').re, closeTo(-1, 1e-12));
      expect(ev('exp(j*pi)').re, closeTo(-1, 1e-12));
    });
    test('variables', () {
      expect(ev('R + j*L*w', {'R': const Complex(40), 'L': const Complex(0.2), 'w': const Complex(100)}).im, closeTo(20, 1e-12));
      expect(() => ev('x + 1'), throwsA(isA<ExprError>()));
    });
    test('erreurs de syntaxe', () {
      expect(() => ev('2+'), throwsA(isA<ExprError>()));
      expect(() => ev('(2+3'), throwsA(isA<ExprError>()));
      expect(() => ev('2 # 3'), throwsA(isA<ExprError>()));
    });
  });

  group('saisie étudiant', () {
    test('virgule décimale et point', () {
      expect(user('12,5').re, 12.5);
      expect(user('12.5').re, 12.5);
      expect(user('4,7e-6').re, closeTo(4.7e-6, 1e-18));
    });
    test('milliers', () {
      expect(user('12 345').re, 12345);
      expect(user('1 234,5').re, 1234.5);
    });
    test('formes complexes', () {
      final a = user('3 + 4j');
      expect([a.re, a.im], [3, 4]);
      final b = user('0,5 + j2,5');
      expect(b.re, closeTo(0.5, 1e-12));
      expect(b.im, closeTo(2.5, 1e-12));
      final c = user('−3 − j4');
      expect([c.re, c.im], [-3, -4]);
      final p = user('5∠90°');
      expect(p.re, closeTo(0, 1e-9));
      expect(p.im, closeTo(5, 1e-9));
      final e = user('2e^(j*pi/2)');
      expect(e.im, closeTo(2, 1e-9));
    });
    test('symboles typographiques', () {
      expect(user('2×3').re, 6);
      expect(user('√(9)').re, 3);
      expect(user('3²').re, 9);
    });
  });
}
