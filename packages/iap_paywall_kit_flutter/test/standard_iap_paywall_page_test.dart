import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iap_paywall_kit_flutter/iap_paywall_kit_flutter.dart';

void main() {
  testWidgets('purchase is blocked until terms are accepted', (tester) async {
    final adapter = _FakeAdapter();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StandardIapPaywallPage(config: _config, adapter: adapter),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(_config.copy.agreeTermsToContinue));
    await tester.pumpAndSettle();
    expect(find.text(_config.copy.agreeTermsToContinue), findsOneWidget);
    await tester.tap(find.text(_config.copy.agreeTermsToContinue));
    await tester.pump();

    expect(adapter.purchaseCount, 0);

    await tester.ensureVisible(find.text(_config.copy.autoRenewAgreePrefix));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_config.copy.autoRenewAgreePrefix));
    await tester.pump();

    await tester.ensureVisible(find.textContaining(_config.copy.subscribeNow));
    await tester.pumpAndSettle();
    expect(find.textContaining(_config.copy.subscribeNow), findsOneWidget);
    await tester.tap(find.textContaining(_config.copy.subscribeNow));
    await tester.pump();

    expect(adapter.purchaseCount, 1);
  });

  testWidgets('switching plans resets accepted terms', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StandardIapPaywallPage(
            config: _config,
            adapter: _FakeAdapter(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(_config.copy.autoRenewAgreePrefix));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_config.copy.autoRenewAgreePrefix));
    await tester.pump();

    await tester.ensureVisible(find.textContaining(_config.copy.subscribeNow));
    await tester.pumpAndSettle();
    expect(find.textContaining(_config.copy.subscribeNow), findsOneWidget);

    await tester.ensureVisible(find.text(_config.copy.monthlyPlanTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_config.copy.monthlyPlanTitle));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(_config.copy.agreeTermsToContinue));
    await tester.pumpAndSettle();
    expect(find.text(_config.copy.agreeTermsToContinue), findsOneWidget);
  });
}

const _config = IapPaywallConfig(
  appName: 'Test App',
  proName: 'PRO',
  supportEmail: 'youdroid2048@gmail.com',
  termsUrl: 'https://example.com/terms',
  privacyUrl: 'https://example.com/privacy',
);

class _FakeAdapter implements IapPaywallPurchaseAdapter {
  int purchaseCount = 0;

  @override
  Future<bool> checkEnvironment() async => true;

  @override
  Future<List<IapPaywallProduct>> queryProducts() async => const [];

  @override
  Future<bool> purchase(IapPaywallPlan plan) async {
    purchaseCount += 1;
    return true;
  }

  @override
  Future<bool> restorePurchases() async => false;

  @override
  Future<void> manageSubscriptions() async {}
}
