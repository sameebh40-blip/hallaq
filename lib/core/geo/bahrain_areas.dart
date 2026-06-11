class BahrainArea {
  final String name;
  final double lat;
  final double lng;

  const BahrainArea({
    required this.name,
    required this.lat,
    required this.lng,
  });
}

const bahrainAreas = <BahrainArea>[
  BahrainArea(name: 'Manama', lat: 26.2235, lng: 50.5876),
  BahrainArea(name: 'Seef', lat: 26.2326, lng: 50.5468),
  BahrainArea(name: 'Juffair', lat: 26.2147, lng: 50.6025),
  BahrainArea(name: 'Riffa', lat: 26.1297, lng: 50.5552),
  BahrainArea(name: 'Muharraq', lat: 26.2578, lng: 50.6119),
  BahrainArea(name: 'Isa Town', lat: 26.1749, lng: 50.5473),
  BahrainArea(name: 'Saar', lat: 26.2150, lng: 50.4867),
  BahrainArea(name: 'Amwaj', lat: 26.2850, lng: 50.6569),
  BahrainArea(name: 'Hamad Town', lat: 26.1153, lng: 50.5063),
  BahrainArea(name: 'Sanabis', lat: 26.2366, lng: 50.5447),
  BahrainArea(name: 'Budaiya', lat: 26.2063, lng: 50.4568),
];

BahrainArea? bahrainAreaByName(String? name) {
  final n = (name ?? '').trim().toLowerCase();
  if (n.isEmpty) return null;
  for (final a in bahrainAreas) {
    if (a.name.toLowerCase() == n) return a;
  }
  return null;
}
