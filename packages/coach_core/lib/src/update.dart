/// Logique de mise à jour (sans réseau, testable) : lecture des releases
/// GitHub, comparaison des versions, choix du fichier, sommes de contrôle.
library;

const kGithubRepo = 'nabeiroriviereadriano-design/Electro-Coach';

/// Compare deux versions « 1.2.3 » (préfixe « v » et suffixes ignorés).
/// Résultat < 0 si a < b, 0 si égales, > 0 si a > b.
int compareVersions(String a, String b) {
  List<int> p(String v) => v
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split(RegExp(r'[+\-]'))
      .first
      .split('.')
      .map((e) => int.tryParse(e) ?? 0)
      .toList();
  final x = p(a), y = p(b);
  for (var i = 0; i < 3; i++) {
    final u = i < x.length ? x[i] : 0, v = i < y.length ? y[i] : 0;
    if (u != v) return u.compareTo(v);
  }
  return 0;
}

class ReleaseAsset {
  ReleaseAsset(this.name, this.url, this.size);
  final String name;
  final String url;
  final int size;
}

class Release {
  Release({
    required this.version,
    required this.tag,
    required this.title,
    required this.notes,
    required this.pageUrl,
    required this.prerelease,
    required this.assets,
    required this.publishedAt,
  });

  final String version;
  final String tag;
  final String title;
  final String notes;
  final String pageUrl;
  final bool prerelease;
  final List<ReleaseAsset> assets;
  final DateTime? publishedAt;

  ReleaseAsset? asset(String name) {
    for (final a in assets) {
      if (a.name == name) return a;
    }
    return null;
  }

  factory Release.fromJson(Map<String, dynamic> j) {
    final tag = (j['tag_name'] ?? '').toString();
    return Release(
      version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
      tag: tag,
      title: (j['name'] ?? tag).toString(),
      notes: (j['body'] ?? '').toString(),
      pageUrl: (j['html_url'] ?? 'https://github.com/$kGithubRepo/releases').toString(),
      prerelease: j['prerelease'] == true,
      assets: [
        for (final a in (j['assets'] as List? ?? const []))
          ReleaseAsset(
            (a as Map)['name'].toString(),
            (a['browser_download_url'] ?? '').toString(),
            (a['size'] as num?)?.toInt() ?? 0,
          ),
      ],
      publishedAt: DateTime.tryParse((j['published_at'] ?? '').toString()),
    );
  }
}

/// Lit la réponse de l'API « GET /repos/{dépôt}/releases » (brouillons exclus).
List<Release> parseReleases(List<dynamic> json) => [
      for (final r in json)
        if (r is Map<String, dynamic> && r['draft'] != true && (r['tag_name'] ?? '').toString().isNotEmpty)
          Release.fromJson(r),
    ];

enum UpdatePlatform { windows, android }

/// Nom du fichier à télécharger pour une plateforme.
String assetName(UpdatePlatform p, String version) =>
    p == UpdatePlatform.windows ? 'ElectroCoach-Setup-$version.exe' : 'ElectroCoach-$version.apk';

const checksumsAsset = 'SHA256SUMS.txt';

/// Release la plus récente, strictement plus récente que [current] et qui
/// contient le fichier de la plateforme ; null si l'appli est à jour.
Release? newestUpdate(List<Release> releases, String current, UpdatePlatform platform, {bool includePrereleases = true}) {
  Release? best;
  for (final r in releases) {
    if (r.prerelease && !includePrereleases) continue;
    if (compareVersions(r.version, current) <= 0) continue;
    if (r.asset(assetName(platform, r.version)) == null) continue;
    if (best == null || compareVersions(r.version, best.version) > 0) best = r;
  }
  return best;
}

/// Lit un fichier « sha256sum » : « <empreinte>  <nom> » par ligne.
Map<String, String> parseChecksums(String text) {
  final out = <String, String>{};
  for (final line in text.split('\n')) {
    final m = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+?)\s*$').firstMatch(line.trim());
    if (m != null) out[m.group(2)!] = m.group(1)!.toLowerCase();
  }
  return out;
}

/// Taille lisible : 54,9 Mo.
String formatSize(int bytes) {
  if (bytes <= 0) return '';
  final mo = bytes / (1024 * 1024);
  return '${mo.toStringAsFixed(1).replaceAll('.', ',')} Mo';
}
