import 'dart:math' as math;

import 'complex.dart';

/// Préfixes SI acceptés dans les réponses.
const Map<String, double> siPrefixes = {
  'T': 1e12,
  'G': 1e9,
  'M': 1e6,
  'k': 1e3,
  'm': 1e-3,
  'µ': 1e-6,
  'μ': 1e-6,
  'u': 1e-6,
  'n': 1e-9,
  'p': 1e-12,
};

/// Autres écritures acceptées pour une même unité.
const Map<String, List<String>> unitAliases = {
  'Ω': ['Ω', 'Ω', 'ohm', 'ohms', 'Ohm', 'Ohms', 'ohm(s)'],
  '°': ['°', 'deg', 'degré', 'degrés'],
  'rad': ['rad', 'radian', 'radians'],
  'rad/s': ['rad/s', 'rad.s-1', 'rad·s⁻¹'],
  'Hz': ['Hz', 'hz'],
  'V': ['V', 'v'],
  'A': ['A'],
  'W': ['W'],
  'var': ['var', 'VAR', 'VAr'],
  'VA': ['VA', 'V·A', 'V.A'],
  'F': ['F'],
  'H': ['H'],
  's': ['s'],
  'J': ['J'],
  'Wh': ['Wh'],
  'N': ['N'],
  'N·m': ['N·m', 'N.m', 'Nm'],
  'tr/min': ['tr/min', 'tr.min-1', 'rpm'],
  '%': ['%'],
};

/// Unités sans préfixe possible.
const Set<String> _noPrefix = {'°', '%', 'tr/min', 'rad/s'};

class UnitMatch {
  UnitMatch(this.numberPart, this.factor, this.unitGiven);
  final String numberPart;
  final double factor;
  final String? unitGiven;
}

/// Sépare la partie numérique et l'unité (avec préfixe) en fin de saisie.
/// Renvoie null si la saisie se termine par une unité qui ne correspond pas à
/// [expected].
UnitMatch? splitUnit(String input, String? expected) {
  final s = input.trim();
  if (expected == null || expected.isEmpty) return UnitMatch(s, 1, null);
  final aliases = unitAliases[expected] ?? [expected];
  final candidates = <(String, double)>[];
  for (final a in aliases) {
    candidates.add((a, 1));
    if (!_noPrefix.contains(expected)) {
      siPrefixes.forEach((p, f) => candidates.add(('$p$a', f)));
    }
  }
  candidates.sort((x, y) => y.$1.length.compareTo(x.$1.length));
  for (final (suffix, f) in candidates) {
    if (s.length > suffix.length && s.endsWith(suffix)) {
      final head = s.substring(0, s.length - suffix.length).trimRight();
      if (head.isEmpty) continue;
      // éviter de lire « 4j » comme un nombre suivi d'une unité « j »
      return UnitMatch(head, f, suffix);
    }
  }
  // se termine par des lettres qui ne sont pas l'unité attendue ?
  final tail = RegExp(r'[A-Za-zΩΩµμ°%]+$').firstMatch(s)?.group(0);
  if (tail != null && tail != 'j' && tail != 'i' && tail != 'pi' && tail != 'π') {
    // une variable ou une fonction ne se termine pas une saisie de nombre : c'est
    // une unité incorrecte
    return null;
  }
  return UnitMatch(s, 1, null);
}

/// Formatage français d'un nombre réel avec [sig] chiffres significatifs.
String formatNumber(double v, {int sig = 3}) {
  if (v.isNaN) return '—';
  if (v.isInfinite) return v > 0 ? '+∞' : '−∞';
  if (v == 0) return '0';
  final a = v.abs();
  final exp10 = (math.log(a) / math.ln10).floor();
  if (exp10 >= 7 || exp10 <= -5) {
    final m = v / math.pow(10, exp10);
    return '${_trim(m.toStringAsFixed(math.max(0, sig - 1)))} × 10^$exp10'.replaceAll('-', '−');
  }
  final decimals = math.max(0, sig - 1 - exp10);
  var s = v.toStringAsFixed(decimals);
  s = _trim(s);
  // séparateur de milliers (espace fine insécable)
  final neg = s.startsWith('-');
  if (neg) s = s.substring(1);
  final parts = s.split('.');
  final intPart = parts[0];
  final b = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0 && intPart.length > 4) b.write(' ');
    b.write(intPart[i]);
  }
  var out = b.toString();
  if (parts.length > 1) out += ',${parts[1]}';
  return neg ? '−$out' : out;
}

String _trim(String s) {
  if (!s.contains('.')) return s;
  s = s.replaceFirst(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

/// Formatage avec préfixe SI : 4700 Ω → « 4,7 kΩ ».
String formatEng(double v, String unit, {int sig = 3}) {
  if (unit.isEmpty) return formatNumber(v, sig: sig);
  if (_noPrefix.contains(unit) || v == 0 || !v.isFinite) return '${formatNumber(v, sig: sig)} $unit';
  final a = v.abs();
  const steps = [
    (1e12, 'T'),
    (1e9, 'G'),
    (1e6, 'M'),
    (1e3, 'k'),
    (1.0, ''),
    (1e-3, 'm'),
    (1e-6, 'µ'),
    (1e-9, 'n'),
    (1e-12, 'p'),
  ];
  for (final (f, p) in steps) {
    if (a >= f * 0.9995) return '${formatNumber(v / f, sig: sig)} $p$unit';
  }
  return '${formatNumber(v / 1e-12, sig: sig)} p$unit';
}

/// Formatage d'un complexe : algébrique « 3 + j4 » ou polaire « 5 ∠ 53,1° ».
String formatComplex(Complex z, {int sig = 3, bool polar = false, String unit = ''}) {
  final u = unit.isEmpty ? '' : ' $unit';
  if (polar) {
    final deg = z.arg * 180 / math.pi;
    return '${formatNumber(z.abs, sig: sig)}$u ∠ ${formatNumber(deg, sig: sig)}°';
  }
  if (z.isReal) return unit.isEmpty ? formatNumber(z.re, sig: sig) : formatEng(z.re, unit, sig: sig);
  final reS = formatNumber(z.re, sig: sig);
  final imS = formatNumber(z.im.abs(), sig: sig);
  if (z.re.abs() <= 1e-12 * z.abs) return '${z.im < 0 ? '−' : ''}j$imS$u';
  final core = '$reS ${z.im < 0 ? '−' : '+'} j$imS';
  return unit.isEmpty ? core : '($core)$u';
}
