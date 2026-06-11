import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkQuality { online, poor, offline }

class NetworkStatusService extends AutoDisposeNotifier<NetworkQuality> {
  Timer? _timer;
  bool _checking = false;

  @override
  NetworkQuality build() {
    if (kIsWeb) return NetworkQuality.online;
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    unawaited(refresh());
    return NetworkQuality.online;
  }

  Future<void> refresh() async {
    if (kIsWeb) return;
    if (_checking) return;
    _checking = true;
    try {
      final sw = Stopwatch()..start();
      final result = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 3));
      sw.stop();
      final ok = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      final next = ok ? (sw.elapsedMilliseconds >= 1500 ? NetworkQuality.poor : NetworkQuality.online) : NetworkQuality.offline;
      if (state != next) state = next;
    } catch (_) {
      if (state != NetworkQuality.offline) state = NetworkQuality.offline;
    } finally {
      _checking = false;
    }
  }
}

final networkStatusProvider = AutoDisposeNotifierProvider<NetworkStatusService, NetworkQuality>(NetworkStatusService.new);

final networkOnlineProvider = Provider<bool>((ref) {
  final q = ref.watch(networkStatusProvider);
  return q != NetworkQuality.offline;
});
