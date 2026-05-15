# iap_paywall_kit_flutter

Shared Flutter paywall UI kit for subscription and lifetime in-app purchase screens.

The package owns paywall layout, legal disclosures, agreement gating, selected-plan notices, restore purchase entry, and support email display. Each app owns only configuration, localization, product IDs, and the store adapter.

## Install

Use a local path dependency from a Flutter app:

```yaml
dependencies:
  iap_paywall_kit_flutter:
    path: ../packages/iap_paywall_kit_flutter
```

## Usage

```dart
import 'package:iap_paywall_kit_flutter/iap_paywall_kit_flutter.dart';

class AppPaywallAdapter implements IapPaywallPurchaseAdapter {
  @override
  Future<bool> checkEnvironment() async {
    return true;
  }

  @override
  Future<List<IapPaywallProduct>> queryProducts() async {
    return const [];
  }

  @override
  Future<bool> purchase(IapPaywallPlan plan) async {
    return true;
  }

  @override
  Future<bool> restorePurchases() async {
    return false;
  }

  @override
  Future<void> manageSubscriptions() async {}
}

StandardIapPaywallPage(
  config: const IapPaywallConfig(
    appName: 'PianoToy',
    proName: 'PRO',
    supportEmail: 'youdroid2048@gmail.com',
    termsUrl: 'https://example.com/terms',
    privacyUrl: 'https://example.com/privacy',
    benefits: [
      IapPaywallBenefit(icon: '🎵', title: 'Unlock all instruments'),
      IapPaywallBenefit(icon: '📚', title: 'Unlock all songs'),
    ],
  ),
  adapter: AppPaywallAdapter(),
  onClose: () {},
  onOpenTerms: (url) {},
  onOpenPrivacy: (url) {},
  onPurchaseSucceeded: () {},
  onRestoreSucceeded: () {},
);
```

## Required behavior

- Monthly and yearly plans are treated as auto-renewable subscriptions.
- Lifetime plans are treated as one-time, restorable purchases.
- The purchase button is blocked until the user agrees to the currently selected plan terms.
- Switching plans resets the agreement state.
- The support email is always shown in the bottom legal text.
- Store SDK logic must live in `IapPaywallPurchaseAdapter`, not inside the widget.

## CopoHub-style adapter

CopoHub already wraps iOS StoreKit and HarmonyOS IAPKit behind a Dart service. Keep that shape and adapt only the final UI contract:

```dart
class CopoHubPaywallAdapter implements IapPaywallPurchaseAdapter {
  const CopoHubPaywallAdapter(this.iapService);

  final IapService iapService;

  @override
  Future<bool> checkEnvironment() async {
    return true;
  }

  @override
  Future<List<IapPaywallProduct>> queryProducts() async {
    final products = await iapService.queryProducts();
    return products.map((product) {
      final plan = switch (product.planType) {
        ProPlanType.monthly => IapPaywallPlan.monthly,
        ProPlanType.yearly => IapPaywallPlan.yearly,
        ProPlanType.lifetime => IapPaywallPlan.lifetime,
        ProPlanType.none => IapPaywallPlan.yearly,
      };
      return IapPaywallProduct(
        productId: product.planType.name,
        plan: plan,
        priceLabel: product.localPrice,
        originalPriceLabel: product.originalLocalPrice,
        periodLabel: switch (plan) {
          IapPaywallPlan.monthly => '月',
          IapPaywallPlan.yearly => '年',
          IapPaywallPlan.lifetime => '永久',
        },
      );
    }).toList();
  }

  @override
  Future<bool> purchase(IapPaywallPlan plan) {
    return iapService.purchase(switch (plan) {
      IapPaywallPlan.monthly => ProPlanType.monthly,
      IapPaywallPlan.yearly => ProPlanType.yearly,
      IapPaywallPlan.lifetime => ProPlanType.lifetime,
    });
  }

  @override
  Future<bool> restorePurchases() {
    return iapService.restorePurchases();
  }

  @override
  Future<void> manageSubscriptions() async {}
}
```
