import 'env_storage_stub.dart' if (dart.library.html) 'env_storage_web.dart' as impl;

class EnvStorage {
  static const _kSupabaseUrl = 'hallaq.supabaseUrl';
  static const _kSupabaseAnonKey = 'hallaq.supabaseAnonKey';
  static const _kAdminPanelUrl = 'hallaq.adminPanelUrl';

  static String? getSupabaseUrl() => impl.getString(_kSupabaseUrl);
  static String? getSupabaseAnonKey() => impl.getString(_kSupabaseAnonKey);
  static String? getAdminPanelUrl() => impl.getString(_kAdminPanelUrl);

  static void setSupabaseUrl(String value) => impl.setString(_kSupabaseUrl, value);
  static void setSupabaseAnonKey(String value) => impl.setString(_kSupabaseAnonKey, value);
  static void setAdminPanelUrl(String value) => impl.setString(_kAdminPanelUrl, value);

  static void clear() {
    impl.remove(_kSupabaseUrl);
    impl.remove(_kSupabaseAnonKey);
    impl.remove(_kAdminPanelUrl);
  }
}
