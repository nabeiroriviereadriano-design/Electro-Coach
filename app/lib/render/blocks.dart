import 'package:coach_core/coach_core.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'circuit.dart';
import 'plot.dart';
import 'rich_content.dart';

/// Affiche une suite de blocs. [render] remplace les modèles [[…]] (exercices).
class BlockList extends StatelessWidget {
  const BlockList(this.blocks, {super.key, this.render, this.env = const {}});
  final List<Block> blocks;
  final String Function(String)? render;
  final Map<String, Complex> env;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in blocks) Padding(padding: const EdgeInsets.only(bottom: 14), child: BlockView(b, render: render, env: env)),
        ],
      );
}

class BlockView extends StatelessWidget {
  const BlockView(this.block, {super.key, this.render, this.env = const {}});
  final Block block;
  final String Function(String)? render;
  final Map<String, Complex> env;

  String _r(String s) {
    if (render == null) return s;
    try {
      return render!(s);
    } on Object {
      return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = context.nn;
    final title = (block.data['title'] ?? '') as String;
    switch (block.type) {
      case 'text':
        return RichContent(_r(block.text));
      case 'tex':
        return DisplayMath(_r(block.tex));
      case 'formula':
        return _Boxed(
          title: title.isEmpty ? 'Formule' : title,
          color: NColors.red,
          icon: Icons.functions,
          child: DisplayMath(_r(block.tex), size: 19),
        );
      case 'method':
        return _Boxed(
          title: title.isEmpty ? 'Méthode' : title,
          color: n.fg,
          icon: Icons.route_outlined,
          child: RichContent(_r(block.text)),
        );
      case 'tip':
        return _Boxed(title: title.isEmpty ? 'Astuce' : title, color: n.mid, icon: Icons.lightbulb_outline, child: RichContent(_r(block.text)));
      case 'warning':
        return _Boxed(
          title: title.isEmpty ? 'Attention' : title,
          color: NColors.red,
          icon: Icons.warning_amber_rounded,
          filled: true,
          child: RichContent(_r(block.text)),
        );
      case 'table':
        return _TableView(block, _r);
      case 'plot':
        return _Card(child: PlotView(block: block, env: env));
      case 'circuit':
        return _Card(child: CircuitView(block: block));
      default:
        return Text('[bloc ${block.type}]', style: TextStyle(color: n.mid));
    }
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.nn.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.nn.line),
        ),
        child: child,
      );
}

class _Boxed extends StatelessWidget {
  const _Boxed({required this.title, required this.color, required this.icon, required this.child, this.filled = false});
  final String title;
  final Color color;
  final IconData icon;
  final Widget child;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final n = context.nn;
    return Container(
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.08) : n.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: filled ? color.withValues(alpha: 0.5) : n.line),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(title.toUpperCase(),
              style: TextStyle(fontSize: 11.5, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: color)),
        ]),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView(this.block, this.r);
  final Block block;
  final String Function(String) r;

  @override
  Widget build(BuildContext context) {
    final n = context.nn;
    final rows = [for (final row in (block.data['rows'] as List? ?? const [])) [for (final c in row as List) '$c']];
    if (rows.isEmpty) return const SizedBox.shrink();
    final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    return LayoutBuilder(builder: (context, box) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: box.maxWidth),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: n.line)),
          clipBehavior: Clip.antiAlias,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder(horizontalInside: BorderSide(color: n.line), verticalInside: BorderSide(color: n.line)),
            children: [
              for (var i = 0; i < rows.length; i++)
                TableRow(
                  decoration: BoxDecoration(color: i == 0 ? n.card : null),
                  children: [
                    for (var k = 0; k < cols; k++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: RichContent(
                          r(k < rows[i].length ? rows[i][k] : ''),
                          style: TextStyle(fontSize: 14, height: 1.4, fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ));
  }
}
