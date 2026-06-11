bool isValidGoogleMapsUrl(String? raw) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return false;
  final uri = Uri.tryParse(v);
  if (uri == null) return false;
  if (uri.scheme != 'https' && uri.scheme != 'http') return false;

  final host = uri.host.toLowerCase();
  final isGoogleHost =
      host == 'maps.google.com' || host.endsWith('.google.com') || host == 'goo.gl' || host.endsWith('.goo.gl') || host == 'maps.app.goo.gl';
  if (!isGoogleHost) return false;

  if (host.contains('google.com')) {
    if (!uri.path.contains('/maps')) return false;
  }

  return true;
}
