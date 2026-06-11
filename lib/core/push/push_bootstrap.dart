import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_router.dart';
import '../supabase/supabase_client_provider.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

void _handlePushTap({
  required Map<String, dynamic> data,
  required GoRouter router,
}) {
  final type = (data['type'] as String?)?.trim() ?? '';
  if (type == 'offer_received') {
    router.push('/offers/inbox');
    return;
  }
  if (type.contains('booking')) {
    final bookingId = (data['booking_id'] as String?)?.trim() ?? '';
    if (bookingId.isNotEmpty) {
      router.push('/booking/$bookingId');
      return;
    }
    router.go('/bookings');
    return;
  }
  router.go('/notifications');
}

final pushBootstrapProvider = Provider<void>((ref) {
  ref.watch(authStateChangesProvider);

  final client = ref.watch(supabaseClientProvider);
  final router = ref.watch(appRouterProvider);
  final user = client.auth.currentUser;
  if (user == null) return;

  final local = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? tokenSub;
  StreamSubscription<RemoteMessage>? foregroundSub;
  StreamSubscription<RemoteMessage>? openedSub;
  bool initialized = false;
  bool localReady = false;

  Future<FirebaseMessaging?> ensureMessagingReady() async {
    try {
      await Firebase.initializeApp();
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> ensureLocalReady() async {
    if (localReady) return;
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) return;
    localReady = true;
    await local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (r) {
        final raw = (r.payload ?? '').trim();
        if (raw.isEmpty) return;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            _handlePushTap(data: Map<String, dynamic>.from(decoded), router: router);
          }
        } catch (_) {}
      },
    );
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'hallaq_high',
        'Hallaq Notifications',
        description: 'Important updates from your shop and bookings',
        importance: Importance.high,
      ));
    }
  }

  Future<void> registerToken() async {
    final messaging = await ensureMessagingReady();
    if (messaging == null) return;

    if (!initialized) {
      initialized = true;
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (_) {}
      try {
        await ensureLocalReady();
        foregroundSub = FirebaseMessaging.onMessage.listen((m) async {
          await ensureLocalReady();
          final n = m.notification;
          final title = (n?.title ?? '').trim();
          final body = (n?.body ?? '').trim();
          if (title.isEmpty && body.isEmpty) return;
          final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
          await local.show(
            id,
            title.isEmpty ? 'Hallaq' : title,
            body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'hallaq_high',
                'Hallaq Notifications',
                channelDescription: 'Important updates from your shop and bookings',
                importance: Importance.high,
                priority: Priority.high,
                colorized: true,
              ),
              iOS: DarwinNotificationDetails(),
            ),
            payload: jsonEncode(m.data),
          );
        });
      } catch (_) {}

      try {
        openedSub = FirebaseMessaging.onMessageOpenedApp.listen((m) {
          _handlePushTap(data: Map<String, dynamic>.from(m.data), router: router);
        });
      } catch (_) {}

      try {
        unawaited(
          messaging.getInitialMessage().then((m) {
            if (m == null) return;
            _handlePushTap(data: Map<String, dynamic>.from(m.data), router: router);
          }),
        );
      } catch (_) {}
    }

    try {
      if (!kIsWeb) {
        await messaging.requestPermission(alert: true, badge: true, sound: true);
      }
    } catch (_) {}

    final token = await messaging.getToken();
    final t = (token ?? '').trim();
    if (t.isEmpty) return;

    final platform = kIsWeb
        ? 'web'
        : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'unknown'));

    await client.rpc('upsert_device_token', params: {
      'token': t,
      'platform': platform,
      'device_id': null,
    });
  }

  unawaited(registerToken());
  unawaited(() async {
    final messaging = await ensureMessagingReady();
    if (messaging == null) return;
    tokenSub = messaging.onTokenRefresh.listen((_) => unawaited(registerToken()));
  }());

  ref.onDispose(() async {
    await tokenSub?.cancel();
    await foregroundSub?.cancel();
    await openedSub?.cancel();
  });
});
