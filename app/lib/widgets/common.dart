import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Anneau de progression rouge (maquettes : « 47 % »).
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 120, this.label, this.caption});
  final double value;
  final double size;
  final String? label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final n = context.nn;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value.clamp(0, 1).toDouble(), n.line, NColors.red),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label ?? '${(value * 100).round()} %',
                style: TextStyle(fontFamily: kFontDot, fontWeight: FontWeight.w900, fontSize: size * 0.22, color: n.fg)),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(caption!, textAlign: TextAlign.center, style: TextStyle(fontSize: size * 0.085, color: n.mid)),
              ),
          ]),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.track, this.fill);
  final double v;
  final Color track, fill;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    // piste en points
    final dots = Paint()..color = track;
    for (var i = 0; i < 60; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / 60;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, 1.6, dots);
    }
    if (v > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * v,
        false,
        Paint()
          ..color = fill
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.track != track;
}

/// Carte cliquable aux coins arrondis.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.highlight = false});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final n = context.nn;
    return Material(
      color: n.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: highlight ? NColors.red : n.line, width: highlight ? 1.4 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Barre de progression fine.
class ThinBar extends StatelessWidget {
  const ThinBar({super.key, required this.value, this.color});
  final double value;
  final Color? color;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1).toDouble(),
          minHeight: 4,
          backgroundColor: context.nn.line,
          color: color ?? NColors.red,
        ),
      );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Text(text.toUpperCase(),
            style: TextStyle(fontSize: 11.5, letterSpacing: 1.4, fontWeight: FontWeight.w600, color: context.nn.mid)),
      );
}

/// Petite pastille de statut.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.filled = false});
  final String text;
  final Color? color;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.nn.mid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? c : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: filled ? context.nn.bg : c)),
    );
  }
}

/// Étoiles de difficulté (1 à 3).
class Difficulty extends StatelessWidget {
  const Difficulty(this.level, {super.key});
  final int level;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 3; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: RedDot(size: 7, color: i <= level ? NColors.red : context.nn.line),
          ),
      ]);
}

/// Mise en page centrée, lisible sur grand écran (Windows) comme sur téléphone.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.padding = const EdgeInsets.fromLTRB(18, 8, 18, 32)});
  final List<Widget> children;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: padding, children: children),
        ),
      );
}

/// Couleur associée à une maîtrise (0 à 1).
Color masteryColor(BuildContext context, double m) {
  if (m >= 0.6) return NColors.red;
  if (m > 0) return context.nn.fg;
  return context.nn.line;
}
