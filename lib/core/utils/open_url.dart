import 'package:url_launcher/url_launcher.dart';

/// Abre una URL externa en el navegador. Devuelve `false` si no se pudo.
Future<bool> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
