import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/env_loader.dart';
import '../../../core/config/env_provider.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class AuthRepository {
  final SupabaseClient _client;
  final EnvLoadResult _loadedEnv;

  AuthRepository(this._client, this._loadedEnv);

  void _debugLog(String message, [Object? error]) {
    if (!kDebugMode) return;
    if (error == null) {
      debugPrint('[Auth] $message');
      return;
    }
    if (error is AuthException) {
      debugPrint('[Auth] $message\nAuthException(message=${error.message} statusCode=${error.statusCode})');
      return;
    }
    if (error is PostgrestException) {
      debugPrint('[Auth] $message\nPostgrestException(message=${error.message} code=${error.code} details=${error.details})');
      return;
    }
    debugPrint('[Auth] $message\n$error');
  }

  void _debugLogWithStack(String message, Object error, StackTrace st) {
    if (!kDebugMode) return;
    _debugLog(message, error);
    debugPrint('$st');
  }

  bool _isInvalidLogin(AuthException e) {
    final lower = e.message.trim().toLowerCase();
    return lower.contains('invalid login credentials') || lower.contains('invalid credentials');
  }

  Future<bool> _accountExists({required bool email, required String value}) async {
    try {
      final rows = await _client
          .from('profiles')
          .select('id')
          .eq(email ? 'email' : 'phone', value)
          .limit(1);
      return rows.isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  AppException _mapSignInException(AuthException e) {
    final msg = e.message.trim();
    final lower = msg.toLowerCase();
    if (lower.contains('email not confirmed') ||
        lower.contains('confirm your email') ||
        lower.contains('email address not confirmed') ||
        lower.contains('email is not confirmed')) {
      return const AppException('Email not confirmed. Check your inbox then try again.', cause: null);
    }
    if (lower.contains('user is banned') || lower.contains('user banned') || lower.contains('banned')) {
      return const AppException('This account is disabled. Contact support.', cause: null);
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return const AppException('Too many attempts. Try again later.', cause: null);
    }
    if (lower.contains('provider') && (lower.contains('disabled') || lower.contains('not enabled'))) {
      return const AppException('Sign-in is disabled on the server. Try again later.', cause: null);
    }
    if (lower.contains('invalid login credentials') || lower.contains('invalid credentials')) {
      return const AppException('Incorrect email or password', cause: null);
    }
    if (lower.contains('user not found')) {
      return const AppException('Account not found', cause: null);
    }
    return AppException(msg.isEmpty ? 'Failed to sign in' : msg, cause: e);
  }

  AppException? _mapNetworkFailure(Object e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('timeout') || raw.contains('timed out') || raw.contains('connection timed out')) {
      return AppException('Connection timeout. Please try again.', cause: e);
    }
    if (raw.contains('handshakeexception') || raw.contains('tls') || raw.contains('certificate')) {
      return AppException(
        'Secure connection failed. Check your phone date/time, update Android System WebView/Chrome, then try again.',
        cause: e,
      );
    }
    if (raw.contains('socketexception') ||
        raw.contains('connection refused') ||
        raw.contains('network is unreachable')) {
      return AppException('Network error. Please check your connection.', cause: e);
    }
    return null;
  }

  AppException? _mapWebFetchFailure(Object e) {
    if (!kIsWeb) return null;
    final raw = e.toString();
    if (!raw.contains('Failed to fetch')) return null;
    if (kDebugMode) {
      print(raw);
    }
    return AppException(
      'Could not reach the server. Check your connection and try again.',
      cause: e,
    );
  }

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  bool get isConfigured {
    final url = _loadedEnv.env.supabaseUrl;
    final key = _loadedEnv.env.supabaseAnonKey;
    return url.isNotEmpty && key.isNotEmpty && !url.contains('YOUR_PROJECT') && !key.contains('YOUR_ANON_KEY');
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      try {
        final allowed = await _client.rpc(
          'get_setting_bool',
          params: {'p_key': 'allow_customer_signup', 'p_default': true},
        );
        if (allowed is bool && !allowed) {
          throw const AppException('Sign up is currently disabled.');
        }
      } catch (_) {}

      return await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          if (fullName != null && fullName.trim().isNotEmpty) 'full_name': fullName.trim(),
        },
      );
    } on AuthException catch (e) {
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      throw AppException(e.message, cause: e);
    } on AppException {
      rethrow;
    } catch (e) {
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      throw AppException('Failed to sign up', cause: e);
    }
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _debugLog('signInWithEmail email=$email');
      final res = await _signInWithPassword(email: email, password: password);
      try {
        await _client.auth.refreshSession();
      } catch (_) {}
      final session = res.session ?? _client.auth.currentSession;
      if (session == null) throw const AppException('Could not start session');
      return res;
    } on AuthException catch (e) {
      _debugLog('AuthException during signInWithEmail', e);
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      throw _mapSignInException(e);
    } on AppException {
      rethrow;
    } catch (e, st) {
      _debugLogWithStack('Unknown error during signInWithEmail', e, st);
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      final net = _mapNetworkFailure(e);
      if (net != null) throw net;
      throw AppException('Failed to sign in', cause: e);
    }
  }

  Future<AuthResponse> signInWithEmailOrPhone({
    required String identifier,
    required String password,
  }) async {
    final v = identifier.trim();
    final looksLikeEmail = v.contains('@');
    try {
      _debugLog('signInWithEmailOrPhone looksLikeEmail=$looksLikeEmail identifier=$v');
      final res = looksLikeEmail ? await _signInWithPassword(email: v, password: password) : await _signInWithPassword(phone: v, password: password);
      try {
        await _client.auth.refreshSession();
      } catch (_) {}
      final session = res.session ?? _client.auth.currentSession;
      if (session == null) throw const AppException('Could not start session');
      return res;
    } on AuthException catch (e) {
      _debugLog('AuthException during signInWithEmailOrPhone', e);
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      if (_isInvalidLogin(e)) {
        final exists = await _accountExists(email: looksLikeEmail, value: v);
        if (!exists) throw const AppException('Account not found');
        throw const AppException('Incorrect email or password');
      }
      throw _mapSignInException(e);
    } on AppException {
      rethrow;
    } catch (e, st) {
      _debugLogWithStack('Unknown error during signInWithEmailOrPhone', e, st);
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      final net = _mapNetworkFailure(e);
      if (net != null) throw net;
      throw AppException('Failed to sign in', cause: e);
    }
  }

  static const Duration _authTimeout = Duration(seconds: 15);

  Future<AuthResponse> _signInWithPassword({
    String? email,
    String? phone,
    required String password,
  }) async {
    Future<AuthResponse> attempt() {
      return _client.auth.signInWithPassword(email: email, phone: phone, password: password).timeout(_authTimeout);
    }

    try {
      return await attempt();
    } on TimeoutException catch (e, st) {
      _debugLogWithStack('Timeout during signInWithPassword (attempt 1)', e, st);
      try {
        return await attempt();
      } on TimeoutException catch (e2, st2) {
        _debugLogWithStack('Timeout during signInWithPassword (attempt 2)', e2, st2);
        throw AppException('Connection timeout. Please try again.', cause: e2);
      }
    } on AuthException catch (e, st) {
      _debugLogWithStack('AuthException during signInWithPassword', e, st);
      rethrow;
    } on PostgrestException catch (e, st) {
      _debugLogWithStack('PostgrestException during signInWithPassword', e, st);
      rethrow;
    } on Exception catch (e, st) {
      _debugLogWithStack('Exception during signInWithPassword', e, st);
      rethrow;
    } catch (e, st) {
      _debugLogWithStack('Error during signInWithPassword', e, st);
      rethrow;
    }
  }

  Future<void> signInWithGoogle({String? redirectTo}) async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (e) {
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      throw AppException(e.message, cause: e);
    } catch (e) {
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      throw AppException('Failed to sign in with Google', cause: e);
    }
  }

  Future<void> signInWithApple({String? redirectTo}) async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (e) {
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      throw AppException(e.message, cause: e);
    } catch (e) {
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      throw AppException('Failed to sign in with Apple', cause: e);
    }
  }

  Future<void> signInWithFacebook({String? redirectTo}) async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (e) {
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      throw AppException(e.message, cause: e);
    } catch (e) {
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      throw AppException('Failed to sign in with Facebook', cause: e);
    }
  }

  Future<void> resetPassword({required String email, String? redirectTo}) async {
    try {
      await _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
    } on AuthException catch (e) {
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      throw AppException(e.message, cause: e);
    } catch (e) {
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      throw AppException('Failed to send reset email', cause: e);
    }
  }

  Future<void> resendEmailVerification({required String email, String? redirectTo}) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: redirectTo,
      );
    } on AuthException catch (e) {
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      throw AppException(e.message, cause: e);
    } catch (e) {
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      throw AppException('Failed to resend verification email', cause: e);
    }
  }

  Future<UserResponse> updatePassword({required String newPassword}) async {
    try {
      return await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      throw AppException(e.message, cause: e);
    } catch (e) {
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      throw AppException('Failed to update password', cause: e);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      final mapped = _mapWebFetchFailure(e);
      if (mapped != null) throw mapped;
      throw AppException('Failed to sign out', cause: e);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final loadedEnv = ref.watch(envLoadResultProvider);
  return AuthRepository(client, loadedEnv);
});
