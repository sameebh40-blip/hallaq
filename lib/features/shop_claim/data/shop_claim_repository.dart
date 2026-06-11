import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/media/media_service.dart';
import '../../../core/supabase/supabase_client_provider.dart';

class ShopClaimRequest {
  final String id;
  final String shopId;
  final String requesterProfileId;
  final String name;
  final String? phone;
  final String? email;
  final String? proofText;
  final String? proofImagePath;
  final String status;
  final DateTime createdAt;

  const ShopClaimRequest({
    required this.id,
    required this.shopId,
    required this.requesterProfileId,
    required this.name,
    required this.status,
    required this.createdAt,
    this.phone,
    this.email,
    this.proofText,
    this.proofImagePath,
  });

  factory ShopClaimRequest.fromJson(Map<String, dynamic> json) {
    return ShopClaimRequest(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      requesterProfileId: json['requester_profile_id'] as String,
      name: (json['name'] as String?) ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      proofText: json['proof_text'] as String?,
      proofImagePath: json['proof_image_path'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ShopClaimRepository {
  final SupabaseClient _client;
  final MediaService _media;

  ShopClaimRepository(this._client, this._media);

  Future<ShopClaimRequest?> getMyLatestForShop(String shopId) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await _client
          .from('shop_claim_requests')
          .select()
          .eq('shop_id', shopId)
          .eq('requester_profile_id', user.id)
          .order('created_at', ascending: false)
          .maybeSingle();
      if (data == null) return null;
      return ShopClaimRequest.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      throw AppException('Failed to load claim request', cause: e);
    }
  }

  Future<List<ShopClaimRequest>> listPending({int limit = 200}) async {
    try {
      final data = await _client.from('shop_claim_requests').select().eq('status', 'pending').order('created_at', ascending: false).limit(limit);
      return (data as List).map((e) => ShopClaimRequest.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
    } catch (e) {
      throw AppException('Failed to load claim requests', cause: e);
    }
  }

  Future<void> approve(String requestId) async {
    try {
      await _client.rpc('approve_shop_claim_request', params: {'p_request_id': requestId});
    } catch (e) {
      throw AppException('Failed to approve request', cause: e);
    }
  }

  Future<void> reject(String requestId, {String? reason}) async {
    try {
      await _client.rpc('reject_shop_claim_request', params: {'p_request_id': requestId, 'p_reason': reason});
    } catch (e) {
      throw AppException('Failed to reject request', cause: e);
    }
  }

  Future<void> submit({
    required String shopId,
    required String name,
    String? phone,
    String? email,
    String? proofText,
    Uint8List? proofImageBytes,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppException('Not signed in');

    String? proofPath;
    if (proofImageBytes != null && proofImageBytes.isNotEmpty) {
      final stored = await _media.uploadImage(
        bucket: 'claim-proofs',
        pathPrefix: user.id,
        bytes: proofImageBytes,
        uploadThumbnail: false,
      );
      proofPath = stored.path;
    }

    try {
      await _client.from('shop_claim_requests').insert({
        'shop_id': shopId,
        'requester_profile_id': user.id,
        'name': name.trim(),
        'phone': (phone ?? '').trim().isEmpty ? null : phone!.trim(),
        'email': (email ?? '').trim().isEmpty ? null : email!.trim(),
        'proof_text': (proofText ?? '').trim().isEmpty ? null : proofText!.trim(),
        'proof_image_path': proofPath,
        'status': 'pending',
      });
    } catch (e) {
      throw AppException('Failed to submit claim', cause: e);
    }
  }

  Future<String?> createShopAsAdmin({
    required String name,
    required String ownerProfileId,
    String? area,
    String? address,
    String? phone,
  }) async {
    try {
      final data = await _client
          .from('barbershops')
          .insert({
            'owner_profile_id': ownerProfileId,
            'name': name,
            'area': area,
            'address': address,
            'phone': phone,
          })
          .select('id')
          .single();
      return data['id'] as String?;
    } catch (e) {
      throw AppException('Failed to create shop', cause: e);
    }
  }
}

final shopClaimRepositoryProvider = Provider<ShopClaimRepository>((ref) {
  return ShopClaimRepository(ref.watch(supabaseClientProvider), ref.watch(mediaServiceProvider));
});

final myShopClaimForShopProvider = FutureProvider.family<ShopClaimRequest?, String>((ref, shopId) async {
  return ref.watch(shopClaimRepositoryProvider).getMyLatestForShop(shopId);
});

final pendingShopClaimRequestsProvider = FutureProvider<List<ShopClaimRequest>>((ref) async {
  return ref.watch(shopClaimRepositoryProvider).listPending();
});
