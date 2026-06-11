import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/config/env_loader.dart';
import 'core/config/env_provider.dart';
import 'core/network/http_client_factory.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/hallaq_logo.dart';

Future<void> _logClientError(Object error, StackTrace? stack, {String? source}) async {
  try {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    final reason = error.toString();
    final details = stack?.toString() ?? '';
    final meta = {
      'source': source ?? 'unknown',
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    };
    await client.from('reports').insert({
      'reporter_profile_id': user.id,
      'entity_type': 'client_error',
      'reason': reason.length > 500 ? reason.substring(0, 500) : reason,
      'details': details.length > 4000 ? details.substring(0, 4000) : details,
      'meta': meta,
    });
  } catch (_) {}
}

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (kIsWeb) {
      usePathUrlStrategy();
    }
    if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }

    ErrorWidget.builder = (details) {
      if (kDebugMode) {
        debugPrint('[ErrorWidget] ${details.exception}');
        if (details.stack != null) debugPrint('${details.stack}');
      }
      unawaited(_logClientError(details.exception, details.stack, source: 'ErrorWidget'));
      final debugText = kDebugMode
          ? '${details.exception}\n\n${(details.stack?.toString() ?? '').split('\n').take(8).join('\n')}'
          : null;
      return _FatalErrorScreen(debugText: debugText);
    };
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(_logClientError(details.exception, details.stack, source: 'FlutterError'));
    };

    final loaded = await EnvLoader.load();
    if (kDebugMode) {
      final host = Uri.tryParse(loaded.env.supabaseUrl)?.host ?? '';
      debugPrint('Platform=${kIsWeb ? 'web' : defaultTargetPlatform.name}');
      debugPrint('EnvLoader.source=${loaded.source}');
      debugPrint('SUPABASE_URL.present=${loaded.hasUrl} length=${loaded.urlLength}');
      debugPrint('SUPABASE_URL.host=$host');
      debugPrint('SUPABASE_ANON_KEY.present=${loaded.hasAnonKey} length=${loaded.anonKeyLength}');
    }
    runApp(
      ProviderScope(
        overrides: [
          envLoadResultProvider.overrideWithValue(loaded),
        ],
        child: _Bootstrap(loaded: loaded),
      ),
    );
  }, (error, stack) {
    if (kDebugMode) {
      debugPrint('[Zone] Uncaught error: $error');
      debugPrint('$stack');
    }
    unawaited(_logClientError(error, stack, source: 'Zone'));
  });
}

class _Bootstrap extends StatefulWidget {
  final EnvLoadResult loaded;

  const _Bootstrap({required this.loaded});

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _ready = false;
  bool _attempted = false;
  late Env _env;

  bool get _isConfigured {
    final url = _env.supabaseUrl;
    final key = _env.supabaseAnonKey;
    return url.isNotEmpty && key.isNotEmpty && !url.contains('YOUR_PROJECT') && !key.contains('YOUR_ANON_KEY');
  }

  @override
  void initState() {
    super.initState();
    _env = widget.loaded.env;
    _init();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _init() async {
    if (!_isConfigured) {
      setState(() {
        _attempted = true;
        _ready = false;
      });
      return;
    }

    try {
      final httpClient = HttpClientFactory.create();
      await Supabase.initialize(
        url: _env.supabaseUrl,
        publishableKey: _env.supabaseAnonKey,
        debug: _env.supabaseDebug,
        httpClient: httpClient,
      );
      setState(() {
        _attempted = true;
        _ready = true;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Supabase.initialize] failed: $e');
        debugPrint('$st');
      }
      setState(() {
        _attempted = true;
        _ready = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const HallaqApp();

    if (!_attempted) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: AppTheme.dark(),
          child: Material(
            color: AppTheme.background,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    final debugDetails = kDebugMode
        ? 'Source=${widget.loaded.source} urlPresent=${widget.loaded.hasUrl} keyPresent=${widget.loaded.hasAnonKey} urlLength=${widget.loaded.urlLength} keyLength=${widget.loaded.anonKeyLength}'
        : '';

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: AppTheme.dark(),
        child: Material(
          color: AppTheme.background,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HallaqLogo(size: 92),
                  const SizedBox(height: 18),
                  Text(
                    _isConfigured ? 'Connection issue' : 'Setup required',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isConfigured
                        ? 'We could not reach the server. Please try again.'
                        : 'HALLAQ is not configured on this device yet.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                  ),
                  if (debugDetails.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      debugDetails,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54, fontWeight: FontWeight.w700),
                    ),
                  ],
                  if (_isConfigured) ...[
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _init,
                      child: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FatalErrorScreen extends StatelessWidget {
  final String? debugText;

  const _FatalErrorScreen({this.debugText});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: AppTheme.dark(),
        child: Material(
          color: AppTheme.background,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HallaqLogo(size: 92),
                  const SizedBox(height: 18),
                  Text(
                    'We hit a problem',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please reopen the app. If it keeps happening, contact support.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                  ),
                  if (debugText != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: Text(
                        debugText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600, height: 1.25),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
