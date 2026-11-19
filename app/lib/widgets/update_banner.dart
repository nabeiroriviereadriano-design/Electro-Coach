import 'package:coach_core/coach_core.dart';
import 'package:flutter/material.dart';

import '../services/updater.dart';
import '../theme.dart';
import 'common.dart';

/// Carte de mise à jour (accueil et réglages) : disponible, téléchargement, prête.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key, required this.updater, this.showIdle = false});
  final Updater updater;

  /// Affiche aussi « à jour » / « erreur » (réglages) ; sinon seulement s'il y a une version.
  final bool showIdle;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: updater,
        builder: (context, _) {
          final u = updater;
          final n = context.nn;
          final active = {UpdateStatus.available, UpdateStatus.downloading, UpdateStatus.ready, UpdateStatus.installing};
          if (!showIdle && !active.contains(u.status)) return const SizedBox.shrink();
          if (u.status == UpdateStatus.idle) return const SizedBox.shrink();
          final r = u.release;
          final size = r == null || u.platform == null ? '' : formatSize(r.asset(assetName(u.platform!, r.version))?.size ?? 0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              highlight: active.contains(u.status),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(
                    switch (u.status) {
                      UpdateStatus.upToDate => Icons.verified_outlined,
                      UpdateStatus.error => Icons.cloud_off_outlined,
                      UpdateStatus.ready => Icons.system_update_alt,
                      _ => Icons.download_outlined,
                    },
                    color: active.contains(u.status) ? NColors.red : n.mid,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        r != null && active.contains(u.status) ? 'Mise à jour ${r.version}' : 'Mises à jour',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (u.message != null) Text(u.message!, style: TextStyle(color: n.mid, fontSize: 13)),
                    ]),
                  ),
                ]),
                if (u.status == UpdateStatus.downloading) ...[
                  const SizedBox(height: 12),
                  ThinBar(value: u.progress),
                  const SizedBox(height: 4),
                  Text('${(u.progress * 100).round()} %${size.isEmpty ? '' : ' de $size'}',
                      style: TextStyle(color: n.mid, fontSize: 12)),
                ],
                if (u.status == UpdateStatus.checking) ...[const SizedBox(height: 12), const ThinBar(value: 0.3)],
                if (r != null && r.notes.trim().isNotEmpty && active.contains(u.status))
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('Nouveautés', style: TextStyle(fontSize: 13, color: n.mid)),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(r.notes.trim(), style: const TextStyle(fontSize: 13, height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
                  if (u.status == UpdateStatus.available && u.isPortable)
                    FilledButton(onPressed: u.openPage, child: const Text('Télécharger')),
                  if (u.status == UpdateStatus.available && !u.isPortable)
                    FilledButton(onPressed: u.download, child: Text('Télécharger${size.isEmpty ? '' : ' ($size)'}')),
                  if (u.status == UpdateStatus.ready)
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: NColors.red, foregroundColor: Colors.white),
                      onPressed: u.install,
                      child: const Text('Installer maintenant'),
                    ),
                  if (u.status == UpdateStatus.error && r != null)
                    OutlinedButton(onPressed: u.openPage, child: const Text('Page de téléchargement')),
                ]),
              ]),
            ),
          );
        },
      );
}
