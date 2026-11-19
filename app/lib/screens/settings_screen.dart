import 'package:coach_core/coach_core.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/update_banner.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final n = context.nn;
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: PageBody(children: [
        const SectionLabel('Année suivie'),
        SegmentedButton<int>(
          segments: const [ButtonSegment(value: 1, label: Text('1re année')), ButtonSegment(value: 2, label: Text('2e année'))],
          selected: {s.year},
          showSelectedIcon: false,
          onSelectionChanged: (v) => s.setYear(v.first),
        ),
        const SectionLabel('Apparence'),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.dark, label: Text('Sombre'), icon: Icon(Icons.dark_mode_outlined)),
            ButtonSegment(value: ThemeMode.light, label: Text('Clair'), icon: Icon(Icons.light_mode_outlined)),
          ],
          selected: {s.themeMode == ThemeMode.light ? ThemeMode.light : ThemeMode.dark},
          showSelectedIcon: false,
          onSelectionChanged: (v) => s.setTheme(v.first),
        ),
        const SectionLabel('Répartition entre les deux années'),
        AppCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SplitScreen())),
          child: Row(children: [
            const Icon(Icons.tune),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Choisir en quelle année travailler chaque domaine. Le référentiel fixe l\'année des maths, '
                'pas celle de la physique-chimie : une répartition est proposée par défaut.',
                style: TextStyle(color: n.mid, fontSize: 13),
              ),
            ),
            Icon(Icons.chevron_right, color: n.mid),
          ]),
        ),
        const SectionLabel('Mises à jour'),
        if (!s.updater.supported)
          Text('Les mises à jour automatiques concernent Windows et Android.', style: TextStyle(color: n.mid, fontSize: 13))
        else ...[
          UpdateBanner(updater: s.updater, showIdle: true),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Mises à jour automatiques'),
                  Text('Vérifie GitHub au démarrage et télécharge la nouvelle version (empreinte SHA-256 contrôlée).',
                      style: TextStyle(color: n.mid, fontSize: 12.5)),
                ]),
              ),
              Switch(value: s.autoUpdate, onChanged: s.setAutoUpdate),
            ]),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: s.checkForUpdates,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Rechercher une mise à jour'),
            ),
          ),
        ],
        const SectionLabel('Données'),
        AppCard(
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Réinitialiser la progression ?'),
                content: const Text('Tes résultats d\'exercices et ta maîtrise des notions seront effacés de cet appareil.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Réinitialiser')),
                ],
              ),
            );
            if (ok == true) await s.resetProgress();
          },
          child: const Row(children: [
            Icon(Icons.restart_alt, color: NColors.red),
            SizedBox(width: 12),
            Expanded(child: Text('Réinitialiser ma progression')),
          ]),
        ),
        const SectionLabel('À propos'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const CoachLogo(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('BTS Électro Coach', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('Version ${AppState.version}', style: TextStyle(color: n.mid, fontSize: 12.5)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Text(
              'Mathématiques et sciences appliquées du BTS Électrotechnique, d\'après le référentiel de l\'arrêté du '
              '21 février 2020 modifié (applicable à la session 2027) et le programme de mathématiques de l\'arrêté du '
              '4 juin 2013. Ta progression reste sur cet appareil : aucun compte, aucun serveur.',
              style: TextStyle(color: n.mid, fontSize: 13, height: 1.45),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Réglage de la répartition 1re / 2e année par domaine et par chapitre.
class SplitScreen extends StatelessWidget {
  const SplitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final n = context.nn;
    final lib = s.library;
    final rows = <({String key, String label, Notion sample})>[];
    for (final subject in Library.subjects) {
      for (final d in lib.domains(subject)) {
        final notions = lib.notionsOf(d);
        if (notions.isEmpty) continue;
        rows.add((key: Parcours.key(d), label: d, sample: notions.first));
        final chapters = <String>{for (final x in notions) x.chapter}..remove('');
        if (chapters.length > 1) {
          for (final c in chapters) {
            rows.add((key: Parcours.key(d, c), label: '   $c', sample: notions.firstWhere((x) => x.chapter == c)));
          }
        }
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Répartition')),
      body: PageBody(children: [
        Text(
          'Un chapitre suit son domaine, sauf si tu lui donnes une année. « Défaut » reprend l\'année du référentiel '
          'ou la répartition proposée.',
          style: TextStyle(color: n.mid, fontSize: 13),
        ),
        const SizedBox(height: 10),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(
                child: Text(r.label,
                    style: TextStyle(fontSize: 14, fontWeight: r.label.startsWith('   ') ? FontWeight.w400 : FontWeight.w600)),
              ),
              DropdownButton<int?>(
                value: s.progress.yearOverrides[r.key],
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(value: null, child: Text('Défaut (${_yearLabel(s.parcours.defaults[r.key] ?? r.sample.year)})')),
                  const DropdownMenuItem(value: 1, child: Text('1re année')),
                  const DropdownMenuItem(value: 2, child: Text('2e année')),
                ],
                onChanged: (v) => s.setYearFor(r.key, v),
              ),
            ]),
          ),
      ]),
    );
  }

  static String _yearLabel(int? y) => y == null ? '—' : (y == 1 ? '1re' : '2e');
}
