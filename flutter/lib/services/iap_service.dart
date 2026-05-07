import 'dart:io';
import 'package:flutter/services.dart';
import 'pro_member_service.dart';

// ── Product IDs ───────────────────────────────────────────────────────────────

const _iosProductIds = {
  ProPlanType.monthly: 'com.youdroid.copohub.promonthly',
  ProPlanType.yearly: 'com.youdroid.copohub.proyearly',
  ProPlanType.lifetime: 'com.youdroid.copohub.prolifetime',
};

const _ohosProductIds = {
  ProPlanType.monthly: 'com.youdroid.copo_promonthly',
  ProPlanType.yearly: 'com.youdroid.copo_proyearly',
  ProPlanType.lifetime: 'com.youdroid.copo_prolifetime',
};

Map<ProPlanType, String> get _platformProductIds =>
    Platform.isIOS ? _iosProductIds : _ohosProductIds;

// Product type tags sent over the channel.
const _typeAutorenewable = 'autorenewable';
const _typeNonconsumable = 'nonconsumable';

String _productType(ProPlanType plan) =>
    plan == ProPlanType.lifetime ? _typeNonconsumable : _typeAutorenewable;

// ── Data classes ──────────────────────────────────────────────────────────────

class IapProduct {
  const IapProduct({
    required this.planType,
    required this.localPrice,
    this.originalLocalPrice = '',
  });

  final ProPlanType planType;
  final String localPrice;
  final String originalLocalPrice;
}

// ── IapService ────────────────────────────────────────────────────────────────

/// Platform-aware in-app purchase service.
///
/// Communicates with native IAP implementations via MethodChannel:
/// - iOS: StoreKit 1 (IapPlugin.swift)
/// - OHOS: HarmonyOS IAPKit (IapPlugin.ets)
class IapService {
  static final IapService instance = IapService._();
  IapService._();

  static const _channel = MethodChannel('com.youdroid/iap');
  final _proService = ProMemberService.instance;

  // ── Query products ──────────────────────────────────────────────────────────

  /// Fetches localised prices for all three plans from the store.
  /// Returns an empty list if the platform does not support IAP or the call
  /// fails; the UI should fall back to hard-coded prices in that case.
  Future<List<IapProduct>> queryProducts() async {
    try {
      final productIds = _platformProductIds.values.toList();
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'queryProducts',
        {'productIds': productIds},
      );
      if (raw == null) return [];

      final result = <IapProduct>[];
      for (final item in raw) {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id'] as String? ?? '';
        final planType = _planTypeForId(id);
        if (planType == ProPlanType.none) continue;
        result.add(IapProduct(
          planType: planType,
          localPrice: map['localPrice'] as String? ?? '',
          originalLocalPrice: map['originalLocalPrice'] as String? ?? '',
        ));
      }
      return result;
    } on PlatformException catch (e) {
      // Not implemented on the current platform or store unavailable.
      _log('queryProducts failed: ${e.code} – ${e.message}');
      return [];
    }
  }

  // ── Purchase ────────────────────────────────────────────────────────────────

  /// Initiates a purchase for [planType].
  ///
  /// On success, activates Pro membership via [ProMemberService] and returns
  /// `true`. Throws [IapException] on failure.
  Future<bool> purchase(ProPlanType planType) async {
    final productId = _platformProductIds[planType];
    if (productId == null) {
      throw IapException('unknown_plan', 'No product ID for plan $planType');
    }

    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'createPurchase',
        {
          'productId': productId,
          'productType': _productType(planType),
        },
      );
      if (raw == null) throw const IapException('null_result', 'Purchase returned null');

      final result = Map<String, dynamic>.from(raw);
      final resolvedPlanType = _planFromString(result['planType'] as String? ?? '');
      final expiryMs = (result['expiryMs'] as int?) ?? 0;

      // On OHOS, finishPurchase must be called explicitly.
      if (!Platform.isIOS) {
        final purchaseToken = result['purchaseToken'] as String? ?? '';
        final purchaseOrderId = result['purchaseOrderId'] as String? ?? '';
        await _finishPurchase(
          productType: _productType(planType),
          purchaseToken: purchaseToken,
          purchaseOrderId: purchaseOrderId,
        );
      }

      await _proService.setPro(
        isPro: true,
        planType: resolvedPlanType != ProPlanType.none ? resolvedPlanType : planType,
        expiryTimestamp: expiryMs,
      );
      return true;
    } on PlatformException catch (e) {
      throw IapException(e.code, e.message ?? 'Purchase failed');
    }
  }

  // ── Restore ─────────────────────────────────────────────────────────────────

  /// Queries previously completed purchases and restores Pro status.
  /// Returns `true` if at least one active purchase was found.
  Future<bool> restorePurchases() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('queryOwnedPurchases');
      if (raw == null || raw.isEmpty) return false;

      // Prefer lifetime > yearly > monthly when multiple purchases exist.
      ProPlanType bestPlan = ProPlanType.none;
      int bestExpiry = 0;

      for (final item in raw) {
        final map = Map<String, dynamic>.from(item as Map);
        final planType = _planFromString(map['planType'] as String? ?? '');
        final expiryMs = (map['expiryMs'] as int?) ?? 0;
        if (_planRank(planType) > _planRank(bestPlan)) {
          bestPlan = planType;
          bestExpiry = expiryMs;
        }
      }

      if (bestPlan == ProPlanType.none) return false;

      await _proService.setPro(
        isPro: true,
        planType: bestPlan,
        expiryTimestamp: bestExpiry,
      );
      return true;
    } on PlatformException catch (e) {
      throw IapException(e.code, e.message ?? 'Restore failed');
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  Future<void> _finishPurchase({
    required String productType,
    required String purchaseToken,
    required String purchaseOrderId,
  }) async {
    if (purchaseToken.isEmpty || purchaseOrderId.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('finishPurchase', {
        'productType': productType,
        'purchaseToken': purchaseToken,
        'purchaseOrderId': purchaseOrderId,
      });
    } on PlatformException catch (e) {
      _log('finishPurchase failed: ${e.code}');
    }
  }

  ProPlanType _planTypeForId(String id) {
    for (final entry in _platformProductIds.entries) {
      if (entry.value == id) return entry.key;
    }
    return ProPlanType.none;
  }

  ProPlanType _planFromString(String s) => ProPlanType.values.firstWhere(
        (e) => e.name == s,
        orElse: () => ProPlanType.none,
      );

  int _planRank(ProPlanType plan) => switch (plan) {
        ProPlanType.monthly => 1,
        ProPlanType.yearly => 2,
        ProPlanType.lifetime => 3,
        ProPlanType.none => 0,
      };

  void _log(String msg) {
    // ignore: avoid_print
    print('[IapService] $msg');
  }
}

// ── IapException ──────────────────────────────────────────────────────────────

class IapException implements Exception {
  const IapException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'IapException($code): $message';
}
