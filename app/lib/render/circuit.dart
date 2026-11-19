import 'dart:math' as math;

import 'package:coach_core/coach_core.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Schéma normalisé simple (symboles CEI) : dipôles en série ou en parallèle
/// alimentés par une source alternative (« ac ») ou continue (« dc »).
class CircuitView extends StatelessWidget {
  const CircuitView({super.key, required this.block});
  final Block block;

  @override
  Widget build(BuildContext context) {
    final n = context.nn;
    final parts = [
      for (final p in (block.data['parts'] as List? ?? const []))
        (type: (p as Map)['type'] as String, label: (p['label'] ?? p['type']) as String)
    ];
    final kind = (block.data['kind'] ?? 'series') as String;
    final source = (block.data['source'] ?? 'ac') as String;
    final caption = (block.data['caption'] ?? '') as String;
    return Column(children: [
      AspectRatio(
        aspectRatio: kind == 'parallel' ? 1.6 : 2.4,
        child: CustomPaint(painter: _CircuitPainter(parts, kind, source, n.fg, NColors.red, n.mid)),
      ),
      if (caption.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(caption, textAlign: TextAlign.center, style: TextStyle(color: n.mid, fontSize: 12.5)),
        ),
    ]);
  }
}

typedef _Part = ({String type, String label});

class _CircuitPainter extends CustomPainter {
  _CircuitPainter(this.parts, this.kind, this.source, this.fg, this.accent, this.mid);
  final List<_Part> parts;
  final String kind, source;
  final Color fg, accent, mid;

  late Paint wire;

  @override
  void paint(Canvas canvas, Size size) {
    wire = Paint()
      ..color = fg
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final left = size.width * 0.12, right = size.width * 0.92;
    final top = size.height * 0.22, bottom = size.height * 0.85;
    final midY = (top + bottom) / 2;
    // source à gauche
    _source(canvas, Offset(left, midY), math.min(size.height * 0.16, 22));
    canvas.drawLine(Offset(left, top), Offset(left, midY - 22), wire);
    canvas.drawLine(Offset(left, midY + 22), Offset(left, bottom), wire);
    _text(canvas, source == 'ac' ? 'u(t)' : 'U', Offset(left - 14, midY), mid, align: TextAlign.right);

    if (kind == 'parallel') {
      canvas.drawLine(Offset(left, top), Offset(right, top), wire);
      canvas.drawLine(Offset(left, bottom), Offset(right, bottom), wire);
      final n = parts.length;
      for (var i = 0; i < n; i++) {
        final x = left + (right - left) * (i + 1) / n;
        final len = (bottom - top) * 0.34;
        final c = Offset(x, midY);
        canvas.drawLine(Offset(x, top), Offset(x, midY - len / 2), wire);
        canvas.drawLine(Offset(x, midY + len / 2), Offset(x, bottom), wire);
        _component(canvas, parts[i].type, c, len, vertical: true);
        _text(canvas, parts[i].label, Offset(x + 14, midY - 8), fg);
      }
      _arrow(canvas, Offset(left + 8, top), Offset(left + 40, top));
      _text(canvas, 'i', Offset(left + 22, top - 22), accent);
      return;
    }
    // série : composants sur le fil du haut
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), wire);
    canvas.drawLine(Offset(right, top), Offset(right, bottom), wire);
    final n = parts.length;
    final slot = (right - left) / n;
    final len = math.min(slot * 0.56, 70.0);
    var x = left;
    for (var i = 0; i < n; i++) {
      final c = Offset(left + slot * (i + 0.5), top);
      canvas.drawLine(Offset(x, top), Offset(c.dx - len / 2, top), wire);
      _component(canvas, parts[i].type, c, len);
      _text(canvas, parts[i].label, Offset(c.dx, top - 26), fg, align: TextAlign.center);
      x = c.dx + len / 2;
    }
    canvas.drawLine(Offset(x, top), Offset(right, top), wire);
    _arrow(canvas, Offset(right, top + 10), Offset(right, top + 40));
    _text(canvas, 'i', Offset(right + 8, top + 14), accent);
  }

  void _component(Canvas canvas, String type, Offset c, double len, {bool vertical = false}) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (vertical) canvas.rotate(math.pi / 2);
    final h = len * 0.32;
    switch (type) {
      case 'R':
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: len, height: h), wire);
        break;
      case 'L':
        // bobine : quatre demi-cercles
        final r = len / 8;
        for (var k = 0; k < 4; k++) {
          canvas.drawArc(Rect.fromCircle(center: Offset(-len / 2 + r * (2 * k + 1), 0), radius: r), math.pi, math.pi, false, wire);
        }
        break;
      case 'C':
        final g = len * 0.09;
        canvas.drawLine(Offset(-len / 2, 0), Offset(-g, 0), wire);
        canvas.drawLine(Offset(g, 0), Offset(len / 2, 0), wire);
        canvas.drawLine(Offset(-g, -h * 1.2), Offset(-g, h * 1.2), wire..strokeWidth = 2.6);
        canvas.drawLine(Offset(g, -h * 1.2), Offset(g, h * 1.2), wire);
        wire.strokeWidth = 2;
        break;
      default:
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: len, height: h), wire);
    }
    canvas.restore();
  }

  void _source(Canvas canvas, Offset c, double r) {
    if (source == 'ac') {
      canvas.drawCircle(c, r, wire);
      final p = Path()..moveTo(c.dx - r * 0.55, c.dy);
      for (var k = 1; k <= 20; k++) {
        final t = k / 20;
        p.lineTo(c.dx - r * 0.55 + r * 1.1 * t, c.dy - r * 0.35 * math.sin(2 * math.pi * t));
      }
      canvas.drawPath(p, Paint()
        ..color = accent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke);
    } else {
      canvas.drawLine(Offset(c.dx - r, c.dy - 4), Offset(c.dx + r, c.dy - 4), wire);
      canvas.drawLine(Offset(c.dx - r / 2, c.dy + 4), Offset(c.dx + r / 2, c.dy + 4), wire..strokeWidth = 3.5);
      wire.strokeWidth = 2;
    }
  }

  void _arrow(Canvas canvas, Offset a, Offset b) {
    final p = Paint()
      ..color = accent
      ..strokeWidth = 2;
    canvas.drawLine(a, b, p);
    final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
    for (final s in const [-1, 1]) {
      canvas.drawLine(b, b - Offset(math.cos(ang + s * 0.5), math.sin(ang + s * 0.5)) * 8, p);
    }
  }

  void _text(Canvas canvas, String s, Offset at, Color color, {TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: kFontBody)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (align == TextAlign.right) dx -= tp.width;
    if (align == TextAlign.center) dx -= tp.width / 2;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_CircuitPainter old) => old.parts != parts || old.fg != fg;
}
