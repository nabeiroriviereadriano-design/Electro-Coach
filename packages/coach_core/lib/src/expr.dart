import 'dart:math' as math;

import 'complex.dart';

/// Erreur de lecture ou de calcul d'une expression, avec un message en français
/// montrable à l'étudiant.
class ExprError implements Exception {
  ExprError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Expression analysée une fois, évaluable autant de fois que voulu
/// (tracés de courbes, tirages d'exercices).
abstract class Expr {
  Complex eval(Map<String, Complex> env);
  Set<String> get variables;
}

class _Num extends Expr {
  _Num(this.v);
  final Complex v;
  @override
  Complex eval(Map<String, Complex> env) => v;
  @override
  Set<String> get variables => const {};
}

class _Var extends Expr {
  _Var(this.name);
  final String name;
  @override
  Complex eval(Map<String, Complex> env) {
    final v = env[name];
    if (v != null) return v;
    final c = constants[name];
    if (c != null) return c;
    throw ExprError('Variable inconnue : $name');
  }

  @override
  Set<String> get variables => constants.containsKey(name) ? const {} : {name};
}

class _Neg extends Expr {
  _Neg(this.a);
  final Expr a;
  @override
  Complex eval(Map<String, Complex> env) => -a.eval(env);
  @override
  Set<String> get variables => a.variables;
}

class _Bin extends Expr {
  _Bin(this.op, this.a, this.b);
  final String op;
  final Expr a, b;
  @override
  Complex eval(Map<String, Complex> env) {
    final x = a.eval(env), y = b.eval(env);
    switch (op) {
      case '+':
        return x + y;
      case '-':
        return x - y;
      case '*':
        return x * y;
      case '/':
        return x / y;
      case '^':
        return x.pow(y);
      case '∠':
        // module ∠ argument (argument en radians, ou en degrés avec « ° »)
        return Complex.polar(x.re, y.re);
    }
    throw ExprError('Opérateur inconnu : $op');
  }

  @override
  Set<String> get variables => {...a.variables, ...b.variables};
}

class _Call extends Expr {
  _Call(this.name, this.args);
  final String name;
  final List<Expr> args;
  @override
  Complex eval(Map<String, Complex> env) {
    final f = functions[name];
    if (f == null) throw ExprError('Fonction inconnue : $name');
    final v = args.map((a) => a.eval(env)).toList();
    return f(v);
  }

  @override
  Set<String> get variables => {for (final a in args) ...a.variables};
}

/// Constantes reconnues (π, j, e, g…).
const Map<String, Complex> constants = {
  'pi': Complex(math.pi),
  'π': Complex(math.pi),
  'j': Complex(0, 1),
  'i': Complex(0, 1),
  'e': Complex(math.e),
};

double _real(Complex c, String fn) {
  if (!c.isReal) throw ExprError('$fn attend un nombre réel');
  return c.re;
}

Complex _one(List<Complex> a, String fn) {
  if (a.length != 1) throw ExprError('$fn attend 1 argument');
  return a[0];
}

/// Fonctions reconnues. Les angles sont en radians (deg() et rad() convertissent).
final Map<String, Complex Function(List<Complex>)> functions = {
  'sqrt': (a) => _one(a, 'sqrt').sqrt(),
  'racine': (a) => _one(a, 'racine').sqrt(),
  'exp': (a) => _one(a, 'exp').exp(),
  'ln': (a) => _one(a, 'ln').ln(),
  'log': (a) => Complex(math.log(_real(_one(a, 'log'), 'log')) / math.ln10),
  'sin': (a) => _one(a, 'sin').sin(),
  'cos': (a) => _one(a, 'cos').cos(),
  'tan': (a) => _one(a, 'tan').tan(),
  'atan': (a) => Complex(math.atan(_real(_one(a, 'atan'), 'atan'))),
  'arctan': (a) => Complex(math.atan(_real(_one(a, 'arctan'), 'arctan'))),
  'asin': (a) => Complex(math.asin(_real(_one(a, 'asin'), 'asin'))),
  'acos': (a) => Complex(math.acos(_real(_one(a, 'acos'), 'acos'))),
  'atan2': (a) {
    if (a.length != 2) throw ExprError('atan2 attend 2 arguments');
    return Complex(math.atan2(_real(a[0], 'atan2'), _real(a[1], 'atan2')));
  },
  'abs': (a) => Complex(_one(a, 'abs').abs),
  'mod': (a) => Complex(_one(a, 'mod').abs),
  'arg': (a) => Complex(_one(a, 'arg').arg),
  're': (a) => Complex(_one(a, 're').re),
  'im': (a) => Complex(_one(a, 'im').im),
  'conj': (a) => _one(a, 'conj').conj,
  'deg': (a) => Complex(_real(_one(a, 'deg'), 'deg') * 180 / math.pi),
  'rad': (a) => Complex(_real(_one(a, 'rad'), 'rad') * math.pi / 180),
  'min': (a) => Complex(a.map((x) => _real(x, 'min')).reduce(math.min)),
  'max': (a) => Complex(a.map((x) => _real(x, 'max')).reduce(math.max)),
  'round': (a) {
    if (a.isEmpty || a.length > 2) throw ExprError('round attend 1 ou 2 arguments');
    final d = a.length == 2 ? _real(a[1], 'round').round() : 0;
    final f = math.pow(10, d);
    return Complex((_real(a[0], 'round') * f).roundToDouble() / f);
  },
  // binomiale : C(n, k)
  'C': (a) {
    if (a.length != 2) throw ExprError('C attend 2 arguments');
    final n = _real(a[0], 'C').round(), k = _real(a[1], 'C').round();
    if (k < 0 || k > n) return Complex.zero;
    var r = 1.0;
    for (var i = 1; i <= k; i++) {
      r = r * (n - k + i) / i;
    }
    return Complex(r.roundToDouble());
  },
};

enum _T { num, ident, op, lpar, rpar, sep, end }

class _Tok {
  _Tok(this.t, this.s, this.pos, [this.v]);
  final _T t;
  final String s;
  final int pos;
  final Complex? v;
}

/// Analyse une expression.
///
/// [userInput] : saisie d'un étudiant. La virgule est alors le séparateur
/// décimal (« 12,5 ») et le point-virgule sépare les arguments ; sinon (contenu
/// rédigé), le point est décimal et la virgule sépare les arguments.
Expr parseExpr(String src, {bool userInput = false}) {
  final toks = _tokenize(src, userInput);
  final p = _Parser(toks);
  final e = p.parseTop();
  if (p.peek.t != _T.end) throw ExprError('Symbole inattendu : « ${p.peek.s} »');
  return e;
}

/// Raccourci : analyse puis évalue.
Complex evalExpr(String src, [Map<String, Complex> env = const {}, bool userInput = false]) =>
    parseExpr(src, userInput: userInput).eval(env);

bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
bool _isIdStart(String c) => RegExp(r'[A-Za-z_αβγδεθλμρστφψωΩπΔ]').hasMatch(c);
bool _isId(String c) => _isIdStart(c) || _isDigit(c);

List<_Tok> _tokenize(String src, bool user) {
  final out = <_Tok>[];
  var s0 = src;
  if (user) {
    // séparateurs de milliers : « 12 345 » → 12345
    s0 = s0.replaceAllMapped(RegExp(r'(\d)[ \u202f\u00a0](?=\d{3}(?!\d))'), (m) => m.group(1)!);
  }
  final s = s0
      .replaceAll('−', '-')
      .replaceAll('–', '-')
      .replaceAll('×', '*')
      .replaceAll('·', '*')
      .replaceAll('÷', '/')
      .replaceAll('²', '^2')
      .replaceAll('³', '^3')
      .replaceAll(' ', ' ')
      .replaceAll(' ', ' ');
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == ' ' || c == '\t' || c == '\n') {
      i++;
      continue;
    }
    final decimalSep = user ? ',' : '.';
    final altDecimal = user ? '.' : null; // un étudiant peut aussi taper un point
    if (_isDigit(c) || ((c == decimalSep || c == altDecimal) && i + 1 < s.length && _isDigit(s[i + 1]))) {
      final start = i;
      final b = StringBuffer();
      var seenDot = false;
      while (i < s.length) {
        final d = s[i];
        if (_isDigit(d)) {
          b.write(d);
          i++;
        } else if ((d == decimalSep || d == altDecimal) && !seenDot) {
          seenDot = true;
          b.write('.');
          i++;
        } else {
          break;
        }
      }
      // exposant : 1e3, 4,7E-6
      if (i < s.length && (s[i] == 'e' || s[i] == 'E')) {
        var k = i + 1;
        if (k < s.length && (s[k] == '+' || s[k] == '-')) k++;
        if (k < s.length && _isDigit(s[k])) {
          b.write('e');
          b.write(s.substring(i + 1, k));
          i = k;
          while (i < s.length && _isDigit(s[i])) {
            b.write(s[i]);
            i++;
          }
        }
      }
      final v = double.parse(b.toString());
      // nombre imaginaire collé : 4j, 4i
      if (i < s.length && (s[i] == 'j' || s[i] == 'i') && (i + 1 >= s.length || !_isId(s[i + 1]))) {
        i++;
        out.add(_Tok(_T.num, s.substring(start, i), start, Complex(0, v)));
      } else {
        out.add(_Tok(_T.num, s.substring(start, i), start, Complex(v)));
      }
      continue;
    }
    if (_isIdStart(c)) {
      final start = i;
      while (i < s.length && _isId(s[i])) {
        i++;
      }
      // « j4 », « j2,5 » : unité imaginaire suivie d'un nombre → j × nombre
      if ((c == 'j' || c == 'i') && start + 1 < s.length && (_isDigit(s[start + 1]) || ((s[start + 1] == ',' || s[start + 1] == '.') && start + 2 < s.length && _isDigit(s[start + 2])))) {
        out.add(_Tok(_T.ident, c, start));
        i = start + 1;
        continue;
      }
      out.add(_Tok(_T.ident, s.substring(start, i), start));
      continue;
    }
    if (c == '√') {
      out.add(_Tok(_T.ident, 'sqrt', i));
      i++;
      continue;
    }
    if ('+-*/^∠°'.contains(c)) {
      out.add(_Tok(_T.op, c, i));
      i++;
      continue;
    }
    if (c == '(') {
      out.add(_Tok(_T.lpar, c, i));
      i++;
      continue;
    }
    if (c == ')') {
      out.add(_Tok(_T.rpar, c, i));
      i++;
      continue;
    }
    if ((user && c == ';') || (!user && c == ',')) {
      out.add(_Tok(_T.sep, c, i));
      i++;
      continue;
    }
    throw ExprError('Caractère non reconnu : « $c »');
  }
  out.add(_Tok(_T.end, '', s.length));
  return out;
}

class _Parser {
  _Parser(this.toks);
  final List<_Tok> toks;
  var i = 0;

  _Tok get peek => toks[i];
  _Tok next() => toks[i++];

  bool _isOp(String s) => peek.t == _T.op && peek.s == s;

  Expr parseTop() {
    var a = parseAdd();
    if (_isOp('∠')) {
      next();
      final b = parseAdd();
      a = _Bin('∠', a, b);
    }
    return a;
  }

  Expr parseAdd() {
    var a = parseMul();
    while (_isOp('+') || _isOp('-')) {
      final op = next().s;
      a = _Bin(op, a, parseMul());
    }
    return a;
  }

  bool _startsPrimary() =>
      peek.t == _T.num || peek.t == _T.ident || peek.t == _T.lpar;

  Expr parseMul() {
    var a = parseUnary();
    while (true) {
      if (_isOp('*') || _isOp('/')) {
        final op = next().s;
        a = _Bin(op, a, parseUnary());
      } else if (_startsPrimary()) {
        // multiplication implicite : 2pi, 3(x+1), 2 R
        a = _Bin('*', a, parsePow());
      } else {
        return a;
      }
    }
  }

  Expr parseUnary() {
    if (_isOp('-')) {
      next();
      return _Neg(parseUnary());
    }
    if (_isOp('+')) {
      next();
      return parseUnary();
    }
    return parsePow();
  }

  Expr parsePow() {
    final base = parsePostfix();
    if (_isOp('^')) {
      next();
      return _Bin('^', base, parseUnary());
    }
    return base;
  }

  Expr parsePostfix() {
    var e = parsePrimary();
    while (_isOp('°')) {
      next();
      e = _Bin('*', e, _Num(const Complex(math.pi / 180)));
    }
    return e;
  }

  Expr parsePrimary() {
    final t = next();
    switch (t.t) {
      case _T.num:
        return _Num(t.v!);
      case _T.ident:
        if (peek.t == _T.lpar) {
          next();
          final args = <Expr>[];
          if (peek.t != _T.rpar) {
            args.add(parseTop());
            while (peek.t == _T.sep) {
              next();
              args.add(parseTop());
            }
          }
          if (next().t != _T.rpar) throw ExprError('Parenthèse fermante manquante après ${t.s}(');
          return _Call(t.s, args);
        }
        if (t.s == 'sqrt') return _Call('sqrt', [parsePow()]);
        return _Var(t.s);
      case _T.lpar:
        final e = parseTop();
        if (next().t != _T.rpar) throw ExprError('Parenthèse fermante manquante');
        return e;
      case _T.end:
        throw ExprError('Expression incomplète');
      default:
        throw ExprError('Symbole inattendu : « ${t.s} »');
    }
  }
}
