import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/barbershop.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_loader.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../data/nearby_repository.dart';

class NearbyMapScreen extends ConsumerStatefulWidget {
  const NearbyMapScreen({super.key});

  @override
  ConsumerState<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends ConsumerState<NearbyMapScreen> {
  Position? _position;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _error = 'Location services disabled');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _position = pos);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopsValue = ref.watch(mappableShopsProvider);
    final pos = _position;

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Nearby', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      child: _error != null
          ? Center(child: Text(_error!, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textMuted)))
          : pos == null
              ? const Center(child: LuxuryLoader())
              : AsyncValueWidget<List<Barbershop>>(
                  value: shopsValue,
                  data: (shops) {
                    final markers = shops
                        .where((s) => s.lat != null && s.lng != null)
                        .map(
                          (s) => Marker(
                            markerId: MarkerId(s.id),
                            position: LatLng(s.lat!, s.lng!),
                            infoWindow: InfoWindow(
                              title: s.name,
                              snippet: s.area,
                              onTap: () => context.push('/shop/${s.id}'),
                            ),
                          ),
                        )
                        .toSet();

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 12.5),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        markers: markers,
                      ),
                    );
                  },
                ),
    );
  }
}
