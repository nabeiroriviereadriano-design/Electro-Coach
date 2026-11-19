import 'dart:io';

import 'package:electro_coach/state/app_state.dart';
import 'package:electro_coach/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// État de l'application sur le vrai contenu, progression en mémoire.
Future<AppState> realState() async {
  final s = AppState(store: MemoryProgressStore(), reader: (p) => File('assets/content/$p').readAsString());
  await s.init();
  if (s.fatalError != null) throw StateError(s.fatalError!);
  return s;
}

Widget wrap(AppState s, Widget home, {Brightness b = Brightness.dark}) => AppScope(
      state: s,
      child: ListenableBuilder(
        listenable: s,
        builder: (c, _) => MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(b), home: home),
      ),
    );

/// Charge les vraies polices (interface, icônes, formules KaTeX) pour les captures.
Future<void> loadFonts() async {
  Future<void> load(String family, List<String> keys) async {
    final l = FontLoader(family);
    for (final k in keys) {
      l.addFont(rootBundle.load(k));
    }
    await l.load();
  }

  await load('Inter', [for (final f in ['Regular', 'Medium', 'SemiBold', 'Italic']) 'assets/fonts/Inter-$f.ttf']);
  await load('Doto', ['assets/fonts/Doto-Bold.ttf', 'assets/fonts/Doto-Black.ttf']);
  await load('JetBrainsMono', ['assets/fonts/JetBrainsMono-Regular.ttf']);
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final byFamily = <String, List<String>>{};
  for (final a in manifest.listAssets()) {
    final m = RegExp(r'packages/flutter_math_fork/.*/(KaTeX_[A-Za-z0-9]+)-[A-Za-z]+\.ttf$').firstMatch(a);
    if (m != null) byFamily.putIfAbsent('packages/flutter_math_fork/${m.group(1)}', () => []).add(a);
  }
  for (final e in byFamily.entries) {
    await load(e.key, e.value);
  }
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final f = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (f.existsSync()) {
      final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      await l.load();
    }
  }
}
