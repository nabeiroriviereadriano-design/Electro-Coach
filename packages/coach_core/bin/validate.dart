// Vérifie tout le contenu de l'application et affiche la couverture du programme.
// Usage (depuis packages/coach_core) : dart run bin/validate.dart [dossier_contenu]
import 'dart:io';

import 'package:coach_core/coach_core.dart';

void main(List<String> args) {
  final dir = Directory(args.isNotEmpty ? args.first : '../../app/assets/content');
  final notions = File('${dir.path}/notions.json').readAsStringSync();
  final packs = Directory('${dir.path}/packs')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .map((f) => f.readAsStringSync());
  final lib = loadLibrary(notions, packs);
  final issues = validate(lib);
  stdout.write(report(lib, issues));
  if (issues.any((i) => i.error)) exitCode = 1;
}
