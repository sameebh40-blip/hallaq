import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/role.dart';
import '../../../core/network/network_status.dart';
import '../../../core/network/resilient_request.dart';
import '../../../core/persistence/kv_store.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class ProfileRepository {
  final SupabaseClient _client;
  final MediaService _media;
  final KvStore _kv;
  final bool _isOnline;
  AppUserRole? _cachedRole;
  String? _cachedRoleUserId;
  String? _cachedRoleAccessToken;
  String? _cachedStatus;

  ProfileRepository(this._client, this._media, this._kv, this._isOnline);

  static const _cacheTtlMs = 1000 * 60 * 60 * 24;

  String _cacheKey(String userId) => 'cache:my_profile:$userId';

  Future<void> _writeCache(UserProfile p) async {
    final payload = <String, dynamic>{
      't': DateTime.now().millisecondsSinceEpoch,
      'v': p.toJson(),
    };
    await _kv.write(_cacheKey(p.id), jsonEncode(payload));
  }

  Future<UserProfile?> readCachedMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final raw = await _kv.read(_cacheKey(user.id));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final t = decoded['t'];
      final v = decoded['v'];
      if (t is! num) return null;
      if (DateTime.now().millisecondsSinceEpoch - t.toInt() > _cacheTtlMs) return null;
      if (v is! Map) return null;
      final p = UserProfile.fromJson(Map<String, dynamic>.from(v));
      return p;
    } catch (_) {
      return null;
    }
  }

  void clearRoleCache() {
    _cachedRole = null;
    _cachedRoleUserId = null;
    _cachedRoleAccessToken = null;
    _cachedStatus = null;
  }

  Future<AppUserRole> getMyRoleFast({AppUserRole defaultRole = AppUserRole.customer}) async {
    final user = _client.auth.currentUser;
    if (user == null) return AppUserRole.unknown;
    final token = _client.auth.currentSession?.accessToken;
    if (_cachedRoleUserId == user.id && _cachedRoleAccessToken == token && _cachedRole != null) return _cachedRole!;
    try {
      final data = await _client.from('profiles').select('role').eq('id', user.id).maybeSingle();
      final role = data == null ? AppUserRole.unknown : AppUserRole.fromDb((data as Map)['role'] as String?);
      _cachedRoleUserId = user.id;
      _cachedRoleAccessToken = token;
      _cachedRole = role;
      return role;
    } catch (_) {
      _cachedRoleUserId = user.id;
      _cachedRoleAccessToken = token;
      _cachedRole = AppUserRole.unknown;
      return AppUserRole.unknown;
    }
  }

  Future<({AppUserRole role, String? status})> getMyGateInfoFast() async {
    final user = _client.auth.currentUser;
    if (user == null) return (role: AppUserRole.unknown, status: null);
    final token = _client.auth.currentSession?.accessToken;
    if (_cachedRoleUserId == user.id && _cachedRoleAccessToken == token && _cachedRole != null) {
      return (role: _cachedRole!, status: _cachedStatus);
    }
    try {
      final data = await _client.from('profiles').select('role, status').eq('id', user.id).maybeSingle();
      final role = data == null ? AppUserRole.unknown : AppUserRole.fromDb((data as Map)['role'] as String?);
      final status = data == null ? null : ((data as Map)['status'] as String?);
      _cachedRoleUserId = user.id;
      _cachedRoleAccessToken = token;
      _cachedRole = role;
      _cachedStatus = status;
      return (role: role, status: status);
    } catch (_) {
      _cachedRoleUserId = user.id;
      _cachedRoleAccessToken = token;
      _cachedRole = AppUserRole.unknown;
      _cachedStatus = null;
      return (role: AppUserRole.unknown, status: null);
    }
  }

  Future<({AppUserRole role, String? status})> getMyGateInfoFresh() async {
    final user = _client.auth.currentUser;
    if (user == null) return (role: AppUserRole.unknown, status: null);
    final token = _client.auth.currentSession?.accessToken;
    try {
      final data = await _client.from('profiles').select('role, status').eq('id', user.id).maybeSingle();
      final role = data == null ? AppUserRole.unknown : AppUserRole.fromDb((data as Map)['role'] as String?);
      final status = data == null ? null : ((data as Map)['status'] as String?);
      _cachedRoleUserId = user.id;
      _cachedRoleAccessToken = token;
      _cachedRole = role;
      _cachedStatus = status;
      return (role: role, status: status);
    } catch (_) {
      _cachedRoleUserId = user.id;
      _cachedRoleAccessToken = token;
      _cachedRole = AppUserRole.unknown;
      _cachedStatus = null;
      return (role: AppUserRole.unknown, status: null);
    }
  }

  Future<UserProfile> _withSignedMedia(UserProfile p) async {
    final avatar = await _media.resolveMediaUrl(bucket: 'avatars', path: p.avatarPath, legacyUrlOrPath: p.avatarUrl);
    final cover = await _media.resolveMediaUrlMulti(
      buckets: const ['avatars', 'profile-covers'],
      path: p.coverPath,
      legacyUrlOrPath: p.coverUrl,
    );
    return p.copyWith(avatarUrl: avatar, coverUrl: cover);
  }

  Future<UserProfile?> getMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await resilientRequest(() => _client.from('profiles').select().eq('id', user.id).maybeSingle());
      if (data == null) return null;
      final p = UserProfile.fromJson(Map<String, dynamic>.from(data));
      final signed = await _withSignedMedia(p);
      final authEmail = (user.email ?? '').trim();
      final profileEmail = (signed.email ?? '').trim();
      var effective = signed;
      if (profileEmail.isEmpty && authEmail.isNotEmpty) {
        effective = signed.copyWith(email: authEmail);
        try {
          await _client.from('profiles').upsert({'id': user.id, 'email': authEmail});
        } catch (_) {}
      }
      try {
        await _writeCache(effective);
      } catch (_) {}
      return effective;
    } catch (e) {
      final cached = await readCachedMyProfile();
      if (!_isOnline && cached != null) return cached;
      throw AppException('Failed to load profile', cause: e);
    }
  }

  Future<UserProfile> getOrCreateMyProfile({AppUserRole defaultRole = AppUserRole.customer}) async {
    final existing = await getMyProfile();
    if (existing != null) return existing;

    final created = await ensureMyProfile(defaultRole: defaultRole);
    return _withSignedMedia(created);
  }

  Stream<UserProfile?> watchMyProfile() {
    final user = _client.auth.currentUser;
    if (user == null) return Stream.value(null);
    return _client
        .from('profiles')
        .stream(primaryKey: const ['id'])
        .eq('id', user.id)
        .asyncMap((rows) async {
      final list = rows;
      if (list.isEmpty) return null;
      final p = UserProfile.fromJson(Map<String, dynamic>.from(list.first));
      return _withSignedMedia(p);
    });
  }

  Future<UserProfile> upsertMyProfile({
    String? fullName,
    String? phone,
    String? email,
    String? avatarUrl,
    String? coverUrl,
    String? avatarPath,
    String? coverPath,
    String? myBarberId,
    bool updateMyBarberId = false,
    AppUserRole? role,
    String? bio,
    String? location,
    String? membershipTier,
    String? area,
    double? lat,
    double? lng,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');
    try {
      final normalizedAvatarUrl = avatarUrl != null && avatarUrl.trim().isEmpty ? null : avatarUrl;
      final normalizedCoverUrl = coverUrl != null && coverUrl.trim().isEmpty ? null : coverUrl;
      final normalizedAvatarPath = avatarPath != null && avatarPath.trim().isEmpty ? null : avatarPath;
      final normalizedCoverPath = coverPath != null && coverPath.trim().isEmpty ? null : coverPath;
      final payload = <String, dynamic>{
        'id': user.id,
        if (fullName != null) 'full_name': fullName.trim(),
        if (phone != null) 'phone': phone.trim(),
        if (email != null) 'email': email.trim(),
        if (avatarUrl != null) 'avatar_url': normalizedAvatarUrl,
        if (coverUrl != null) 'cover_url': normalizedCoverUrl,
        if (avatarPath != null) 'avatar_path': normalizedAvatarPath,
        if (coverPath != null) 'cover_path': normalizedCoverPath,
        if (updateMyBarberId) 'my_barber_id': myBarberId,
        if (role != null) 'role': role.toDb(),
        if (bio != null) 'bio': bio.trim(),
        if (location != null) 'location': location.trim(),
        if (membershipTier != null) 'membership_tier': membershipTier.trim(),
        if (area != null) 'area': area,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };
      final data = await _client.from('profiles').upsert(payload).select().single();
      return UserProfile.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw AppException('Failed to update profile', cause: e);
    }
  }

  Future<UserProfile> ensureMyProfile({AppUserRole defaultRole = AppUserRole.customer}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not authenticated');

    final existing = await getMyProfile();
    if (existing != null) return existing;

    return upsertMyProfile(
      fullName: user.userMetadata?['full_name'] as String?,
      email: user.email,
      role: defaultRole,
    );
  }

  Future<UserProfile> setMyBarber(String barberId) async {
    return upsertMyProfile(myBarberId: barberId, updateMyBarberId: true);
  }

  Future<UserProfile> clearMyBarber() async {
    return upsertMyProfile(myBarberId: null, updateMyBarberId: true);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ProfileRepository(client, ref.watch(mediaServiceProvider), ref.watch(kvStoreProvider), ref.watch(networkOnlineProvider));
});

class MyProfileController extends AutoDisposeAsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    ref.watch(authStateChangesProvider);
    ref.listen<bool>(networkOnlineProvider, (prev, next) {
      if (prev == false && next == true) {
        Future<void>.microtask(refresh);
      }
    });
    final repo = ref.watch(profileRepositoryProvider);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    if (user == null) return null;

    final cached = await repo.readCachedMyProfile();
    if (cached != null) state = AsyncData(cached);

    try {
      final fresh = await repo.getMyProfile();
      return fresh;
    } catch (e) {
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(profileRepositoryProvider).getMyProfile());
  }
}

final myProfileProvider = AsyncNotifierProvider.autoDispose<MyProfileController, UserProfile?>(MyProfileController.new);
