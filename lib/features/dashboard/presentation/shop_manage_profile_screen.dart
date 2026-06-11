import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/media/media_service.dart';
import '../../../core/errors/user_facing_error.dart';
import '../../../core/geo/maps_url_validator.dart';
import '../../../core/models/barbershop.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/hallaq_images.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_ui.dart';
import '../../../core/widgets/luxury_button.dart';
import '../../../core/widgets/luxury_icon_button.dart';
import '../../../core/widgets/luxury_network_image.dart';
import '../../../core/widgets/luxury_scaffold.dart';
import '../../shop/data/shop_repository.dart';

class ShopManageProfileScreen extends ConsumerStatefulWidget {
  const ShopManageProfileScreen({super.key});

  @override
  ConsumerState<ShopManageProfileScreen> createState() => _ShopManageProfileScreenState();
}

class _ShopManageProfileScreenState extends ConsumerState<ShopManageProfileScreen> {
  final _name = TextEditingController();
  final _area = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _googleMapsUrl = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final Map<String, _DayHours> _openingHours = {};
  bool? _homeService;
  Uint8List? _pendingLogoBytes;
  Uint8List? _pendingCoverBytes;
  bool _busy = false;
  double? _progress;

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _address.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _googleMapsUrl.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  static const _dayKeys = <({String key, String label})>[
    (key: 'mon', label: 'Monday'),
    (key: 'tue', label: 'Tuesday'),
    (key: 'wed', label: 'Wednesday'),
    (key: 'thu', label: 'Thursday'),
    (key: 'fri', label: 'Friday'),
    (key: 'sat', label: 'Saturday'),
    (key: 'sun', label: 'Sunday'),
  ];

  String _fmt(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  List<String> _timeOptions() {
    final out = <String>[];
    for (var h = 0; h < 24; h++) {
      out.add('${h.toString().padLeft(2, '0')}:00');
      out.add('${h.toString().padLeft(2, '0')}:30');
    }
    return out;
  }

  TimeOfDay _parseTime(String raw, {required TimeOfDay fallback}) {
    final parts = raw.split(':').map((e) => e.trim()).toList(growable: false);
    if (parts.length < 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return fallback;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  ({TimeOfDay start, TimeOfDay end})? _parseRange(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    final parts = v.split('-').map((e) => e.trim()).toList(growable: false);
    if (parts.length != 2) return null;
    final start = _parseTime(parts[0], fallback: const TimeOfDay(hour: 10, minute: 0));
    final end = _parseTime(parts[1], fallback: const TimeOfDay(hour: 22, minute: 0));
    return (start: start, end: end);
  }

  void _initOpeningHours(Map<String, dynamic>? raw) {
    if (_openingHours.isNotEmpty) return;
    final hours = raw ?? const <String, dynamic>{};
    for (final d in _dayKeys) {
      final v = (hours[d.key] ?? '').toString().trim();
      final parsed = _parseRange(v);
      if (parsed == null) {
        _openingHours[d.key] = _DayHours.closed();
        continue;
      }
      _openingHours[d.key] = _DayHours(open: true, start: parsed.start, end: parsed.end);
    }
  }

  Future<void> _pickImage({required bool cover}) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: cover ? 1800 : 900,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      if (cover) {
        _pendingCoverBytes = bytes;
      } else {
        _pendingLogoBytes = bytes;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final shopValue = ref.watch(myShopProvider);

    Future<void> save(Barbershop shop) async {
      if (_busy) return;
      final maps = _googleMapsUrl.text.trim();
      if (maps.isNotEmpty && !isValidGoogleMapsUrl(maps)) {
        showErrorSnackBar(context, 'Invalid Google Maps link');
        return;
      }

      final lat = double.tryParse(_lat.text.trim());
      final lng = double.tryParse(_lng.text.trim());

      setState(() {
        _busy = true;
        _progress = 0;
      });

      try {
        final repo = ref.read(shopRepositoryProvider);
        final media = ref.read(mediaServiceProvider);
        final storage = ref.read(storageServiceProvider);

        final steps = 1 + (_pendingLogoBytes != null ? 1 : 0) + (_pendingCoverBytes != null ? 1 : 0);
        var done = 0;

        void tick() {
          done += 1;
          if (!mounted) return;
          setState(() => _progress = done / steps);
        }

        String? nextLogoPath;
        String? nextLogoUrl;
        String? nextCoverPath;
        String? nextCoverUrl;

        if (_pendingLogoBytes != null) {
          final stored = await media.uploadImage(
            bucket: 'shop-images',
            pathPrefix: 'shops/${shop.id}',
            bytes: _pendingLogoBytes!,
            options: const MediaImageProcessOptions(cropAspectRatio: 1, maxWidth: 512, maxHeight: 512),
            uploadThumbnail: false,
          );
          nextLogoPath = stored.path;
          nextLogoUrl = media.publicUrlFor(bucket: 'shop-images', path: stored.path);
          tick();
        }

        if (_pendingCoverBytes != null) {
          final stored = await media.uploadImage(
            bucket: 'shop-images',
            pathPrefix: 'shops/${shop.id}',
            bytes: _pendingCoverBytes!,
            options: const MediaImageProcessOptions(cropAspectRatio: 16 / 9, maxWidth: 1280, maxHeight: 720),
            uploadThumbnail: false,
          );
          nextCoverPath = stored.path;
          nextCoverUrl = media.publicUrlFor(bucket: 'shop-images', path: stored.path);
          tick();
        }

        final openingHours = <String, dynamic>{};
        for (final d in _dayKeys) {
          final h = _openingHours[d.key] ?? _DayHours.closed();
          if (!h.open) continue;
          openingHours[d.key] = '${_fmt(h.start)}-${_fmt(h.end)}';
        }

        await repo.updateShop(
          shopId: shop.id,
          name: _name.text,
          area: _area.text,
          address: _address.text,
          phone: _phone.text,
          whatsapp: _whatsapp.text,
          googleMapsUrl: maps,
          lat: lat,
          lng: lng,
          openingHours: openingHours,
          homeService: _homeService ?? false,
          logoPath: nextLogoPath,
          logoUrl: nextLogoUrl,
          coverPath: nextCoverPath,
          coverUrl: nextCoverUrl,
        );

        if (nextLogoPath != null && (shop.logoPath ?? '').trim().isNotEmpty && shop.logoPath != nextLogoPath) {
          try {
            await storage.removeObject(bucket: 'shop-images', path: shop.logoPath!.trim());
          } catch (_) {}
        }
        if (nextCoverPath != null && (shop.coverPath ?? '').trim().isNotEmpty && shop.coverPath != nextCoverPath) {
          try {
            await storage.removeObject(bucket: 'shop-images', path: shop.coverPath!.trim());
          } catch (_) {}
        }

        tick();

        ref.invalidate(myShopProvider);
        ref.invalidate(featuredShopsProvider);
        ref.invalidate(shopByIdProvider(shop.id));

        if (!context.mounted) return;
        setState(() {
          _pendingLogoBytes = null;
          _pendingCoverBytes = null;
        });
        showSuccessSnackBar(context, 'Saved');
      } catch (e) {
        if (!context.mounted) return;
        showErrorSnackBar(context, e);
      } finally {
        if (mounted) {
          setState(() {
            _busy = false;
            _progress = null;
          });
        }
      }
    }

    return LuxuryScaffold(
      header: LuxuryTopBar(
        leading: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
        title: Text('Manage shop', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
      child: AsyncValueWidget(
        value: shopValue,
        data: (shop) {
          if (shop == null) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: HallaqCard(glass: true, child: Text('No shop assigned to this account.')),
            );
          }

          _name.text = _name.text.isEmpty ? shop.name : _name.text;
          _area.text = _area.text.isEmpty ? (shop.area ?? '') : _area.text;
          _address.text = _address.text.isEmpty ? (shop.address ?? '') : _address.text;
          _phone.text = _phone.text.isEmpty ? (shop.phone ?? '') : _phone.text;
          _whatsapp.text = _whatsapp.text.isEmpty ? (shop.whatsapp ?? '') : _whatsapp.text;
          _googleMapsUrl.text = _googleMapsUrl.text.isEmpty ? (shop.googleMapsUrl ?? '') : _googleMapsUrl.text;
          _lat.text = _lat.text.isEmpty ? (shop.lat?.toString() ?? '') : _lat.text;
          _lng.text = _lng.text.isEmpty ? (shop.lng?.toString() ?? '') : _lng.text;
          _homeService ??= shop.homeService;
          _initOpeningHours(shop.openingHours);

          final times = _timeOptions();

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 140),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    child: SizedBox(
                      height: 170,
                      width: double.infinity,
                      child: _pendingCoverBytes != null
                          ? Image.memory(_pendingCoverBytes!, fit: BoxFit.cover)
                          : LuxuryNetworkImage(
                              imageUrl: shop.coverUrl,
                              fallbackUrl: HallaqImages.shopCover(variant: '01'),
                              borderRadius: BorderRadius.zero,
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: HallaqButton(
                          label: 'Change cover',
                          expanded: true,
                          icon: Icons.photo_library_rounded,
                          variant: HallaqButtonVariant.secondary,
                          onPressed: _busy ? null : () => _pickImage(cover: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_pendingCoverBytes != null)
                        HallaqButton(
                          label: 'Remove',
                          icon: Icons.close_rounded,
                          variant: HallaqButtonVariant.secondary,
                          onPressed: _busy ? null : () => setState(() => _pendingCoverBytes = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: SizedBox(
                          width: 66,
                          height: 66,
                          child: _pendingLogoBytes != null
                              ? Image.memory(_pendingLogoBytes!, fit: BoxFit.cover)
                              : LuxuryNetworkImage(
                                  imageUrl: shop.logoUrl,
                                  fallbackUrl: HallaqImages.shopLogo(variant: '01'),
                                  borderRadius: BorderRadius.zero,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(shop.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: HallaqButton(
                          label: 'Change logo',
                          expanded: true,
                          icon: Icons.photo_library_rounded,
                          variant: HallaqButtonVariant.secondary,
                          onPressed: _busy ? null : () => _pickImage(cover: false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_pendingLogoBytes != null)
                        HallaqButton(
                          label: 'Remove',
                          icon: Icons.close_rounded,
                          variant: HallaqButtonVariant.secondary,
                          onPressed: _busy ? null : () => setState(() => _pendingLogoBytes = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Basic Info',
                    child: Column(
                      children: [
                        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
                        const SizedBox(height: 12),
                        TextField(controller: _area, decoration: const InputDecoration(labelText: 'Area')),
                        const SizedBox(height: 12),
                        TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Contact',
                    child: Column(
                      children: [
                        TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
                        const SizedBox(height: 12),
                        TextField(controller: _whatsapp, decoration: const InputDecoration(labelText: 'WhatsApp')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Location',
                    child: Column(
                      children: [
                        TextField(controller: _googleMapsUrl, decoration: const InputDecoration(labelText: 'Google Maps Link')),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _lat,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Latitude'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _lng,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Longitude'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Business Settings',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile.adaptive(
                          value: _homeService ?? false,
                          onChanged: _busy ? null : (v) => setState(() => _homeService = v),
                          title: const Text('Home Service'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 10),
                        Text('Opening Hours', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        ..._dayKeys.map((d) {
                          final h = _openingHours[d.key] ?? _DayHours.closed();
                          final startV = _fmt(h.start);
                          final endV = _fmt(h.end);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: HallaqCard(
                              glass: true,
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 44,
                                        child: Text(
                                          d.label,
                                          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                      const Spacer(),
                                      Switch.adaptive(
                                        value: h.open,
                                        onChanged: _busy
                                            ? null
                                            : (v) => setState(() => _openingHours[d.key] = h.copyWith(open: v)),
                                      ),
                                    ],
                                  ),
                                  if (h.open) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            key: ValueKey('open_${d.key}_$startV'),
                                            initialValue: times.contains(startV) ? startV : times.first,
                                            items: times.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(growable: false),
                                            onChanged: _busy
                                                ? null
                                                : (v) => setState(() {
                                                      final t = _parseTime(v ?? times.first, fallback: h.start);
                                                      _openingHours[d.key] = h.copyWith(start: t);
                                                    }),
                                            decoration: const InputDecoration(labelText: 'Open'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            key: ValueKey('close_${d.key}_$endV'),
                                            initialValue: times.contains(endV) ? endV : times.last,
                                            items: times.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(growable: false),
                                            onChanged: _busy
                                                ? null
                                                : (v) => setState(() {
                                                      final t = _parseTime(v ?? times.last, fallback: h.end);
                                                      _openingHours[d.key] = h.copyWith(end: t);
                                                    }),
                                            decoration: const InputDecoration(labelText: 'Close'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_busy)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LinearProgressIndicator(value: _progress),
                        ),
                      if (_busy) const SizedBox(height: 10),
                      LuxuryButton(
                        label: 'Save',
                        isLoading: _busy,
                        onPressed: _busy ? null : () => save(shop),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayHours {
  final bool open;
  final TimeOfDay start;
  final TimeOfDay end;

  const _DayHours({required this.open, required this.start, required this.end});

  factory _DayHours.closed() => const _DayHours(open: false, start: TimeOfDay(hour: 10, minute: 0), end: TimeOfDay(hour: 22, minute: 0));

  _DayHours copyWith({bool? open, TimeOfDay? start, TimeOfDay? end}) {
    return _DayHours(open: open ?? this.open, start: start ?? this.start, end: end ?? this.end);
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return HallaqCard(
      glass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
