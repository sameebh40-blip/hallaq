import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/luxury_icon_button.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _handled = false;

  void _handleCode(String raw) {
    if (_handled) return;
    final v = raw.trim();
    if (v.isEmpty) return;

    Uri? uri;
    try {
      uri = Uri.parse(v);
    } catch (_) {
      uri = null;
    }

    String? route;

    if (uri != null) {
      final scheme = uri.scheme.toLowerCase();
      if (scheme == 'barber' && uri.path.trim().isNotEmpty) {
        route = '/barber/${uri.pathSegments.isNotEmpty ? uri.pathSegments.first : uri.path.trim()}';
      } else if (scheme == 'shop' && uri.path.trim().isNotEmpty) {
        route = '/shop/${uri.pathSegments.isNotEmpty ? uri.pathSegments.first : uri.path.trim()}';
      } else if (scheme == 'book' || scheme == 'booking') {
        final shopId = uri.queryParameters['shopId'] ?? uri.queryParameters['shop_id'];
        final barberId = uri.queryParameters['barberId'] ?? uri.queryParameters['barber_id'];
        final serviceId = uri.queryParameters['serviceId'] ?? uri.queryParameters['service_id'];
        route = '/booking/new'
            '${shopId == null ? '' : '?shopId=${Uri.encodeQueryComponent(shopId)}'}'
            '${barberId == null ? '' : '${shopId == null ? '?' : '&'}barberId=${Uri.encodeQueryComponent(barberId)}'}'
            '${serviceId == null ? '' : '${(shopId == null && barberId == null) ? '?' : '&'}serviceId=${Uri.encodeQueryComponent(serviceId)}'}';
      } else if (scheme == 'review' || scheme == 'reviews') {
        final targetType = uri.queryParameters['targetType'] ?? uri.queryParameters['target_type'] ?? 'shop';
        final targetId = uri.queryParameters['targetId'] ?? uri.queryParameters['target_id'] ?? '';
        if (targetId.trim().isNotEmpty) {
          route = '/reviews?targetType=${Uri.encodeQueryComponent(targetType)}&targetId=${Uri.encodeQueryComponent(targetId)}';
        }
      } else if (scheme == 'discover') {
        final reel = uri.queryParameters['reel'];
        route = (reel != null && reel.trim().isNotEmpty) ? '/discover?reel=${Uri.encodeQueryComponent(reel)}' : '/discover';
      } else {
        final seg = uri.pathSegments;
        if (seg.isNotEmpty) {
          if (seg.length >= 2 && seg[0] == 'barber') route = '/barber/${seg[1]}';
          if (seg.length >= 2 && seg[0] == 'shop') route = '/shop/${seg[1]}';
          if (seg.first == 'book') {
            final shopId = uri.queryParameters['shopId'] ?? uri.queryParameters['shop_id'];
            final barberId = uri.queryParameters['barberId'] ?? uri.queryParameters['barber_id'];
            final serviceId = uri.queryParameters['serviceId'] ?? uri.queryParameters['service_id'];
            route = '/booking/new'
                '${shopId == null ? '' : '?shopId=${Uri.encodeQueryComponent(shopId)}'}'
                '${barberId == null ? '' : '${shopId == null ? '?' : '&'}barberId=${Uri.encodeQueryComponent(barberId)}'}'
                '${serviceId == null ? '' : '${(shopId == null && barberId == null) ? '?' : '&'}serviceId=${Uri.encodeQueryComponent(serviceId)}'}';
          }
          if (seg.first == 'review') {
            final targetType = uri.queryParameters['targetType'] ?? uri.queryParameters['target_type'] ?? 'shop';
            final targetId = uri.queryParameters['targetId'] ?? uri.queryParameters['target_id'] ?? '';
            if (targetId.trim().isNotEmpty) {
              route = '/reviews?targetType=${Uri.encodeQueryComponent(targetType)}&targetId=${Uri.encodeQueryComponent(targetId)}';
            }
          }
          if (seg.first == 'discover') {
            final reel = uri.queryParameters['reel'];
            route = (reel != null && reel.trim().isNotEmpty) ? '/discover?reel=${Uri.encodeQueryComponent(reel)}' : '/discover';
          }
        }
      }
    }

    if (route == null) {
      final low = v.toLowerCase();
      if (low.startsWith('barber:')) route = '/barber/${v.substring(7).trim()}';
      if (low.startsWith('shop:')) route = '/shop/${v.substring(5).trim()}';
      if (low.startsWith('discover:')) {
        final id = v.substring(9).trim();
        route = id.isEmpty ? '/discover' : '/discover?reel=${Uri.encodeQueryComponent(id)}';
      }
      if (low.startsWith('hallaq://')) {
        try {
          final u = Uri.parse(v);
          final seg = u.pathSegments;
          if (seg.length >= 2 && seg[0] == 'barber') route = '/barber/${seg[1]}';
          if (seg.length >= 2 && seg[0] == 'shop') route = '/shop/${seg[1]}';
          if (seg.isNotEmpty && seg.first == 'book') {
            final shopId = u.queryParameters['shopId'] ?? u.queryParameters['shop_id'];
            final barberId = u.queryParameters['barberId'] ?? u.queryParameters['barber_id'];
            final serviceId = u.queryParameters['serviceId'] ?? u.queryParameters['service_id'];
            route = '/booking/new'
                '${shopId == null ? '' : '?shopId=${Uri.encodeQueryComponent(shopId)}'}'
                '${barberId == null ? '' : '${shopId == null ? '?' : '&'}barberId=${Uri.encodeQueryComponent(barberId)}'}'
                '${serviceId == null ? '' : '${(shopId == null && barberId == null) ? '?' : '&'}serviceId=${Uri.encodeQueryComponent(serviceId)}'}';
          }
          if (seg.isNotEmpty && seg.first == 'review') {
            final targetType = u.queryParameters['targetType'] ?? u.queryParameters['target_type'] ?? 'shop';
            final targetId = u.queryParameters['targetId'] ?? u.queryParameters['target_id'] ?? '';
            if (targetId.trim().isNotEmpty) {
              route = '/reviews?targetType=${Uri.encodeQueryComponent(targetType)}&targetId=${Uri.encodeQueryComponent(targetId)}';
            }
          }
        } catch (_) {}
      }
    }

    if (route == null) return;
    _handled = true;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              fit: BoxFit.cover,
              onDetect: (capture) {
                final codes = capture.barcodes;
                for (final b in codes) {
                  final raw = b.rawValue;
                  if (raw == null) continue;
                  _handleCode(raw);
                  if (_handled) break;
                }
              },
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.70),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Scan QR Code',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.75), width: 2),
                boxShadow: AppTheme.goldGlow(opacity: 0.12, blur: 34, y: 14),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Scan a barber or shop QR to open their profile instantly.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.82), fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
