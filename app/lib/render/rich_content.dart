import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../theme.dart';

/// Texte du contenu pédagogique : formules LaTeX en ligne entre $…$, **gras**,
/// listes à puces (« - ») et numérotées (« 1. »).
class RichContent extends StatelessWidget {
  const RichContent(this.text, {super.key, this.style, this.textAlign = TextAlign.start});
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? const TextStyle(fontSize: 15.5, height: 1.5)).copyWith(color: style?.color ?? context.nn.fg);
    final lines = text.split('\n');
    final children = <Widget>[];
    for (final line in lines) {
      final bullet = RegExp(r'^\s*[-•]\s+').firstMatch(line);
      final number = RegExp(r'^\s*(\d+)[.)]\s+').firstMatch(line);
      if (bullet != null || number != null) {
        final rest = line.substring((bullet ?? number)!.end);
        children.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 22,
              child: bullet != null
                  ? Padding(padding: const EdgeInsets.only(top: 9), child: RedDot(size: 6))
                  : Text('${number!.group(1)}.', style: base.copyWith(fontWeight: FontWeight.w600)),
            ),
            Expanded(child: _line(context, rest, base)),
          ]),
        ));
      } else {
        children.add(_line(context, line, base));
      }
    }
    if (children.length == 1) return children.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _line(BuildContext context, String line, TextStyle base) =>
      Text.rich(TextSpan(children: inlineSpans(context, line, base)), textAlign: textAlign);
}

/// Découpe une ligne en morceaux de texte et de formules.
List<InlineSpan> inlineSpans(BuildContext context, String line, TextStyle base) {
  final spans = <InlineSpan>[];
  final parts = splitMath(line);
  for (final p in parts) {
    if (p.isMath) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Math.tex(
          p.text,
          mathStyle: MathStyle.text,
          textStyle: base.copyWith(fontSize: (base.fontSize ?? 15) * 1.02),
          onErrorFallback: (e) => Text(p.text, style: base.copyWith(fontFamily: kFontMono, color: context.nn.accent)),
        ),
      ));
    } else {
      final bold = p.text.split('**');
      for (var i = 0; i < bold.length; i++) {
        if (bold[i].isEmpty) continue;
        spans.add(TextSpan(text: bold[i], style: i.isOdd ? base.copyWith(fontWeight: FontWeight.w600) : base));
      }
    }
  }
  return spans;
}

class MathPart {
  MathPart(this.text, this.isMath);
  final String text;
  final bool isMath;
}

/// Sépare $…$ (formule) du texte ; « \$ » reste un dollar.
List<MathPart> splitMath(String s) {
  final out = <MathPart>[];
  final b = StringBuffer();
  var inMath = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == r'$' && (i == 0 || s[i - 1] != '\\')) {
      if (b.isNotEmpty) out.add(MathPart(b.toString(), inMath));
      b.clear();
      inMath = !inMath;
    } else if (c == r'$') {
      // dollar échappé : retire la barre oblique déjà écrite
      final t = b.toString();
      b
        ..clear()
        ..write(t.substring(0, t.length - 1))
        ..write(r'$');
    } else {
      b.write(c);
    }
  }
  if (b.isNotEmpty) out.add(MathPart(b.toString(), inMath));
  return out;
}

/// Formule centrée, défilable horizontalement si elle est trop large (téléphone).
class DisplayMath extends StatelessWidget {
  const DisplayMath(this.tex, {super.key, this.size = 18});
  final String tex;
  final double size;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Math.tex(
            tex,
            mathStyle: MathStyle.display,
            textStyle: TextStyle(fontSize: size, color: context.nn.fg),
            onErrorFallback: (e) => Text(tex, style: TextStyle(fontFamily: kFontMono, color: context.nn.accent)),
          ),
        ),
      );
}
