import 'package:coach_core/coach_core.dart';
import 'package:test/test.dart';

Map<String, dynamic> rel(String tag, {bool pre = false, bool draft = false, List<String>? files}) => {
      'tag_name': tag,
      'name': 'BTS Électro Coach ${tag.substring(1)}',
      'body': 'Nouveautés',
      'html_url': 'https://github.com/x/y/releases/tag/$tag',
      'prerelease': pre,
      'draft': draft,
      'published_at': '2026-11-19T12:00:00Z',
      'assets': [
        for (final f in files ?? ['ElectroCoach-Setup-${tag.substring(1)}.exe', 'ElectroCoach-${tag.substring(1)}.apk', 'SHA256SUMS.txt'])
          {'name': f, 'browser_download_url': 'https://github.com/x/y/releases/download/$tag/$f', 'size': 1000}
      ],
    };

void main() {
  test('comparaison de versions', () {
    expect(compareVersions('0.2.0', '0.1.0'), greaterThan(0));
    expect(compareVersions('v0.10.0', '0.9.9'), greaterThan(0));
    expect(compareVersions('1.0.0', '1.0.0+5'), 0);
    expect(compareVersions('1.0', '1.0.1'), lessThan(0));
  });

  test('choix de la mise à jour', () {
    final list = parseReleases([
      rel('v0.3.0', draft: true),
      rel('v0.2.1', pre: true),
      rel('v0.2.0'),
      rel('v0.1.0'),
      rel('v0.4.0', files: ['ElectroCoach-0.4.0.apk']),
    ]);
    expect(list.length, 4);
    expect(newestUpdate(list, '0.1.0', UpdatePlatform.windows)!.version, '0.2.1');
    expect(newestUpdate(list, '0.1.0', UpdatePlatform.windows, includePrereleases: false)!.version, '0.2.0');
    expect(newestUpdate(list, '0.1.0', UpdatePlatform.android)!.version, '0.4.0');
    expect(newestUpdate(list, '0.4.0', UpdatePlatform.android), isNull);
    expect(newestUpdate(list, '0.2.1', UpdatePlatform.windows), isNull);
  });

  test('sommes de contrôle', () {
    final h = 'a' * 64;
    final m = parseChecksums('$h  ElectroCoach-0.2.0.apk\n${'B' * 64} *ElectroCoach-Setup-0.2.0.exe\nligne invalide');
    expect(m['ElectroCoach-0.2.0.apk'], h);
    expect(m['ElectroCoach-Setup-0.2.0.exe'], 'b' * 64);
    expect(m.length, 2);
  });

  test('noms des fichiers', () {
    expect(assetName(UpdatePlatform.windows, '0.2.0'), 'ElectroCoach-Setup-0.2.0.exe');
    expect(assetName(UpdatePlatform.android, '0.2.0'), 'ElectroCoach-0.2.0.apk');
    expect(formatSize(57565184), '54,9 Mo');
  });
}
