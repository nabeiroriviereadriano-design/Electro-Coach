import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coach_core/coach_core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

enum UpdateStatus { idle, checking, upToDate, available, downloading, ready, installing, error }

/// Téléchargement HTTP (remplaçable dans les tests).
abstract class UpdateNetwork {
  Future<String> getText(Uri url);
  Future<void> download(Uri url, File dest, void Function(int received, int total) onProgress);
}

class HttpUpdateNetwork implements UpdateNetwork {
  HttpClient _client() => HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..userAgent = 'ElectroCoach-Updater';

  @override
  Future<String> getText(Uri url) async {
    final c = _client();
    try {
      final req = await c.getUrl(url);
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: url);
      return await res.transform(utf8.decoder).join();
    } finally {
      c.close();
    }
  }

  @override
  Future<void> download(Uri url, File dest, void Function(int, int) onProgress) async {
    final c = _client();
    try {
      final req = await c.getUrl(url);
      final res = await req.close(); // suit les redirections de GitHub
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: url);
      final total = res.contentLength;
      var received = 0;
      final sink = dest.openWrite();
      try {
        await for (final chunk in res) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(received, total);
        }
      } finally {
        await sink.close();
      }
    } finally {
      c.close();
    }
  }
}

/// Mises à jour depuis les releases GitHub du projet.
///
/// 1. Vérification au démarrage (au plus toutes les 6 h) ou à la demande.
/// 2. Téléchargement automatique du fichier de la plateforme, contrôlé par
///    son empreinte SHA-256 publiée dans la release (SHA256SUMS.txt).
/// 3. Installation : Windows → installateur silencieux puis relance de
///    l'appli ; Android → installateur du système (une confirmation).
class Updater extends ChangeNotifier {
  Updater({required this.currentVersion, UpdateNetwork? network, this.platformOverride})
      : network = network ?? HttpUpdateNetwork();

  final String currentVersion;
  final UpdateNetwork network;
  final UpdatePlatform? platformOverride;

  static const _channel = MethodChannel('electro_coach/update');

  UpdateStatus status = UpdateStatus.idle;
  Release? release;
  double progress = 0;
  String? message;
  File? file;

  UpdatePlatform? get platform {
    if (platformOverride != null) return platformOverride;
    if (kIsWeb) return null;
    if (Platform.isWindows) return UpdatePlatform.windows;
    if (Platform.isAndroid) return UpdatePlatform.android;
    return null;
  }

  bool get supported => platform != null;

  /// Version portable (hors du dossier d'installation) : pas d'installation
  /// automatique, on ouvre la page de téléchargement.
  bool get isPortable {
    if (platform != UpdatePlatform.windows || platformOverride != null) return false;
    final exe = Platform.resolvedExecutable.toLowerCase();
    return !exe.contains(r'\programs\electro coach\');
  }

  void _set(UpdateStatus s, {String? msg}) {
    status = s;
    message = msg;
    notifyListeners();
  }

  /// Cherche une version plus récente. [autoDownload] : télécharge aussitôt.
  Future<void> check({bool autoDownload = true}) async {
    final p = platform;
    if (p == null || status == UpdateStatus.checking || status == UpdateStatus.downloading) return;
    _set(UpdateStatus.checking);
    try {
      final body = await network.getText(Uri.parse('https://api.github.com/repos/$kGithubRepo/releases?per_page=15'));
      final list = parseReleases(jsonDecode(body) as List<dynamic>);
      final r = newestUpdate(list, currentVersion, p);
      release = r;
      if (r == null) {
        _set(UpdateStatus.upToDate, msg: 'BTS Électro Coach est à jour (version $currentVersion).');
        return;
      }
      _set(UpdateStatus.available, msg: 'Version ${r.version} disponible.');
      if (autoDownload && !isPortable) await download();
    } on Object catch (e) {
      _set(UpdateStatus.error, msg: 'Vérification impossible (${_short(e)}). Réessaie plus tard.');
    }
  }

  Future<void> download() async {
    final r = release, p = platform;
    if (r == null || p == null) return;
    final asset = r.asset(assetName(p, r.version));
    if (asset == null) return;
    _set(UpdateStatus.downloading, msg: 'Téléchargement de la version ${r.version}…');
    progress = 0;
    try {
      final sums = r.asset(checksumsAsset);
      if (sums == null) throw const FormatException('empreinte SHA-256 absente de la release');
      final expected = parseChecksums(await network.getText(Uri.parse(sums.url)))[asset.name];
      if (expected == null) throw const FormatException('empreinte du fichier introuvable');
      final dir = Directory('${(await getTemporaryDirectory()).path}${Platform.pathSeparator}updates');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);
      final dest = File('${dir.path}${Platform.pathSeparator}${asset.name}');
      await network.download(Uri.parse(asset.url), dest, (got, total) {
        final t = total > 0 ? total : asset.size;
        progress = t > 0 ? (got / t).clamp(0, 1).toDouble() : 0;
        notifyListeners();
      });
      final digest = await sha256.bind(dest.openRead()).first;
      if (digest.toString() != expected) {
        dest.deleteSync();
        throw const FormatException('fichier corrompu (empreinte SHA-256 différente)');
      }
      file = dest;
      _set(UpdateStatus.ready, msg: 'La version ${r.version} est prête à être installée.');
    } on Object catch (e) {
      _set(UpdateStatus.error, msg: 'Téléchargement impossible (${_short(e)}).');
    }
  }

  /// Lance l'installation. Sous Windows, l'appli se ferme et l'installateur
  /// la relance une fois la mise à jour faite.
  Future<void> install() async {
    final f = file, p = platform;
    if (f == null || p == null) return;
    _set(UpdateStatus.installing, msg: 'Installation…');
    try {
      if (p == UpdatePlatform.windows) {
        await Process.start(
          f.path,
          ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS', '/RELAUNCH=1'],
          mode: ProcessStartMode.detached,
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
        exit(0);
      } else {
        final r = await _channel.invokeMethod<String>('installApk', {'path': f.path});
        if (r == 'permission') {
          _set(UpdateStatus.ready,
              msg: 'Autorise « Installer des applis inconnues » pour BTS Électro Coach, puis touche à nouveau Installer.');
        } else {
          _set(UpdateStatus.ready, msg: 'Confirme l\'installation dans la fenêtre d\'Android.');
        }
      }
    } on Object catch (e) {
      _set(UpdateStatus.error, msg: 'Installation impossible (${_short(e)}).');
    }
  }

  /// Ouvre la page de la release dans le navigateur.
  Future<void> openPage() async {
    final url = release?.pageUrl ?? 'https://github.com/$kGithubRepo/releases';
    try {
      if (platform == UpdatePlatform.android) {
        await _channel.invokeMethod('openUrl', {'url': url});
      } else if (Platform.isWindows) {
        await Process.start('rundll32', ['url.dll,FileProtocolHandler', url], mode: ProcessStartMode.detached);
      }
    } on Object catch (e) {
      debugPrint('Ouverture impossible : $e');
    }
  }

  static String _short(Object e) {
    final s = e.toString().replaceFirst(RegExp(r'^[A-Za-z]+Exception: '), '');
    return s.length > 90 ? '${s.substring(0, 90)}…' : s;
  }
}
