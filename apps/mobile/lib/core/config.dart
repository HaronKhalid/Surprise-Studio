/// Build-time configuration. Override per build with `--dart-define`:
///
///   flutter run --dart-define=API_URL=https://api.example.com/api/v1 \
///               --dart-define=SITE_URL=https://example.com
///
/// The defaults are for local development with `adb reverse tcp:4000 tcp:4000` (and 3000, 9000),
/// which makes the phone's `localhost` reach the dev machine, so one set of URLs works on both
/// emulators and real devices, including the photo URLs the API hands back.
class AppConfig {
  const AppConfig({required this.apiUrl, required this.siteUrl});

  static const fromEnvironment = AppConfig(
    apiUrl: String.fromEnvironment('API_URL', defaultValue: 'http://localhost:4000/api/v1'),
    siteUrl: String.fromEnvironment('SITE_URL', defaultValue: 'http://localhost:3000'),
  );

  final String apiUrl;
  final String siteUrl;

  /// The link a recipient opens.
  String publicLink(String slug) => '${_trim(siteUrl)}/s/$slug';

  /// The creator's draft preview, rendered by the same web app (see docs/api.md).
  Uri previewUri(String token) => Uri.parse('${_trim(siteUrl)}/preview/$token');

  static String _trim(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
