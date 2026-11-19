import 'dart:math' as math;

import 'package:coach_core/coach_core.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Courbe(s) d'un bloc « plot » : expressions de [var] tracées sur [from, to].
class PlotView extends StatelessWidget {
  const PlotView({super.key, required this.block, this.env = const {}});
  final Block block;
  final Map<String, Complex> env;

  @override
  Widget build(BuildContext context) {
    final n = context.nn;
    final colors = [n.fg, NColors.red, n.mid, const Color(0xFF2F80ED)];
    final data = _sample();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if ((block.data['title'] ?? '') != '')
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(block.data['title'] as String, style: TextStyle(color: n.mid, fontSize: 13)),
        ),
      AspectRatio(
        aspectRatio: 1.7,
        child: data == null
            ? Center(child: Text('Courbe impossible à tracer', style: TextStyle(color: n.mid)))
            : CustomPaint(
                painter: _PlotPainter(data, colors, n.line, n.mid,
                    (block.data['xLabel'] ?? '') as String, (block.data['yLabel'] ?? '') as String),
              ),
      ),
      if (data != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 16, runSpacing: 4, children: [
            for (var i = 0; i < data.labels.length; i++)
              if (data.labels[i].isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 14, height: 3, color: colors[i % colors.length]),
                  const SizedBox(width: 6),
                  Text(data.labels[i], style: TextStyle(fontSize: 12.5, color: n.mid)),
                ]),
          ]),
        ),
    ]);
  }

  _PlotData? _sample() {
    try {
      final v = (block.data['var'] ?? 't') as String;
      final a = plotBound(block.data['from'], env) ?? 0;
      final b = plotBound(block.data['to'], env) ?? 1;
      if (!(b > a)) return null;
      final samples = (block.data['samples'] ?? 240) as int;
      final curves = <List<Offset>>[];
      final labels = <String>[];
      for (final c in block.data['curves'] as List) {
        final m = c as Map;
        final e = parseExpr(m['expr'] as String);
        final pts = <Offset>[];
        for (var k = 0; k <= samples; k++) {
          final x = a + (b - a) * k / samples;
          final y = e.eval({...env, v: Complex(x)});
          if (y.isFinite) pts.add(Offset(x, y.re));
        }
        curves.add(pts);
        labels.add((m['label'] ?? '') as String);
      }
      return _PlotData(a, b, curves, labels);
    } on Object {
      return null;
    }
  }
}

class _PlotData {
  _PlotData(this.x0, this.x1, this.curves, this.labels);
  final double x0, x1;
  final List<List<Offset>> curves;
  final List<String> labels;
}

class _PlotPainter extends CustomPainter {
  _PlotPainter(this.d, this.colors, this.grid, this.text, this.xLabel, this.yLabel);
  final _PlotData d;
  final List<Color> colors;
  final Color grid, text;
  final String xLabel, yLabel;

  @override
  void paint(Canvas canvas, Size size) {
    var yMin = double.infinity, yMax = -double.infinity;
    for (final c in d.curves) {
      for (final p in c) {
        yMin = math.min(yMin, p.dy);
        yMax = math.max(yMax, p.dy);
      }
    }
    if (!yMin.isFinite) return;
    if (yMax - yMin < 1e-12) {
      yMax += 1;
      yMin -= 1;
    }
    final pad = (yMax - yMin) * 0.08;
    yMin -= pad;
    yMax += pad;
    const left = 8.0, right = 8.0, top = 8.0, bottom = 22.0;
    final w = size.width - left - right, h = size.height - top - bottom;
    Offset map(Offset p) => Offset(left + (p.dx - d.x0) / (d.x1 - d.x0) * w, top + (yMax - p.dy) / (yMax - yMin) * h);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    // grille en points (style matrice)
    for (var i = 0; i <= 8; i++) {
      for (var k = 0; k <= 4; k++) {
        canvas.drawCircle(Offset(left + w * i / 8, top + h * k / 4), 1.1, gridPaint);
      }
    }
    // axe des abscisses (y = 0) s'il est visible
    if (yMin < 0 && yMax > 0) {
      final y0 = map(Offset(d.x0, 0)).dy;
      canvas.drawLine(Offset(left, y0), Offset(left + w, y0), gridPaint..strokeWidth = 1.2);
    }
    for (var i = 0; i < d.curves.length; i++) {
      final pts = d.curves[i];
      if (pts.length < 2) continue;
      final path = Path()..moveTo(map(pts.first).dx, map(pts.first).dy);
      for (final p in pts.skip(1)) {
        final q = map(p);
        path.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colors[i % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round,
      );
    }
    void label(String s, Offset at, {TextAlign align = TextAlign.left}) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(color: text, fontSize: 11, fontFamily: kFontMono)),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = align == TextAlign.right ? at.dx - tp.width : at.dx;
      tp.paint(canvas, Offset(dx, at.dy));
    }

    label(formatNumber(d.x0), Offset(left, size.height - 16));
    label('${formatNumber(d.x1)}  $xLabel'.trim(), Offset(size.width - right, size.height - 16), align: TextAlign.right);
    label(formatNumber(yMax - pad), Offset(left + 2, top));
    if (yLabel.isNotEmpty) label(yLabel, Offset(size.width - right, top), align: TextAlign.right);
  }

  @override
  bool shouldRepaint(_PlotPainter old) => old.d != d;
}
