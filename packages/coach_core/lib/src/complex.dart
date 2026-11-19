import 'dart:math' as math;

/// Nombre complexe minimal (j² = −1), utilisé par l'évaluateur d'expressions :
/// toutes les grandeurs sont calculées en complexe, un réel a une partie
/// imaginaire nulle.
class Complex {
  const Complex(this.re, [this.im = 0]);

  factory Complex.polar(double r, double theta) => Complex(r * math.cos(theta), r * math.sin(theta));

  final double re;
  final double im;

  static const zero = Complex(0);
  static const one = Complex(1);
  static const j = Complex(0, 1);

  double get abs => math.sqrt(re * re + im * im);
  double get arg => math.atan2(im, re);
  Complex get conj => Complex(re, -im);

  bool get isFinite => re.isFinite && im.isFinite;

  /// Vrai si la partie imaginaire est négligeable devant le module.
  bool get isReal => im.abs() <= 1e-9 * math.max(1.0, abs);

  Complex operator +(Complex o) => Complex(re + o.re, im + o.im);
  Complex operator -(Complex o) => Complex(re - o.re, im - o.im);
  Complex operator -() => Complex(-re, -im);
  Complex operator *(Complex o) => Complex(re * o.re - im * o.im, re * o.im + im * o.re);
  Complex operator /(Complex o) {
    final d = o.re * o.re + o.im * o.im;
    if (d == 0) return const Complex(double.nan, double.nan);
    return Complex((re * o.re + im * o.im) / d, (im * o.re - re * o.im) / d);
  }

  Complex scale(double k) => Complex(re * k, im * k);

  Complex exp() {
    final e = math.exp(re);
    return Complex(e * math.cos(im), e * math.sin(im));
  }

  Complex ln() => Complex(math.log(abs), arg);

  Complex sqrt() {
    if (isReal && re >= 0) return Complex(math.sqrt(re));
    return Complex.polar(math.sqrt(abs), arg / 2);
  }

  Complex pow(Complex e) {
    if (isReal && e.isReal) {
      final b = re, x = e.re;
      if (b >= 0 || x == x.roundToDouble()) return Complex(math.pow(b, x).toDouble());
    }
    if (re == 0 && im == 0) return e.re > 0 ? zero : const Complex(double.nan, double.nan);
    return (ln() * e).exp();
  }

  Complex sin() => Complex(math.sin(re) * _cosh(im), math.cos(re) * _sinh(im));
  Complex cos() => Complex(math.cos(re) * _cosh(im), -math.sin(re) * _sinh(im));
  Complex tan() => sin() / cos();

  static double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;
  static double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;

  @override
  bool operator ==(Object other) => other is Complex && other.re == re && other.im == im;

  @override
  int get hashCode => Object.hash(re, im);

  @override
  String toString() => im == 0 ? '$re' : '$re${im < 0 ? '-' : '+'}j${im.abs()}';
}
