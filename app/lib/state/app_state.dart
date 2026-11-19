import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coach_core/coach_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../services/updater.dart';

/// Lieu de sauvegarde de la progression (fichier local, rien en ligne).
abstract class ProgressStore {
  Future<String?> read();
  Future<void> write(String data);
}

class MemoryProgressStore implements ProgressStore {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String d) async => data = d;
}

class FileProgressStore implements ProgressStore {
  FileProgressStore(this.file);
  final File file;

  /// Windows : %APPDATA%\ElectroCoach (effacé au choix par le désinstalleur).
  /// Android : dossier privé de l'application.
  static Future<FileProgressStore> standard() async {
    Directory dir;
    final appData = Platform.isWindows ? Platform.environment['APPDATA'] : null;
    if (appData != null) {
      dir = Directory('$appData\\ElectroCoach');
    } else {
      dir = await getApplicationSupportDirectory();
    }
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return FileProgressStore(File('${dir.path}${Platform.pathSeparator}progression.json'));
  }

  @override
  Future<String?> read() async => file.existsSync() ? file.readAsString() : null;

  @override
  Future<void> write(String data) async {
    // écriture atomique : fichier temporaire puis renommage
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(file.path);
  }
}

/// Charge le contenu embarqué dans l'application.
typedef AssetReader = Future<String> Function(String path);

Future<String> bundleReader(String path) => rootBundle.loadString('assets/content/$path');

class AppState extends ChangeNotifier {
  AppState({ProgressStore? store, AssetReader? reader, Updater? updater, this.checkUpdates = true})
      : _store = store,
        _reader = reader ?? bundleReader,
        updater = updater ?? Updater(currentVersion: version);

  ProgressStore? _store;
  final AssetReader _reader;

  /// Mises à jour depuis GitHub.
  final Updater updater;
  final bool checkUpdates;

  late Library library;
  late Parcours parcours;
  ProgressState progress = ProgressState();
  ThemeMode themeMode = ThemeMode.dark;

  bool ready = false;
  String? fatalError;

  static const version = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');

  Future<void> init() async {
    try {
      final notions = await _reader('notions.json');
      final index = jsonDecode(await _reader('index.json')) as Map<String, dynamic>;
      final packs = <String>[];
      for (final p in index['packs'] as List) {
        packs.add(await _reader(p as String));
      }
      library = loadLibrary(notions, packs);
      parcours = Parcours.fromJson(jsonDecode(await _reader('parcours.json')) as Map<String, dynamic>);
      _store ??= await FileProgressStore.standard();
      progress = ProgressState.decode(await _store!.read());
      parcours.overrides
        ..clear()
        ..addAll(progress.yearOverrides);
      themeMode = progress.settings['theme'] == 'light' ? ThemeMode.light : ThemeMode.dark;
      ready = true;
      if (checkUpdates) unawaited(_autoCheck());
    } catch (e, st) {
      fatalError = '$e';
      debugPrint('$e\n$st');
    }
    notifyListeners();
  }

  /// Mises à jour automatiques activées (réglage, oui par défaut).
  bool get autoUpdate => progress.settings['autoUpdate'] != 'off';

  Future<void> setAutoUpdate(bool on) async {
    progress.settings['autoUpdate'] = on ? 'on' : 'off';
    await _save();
    if (on) unawaited(checkForUpdates());
  }

  /// Vérification au démarrage, au plus toutes les 6 heures.
  Future<void> _autoCheck() async {
    if (!autoUpdate || !updater.supported) return;
    final last = DateTime.tryParse(progress.settings['lastUpdateCheck'] ?? '');
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 6)) return;
    await checkForUpdates();
  }

  Future<void> checkForUpdates() async {
    progress.settings['lastUpdateCheck'] = DateTime.now().toIso8601String();
    await _save();
    await updater.check(autoDownload: autoUpdate);
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      await _store?.write(progress.encode());
    } catch (e) {
      debugPrint('Sauvegarde impossible : $e');
    }
  }

  int get year => progress.year;

  Future<void> setYear(int y) async {
    progress.year = y;
    await _save();
  }

  /// Place un domaine (ou un chapitre) dans une année ; null rétablit la valeur par défaut.
  Future<void> setYearFor(String key, int? y) async {
    if (y == null) {
      progress.yearOverrides.remove(key);
      parcours.overrides.remove(key);
    } else {
      progress.yearOverrides[key] = y;
      parcours.overrides[key] = y;
    }
    await _save();
  }

  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    progress.settings['theme'] = m == ThemeMode.light ? 'light' : 'dark';
    await _save();
  }

  Future<void> recordAttempt(Exercise ex, int seed, bool correct) async {
    progress.recordAttempt(ex, seed, correct);
    await _save();
  }

  Future<void> markRead(Course c) async {
    if (progress.coursesRead.contains(c.id)) return;
    progress.markCourseRead(c);
    await _save();
  }

  Future<void> resetProgress() async {
    final keep = Map<String, int>.from(progress.yearOverrides);
    final settings = Map<String, String>.from(progress.settings);
    final y = progress.year;
    progress = ProgressState()
      ..year = y
      ..yearOverrides.addAll(keep)
      ..settings.addAll(settings);
    await _save();
  }

  /// Seed d'un nouveau tirage pour un exercice : jamais deux fois le même d'affilée.
  int nextSeed(Exercise ex) => (progress.attempts[ex.id]?.length ?? 0) * 7919 + ex.id.hashCode.abs() % 1000;

  CoverageReport get coverage => computeCoverage(library);

  List<Notion> notionsOfYear(int y) => parcours.notionsForYear(library, y);
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
