import 'env_storage.dart';

class Env {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool supabaseDebug;
  final String adminPanelUrl;

  const Env({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.supabaseDebug,
    required this.adminPanelUrl,
  });

  Env copyWith({
    String? supabaseUrl,
    String? supabaseAnonKey,
    bool? supabaseDebug,
    String? adminPanelUrl,
  }) {
    return Env(
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
      supabaseDebug: supabaseDebug ?? this.supabaseDebug,
      adminPanelUrl: adminPanelUrl ?? this.adminPanelUrl,
    );
  }

  factory Env.fromDartDefines() {
    const supabaseUrlPrimary = String.fromEnvironment('SUPABASE_URL');
    const supabaseUrlFallback = String.fromEnvironment('NEXT_PUBLIC_SUPABASE_URL');
    const supabaseAnonKeyPrimary = String.fromEnvironment('SUPABASE_ANON_KEY');
    const supabaseAnonKeyFallback = String.fromEnvironment('NEXT_PUBLIC_SUPABASE_ANON_KEY');
    const supabaseDebugPrimary = bool.fromEnvironment('SUPABASE_DEBUG', defaultValue: false);
    const supabaseDebugFallback = bool.fromEnvironment('NEXT_PUBLIC_SUPABASE_DEBUG', defaultValue: false);
    const adminPanelUrlPrimary = String.fromEnvironment('ADMIN_PANEL_URL', defaultValue: 'https://admin.hallaq.com');
    const adminPanelUrlFallback = String.fromEnvironment('NEXT_PUBLIC_ADMIN_PANEL_URL', defaultValue: 'https://admin.hallaq.com');

    var supabaseUrl = supabaseUrlPrimary.isNotEmpty ? supabaseUrlPrimary : supabaseUrlFallback;
    var supabaseAnonKey = supabaseAnonKeyPrimary.isNotEmpty ? supabaseAnonKeyPrimary : supabaseAnonKeyFallback;
    final supabaseDebug = supabaseDebugPrimary || supabaseDebugFallback;
    var adminPanelUrl = adminPanelUrlPrimary != 'https://admin.hallaq.com' ? adminPanelUrlPrimary : adminPanelUrlFallback;

    final storedUrl = EnvStorage.getSupabaseUrl();
    final storedAnonKey = EnvStorage.getSupabaseAnonKey();
    final storedAdminPanelUrl = EnvStorage.getAdminPanelUrl();

    if ((supabaseUrl.isEmpty || supabaseUrl.contains('YOUR_PROJECT')) && storedUrl != null && storedUrl.isNotEmpty) {
      supabaseUrl = storedUrl;
    }

    if ((supabaseAnonKey.isEmpty || supabaseAnonKey.contains('YOUR_ANON_KEY')) && storedAnonKey != null && storedAnonKey.isNotEmpty) {
      supabaseAnonKey = storedAnonKey;
    }

    if ((adminPanelUrl.isEmpty || adminPanelUrl == 'https://admin.hallaq.com') && storedAdminPanelUrl != null && storedAdminPanelUrl.isNotEmpty) {
      adminPanelUrl = storedAdminPanelUrl;
    }

    String sanitize(String v) {
      var out = v.trim();
      if (out.length >= 2) {
        final first = out[0];
        final last = out[out.length - 1];
        if ((first == '"' && last == '"') || (first == "'" && last == "'") || (first == '`' && last == '`')) {
          out = out.substring(1, out.length - 1).trim();
        }
      }
      out = out.replaceAll('`', '').replaceAll('"', '').trim();
      return out;
    }

    supabaseUrl = sanitize(supabaseUrl);
    supabaseAnonKey = sanitize(supabaseAnonKey).replaceAll(RegExp(r'\s+'), '');
    adminPanelUrl = sanitize(adminPanelUrl);

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      return const Env(
        supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
        supabaseAnonKey: 'YOUR_ANON_KEY',
        supabaseDebug: true,
        adminPanelUrl: 'https://admin.hallaq.com',
      );
    }

    return Env(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      supabaseDebug: supabaseDebug,
      adminPanelUrl: adminPanelUrl,
    );
  }
}
