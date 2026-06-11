import 'package:url_launcher/url_launcher.dart';

Future<bool> launchDirections({
  String? googleMapsUrl,
  double? lat,
  double? lng,
}) async {
  final fromLink = Uri.tryParse((googleMapsUrl ?? '').trim());
  if (fromLink != null && fromLink.toString().trim().isNotEmpty) {
    if (await canLaunchUrl(fromLink)) {
      return launchUrl(fromLink, mode: LaunchMode.externalApplication);
    }
  }

  if (lat == null || lng == null) return false;

  final urls = <Uri>[
    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
    Uri.parse('http://maps.apple.com/?daddr=$lat,$lng'),
    Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes'),
  ];

  for (final u in urls) {
    if (await canLaunchUrl(u)) {
      return launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  return false;
}
