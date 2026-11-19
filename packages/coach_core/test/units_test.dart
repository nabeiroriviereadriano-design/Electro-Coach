import 'package:coach_core/coach_core.dart';
import 'package:test/test.dart';

void main() {
  test('formatage français', () {
    expect(formatNumber(12.5), '12,5');
    expect(formatNumber(-0.0123, sig: 2), '−0,012');
    expect(formatNumber(4700), '4700');
    expect(formatNumber(123456), '123 456');
    expect(formatNumber(2), '2');
  });
  test('préfixes SI', () {
    expect(formatEng(4700, 'Ω'), '4,7 kΩ');
    expect(formatEng(0.0047, 'A'), '4,7 mA');
    expect(formatEng(22e-6, 'F'), '22 µF');
    expect(formatEng(230, 'V'), '230 V');
    expect(formatEng(37.8, '°'), '37,8 °');
  });
  test('complexes', () {
    expect(formatComplex(const Complex(3, 4)), '3 + j4');
    expect(formatComplex(const Complex(3, -4)), '3 − j4');
    expect(formatComplex(const Complex(0, 2)), 'j2');
    expect(formatComplex(const Complex(0, 5), polar: true), '5 ∠ 90°');
  });
  test('séparation de l\'unité', () {
    final a = splitUnit('4,7 kΩ', 'Ω')!;
    expect(a.numberPart, '4,7');
    expect(a.factor, 1e3);
    final b = splitUnit('12 mA', 'A')!;
    expect(b.factor, 1e-3);
    expect(splitUnit('12', 'A')!.unitGiven, isNull);
    expect(splitUnit('12 kV', 'A'), isNull);
    expect(splitUnit('47 ohms', 'Ω')!.factor, 1);
    expect(splitUnit('22 uF', 'F')!.factor, 1e-6);
    expect(splitUnit('3+4j', null)!.numberPart, '3+4j');
  });
}
