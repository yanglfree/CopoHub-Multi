const iapPaywallTooFrequentError = 'IAP_TOO_FREQUENT_REQUEST';

enum IapPaywallPlan { monthly, yearly, lifetime }

class IapPaywallProduct {
  const IapPaywallProduct({
    required this.productId,
    required this.plan,
    required this.priceLabel,
    this.originalPriceLabel = '',
    this.periodLabel = '',
    this.discountLabel = '',
    this.promoLabel = '',
    this.title,
    this.hintText,
  });

  final String productId;
  final IapPaywallPlan plan;
  final String priceLabel;
  final String originalPriceLabel;
  final String periodLabel;
  final String discountLabel;
  final String promoLabel;
  final String? title;
  final String? hintText;
}

class IapPaywallBenefit {
  const IapPaywallBenefit({
    required this.icon,
    required this.title,
    this.description,
  });

  final String icon;
  final String title;
  final String? description;
}

class IapPaywallMetric {
  const IapPaywallMetric({required this.value, required this.label});

  final String value;
  final String label;
}

class IapPaywallCopy {
  const IapPaywallCopy({
    this.membershipLabel = '会员中心',
    this.heroTitleSuffix = ' PRO',
    this.heroSubtitle = '解锁完整体验。',
    this.offerTitle = '完整专业套装',
    this.offerSubtitle = '把核心高级能力集中到一个会员里。',
    this.monthlyPlanTitle = '月度订阅',
    this.yearlyPlanTitle = '年度订阅',
    this.lifetimePlanTitle = '终身会员',
    this.monthlyHint = '按月计费',
    this.yearlyHint = '年度更划算',
    this.lifetimeHint = '一次购买永久使用',
    this.selectedSubscriptionNotice = '月会员与年会员均为自动续费订阅，到期后将自动续费；可随时取消。',
    this.selectedLifetimeNotice = '终身会员为一次购买、永久解锁的非消耗型项目，购买后可恢复。',
    this.autoRenewAgreePrefix = '我已阅读并同意',
    this.autoRenewAgreementLink = '《自动续费服务协议》',
    this.autoRenewAgreeSuffix = '，到期自动续费，可随时取消',
    this.purchaseTermsAgreePrefix = '我已阅读并同意',
    this.purchaseTermsAgreeSuffix = '中的购买规则',
    this.subscriptionAutoRenewHint = '订阅到期前会自动续费，可随时在系统订阅管理中取消。',
    this.purchaseAgreePrefix = '购买即表示同意 ',
    this.purchaseAgreeAnd = ' 与 ',
    this.privacyPolicy = '隐私政策',
    this.userAgreement = '用户协议',
    this.supportEmailLabel = '客服邮箱：',
    this.agreeTermsToContinue = '同意协议后继续',
    this.subscribeNow = '立即订阅',
    this.purchaseNow = '立即购买',
    this.purchasing = '购买中...',
    this.restorePurchase = '恢复购买',
    this.manageSubscription = '管理订阅',
    this.startUsing = '开始使用',
    this.proActivatedTitle = '已解锁 PRO 权益',
    this.memberExpiresHint = '会员有效期至',
    this.purchaseTermsRequired = '请先阅读并同意购买协议',
    this.purchaseCoolingDown = '支付处理中，请稍后再试',
    this.purchaseTooFrequent = '支付请求太频繁，请稍后再试',
    this.iapEnvWarning = '内购服务暂不可用，请稍后重试。',
    this.iapRetry = '重试',
    this.iapEnvReady = '内购服务已就绪',
    this.purchaseSuccessToast = '开通成功',
    this.restoreSuccessToast = '权益已恢复',
    this.restoreEmptyToast = '未找到有效的购买记录',
    this.purchaseLaunchFailedPrefix = '支付唤起失败，请稍后再试',
  });

  final String membershipLabel;
  final String heroTitleSuffix;
  final String heroSubtitle;
  final String offerTitle;
  final String offerSubtitle;
  final String monthlyPlanTitle;
  final String yearlyPlanTitle;
  final String lifetimePlanTitle;
  final String monthlyHint;
  final String yearlyHint;
  final String lifetimeHint;
  final String selectedSubscriptionNotice;
  final String selectedLifetimeNotice;
  final String autoRenewAgreePrefix;
  final String autoRenewAgreementLink;
  final String autoRenewAgreeSuffix;
  final String purchaseTermsAgreePrefix;
  final String purchaseTermsAgreeSuffix;
  final String subscriptionAutoRenewHint;
  final String purchaseAgreePrefix;
  final String purchaseAgreeAnd;
  final String privacyPolicy;
  final String userAgreement;
  final String supportEmailLabel;
  final String agreeTermsToContinue;
  final String subscribeNow;
  final String purchaseNow;
  final String purchasing;
  final String restorePurchase;
  final String manageSubscription;
  final String startUsing;
  final String proActivatedTitle;
  final String memberExpiresHint;
  final String purchaseTermsRequired;
  final String purchaseCoolingDown;
  final String purchaseTooFrequent;
  final String iapEnvWarning;
  final String iapRetry;
  final String iapEnvReady;
  final String purchaseSuccessToast;
  final String restoreSuccessToast;
  final String restoreEmptyToast;
  final String purchaseLaunchFailedPrefix;
}

class IapPaywallConfig {
  const IapPaywallConfig({
    required this.appName,
    required this.proName,
    required this.supportEmail,
    required this.termsUrl,
    required this.privacyUrl,
    this.defaultSelectedPlan = IapPaywallPlan.yearly,
    this.defaultProducts = defaultIapPaywallProducts,
    this.metrics = defaultIapPaywallMetrics,
    this.benefits = defaultIapPaywallBenefits,
    this.copy = const IapPaywallCopy(),
  });

  final String appName;
  final String proName;
  final String supportEmail;
  final String termsUrl;
  final String privacyUrl;
  final IapPaywallPlan defaultSelectedPlan;
  final List<IapPaywallProduct> defaultProducts;
  final List<IapPaywallMetric> metrics;
  final List<IapPaywallBenefit> benefits;
  final IapPaywallCopy copy;
}

abstract interface class IapPaywallPurchaseAdapter {
  Future<bool> checkEnvironment();

  Future<List<IapPaywallProduct>> queryProducts();

  Future<bool> purchase(IapPaywallPlan plan);

  Future<bool> restorePurchases();

  Future<void> manageSubscriptions();
}

class NoopPaywallPurchaseAdapter implements IapPaywallPurchaseAdapter {
  const NoopPaywallPurchaseAdapter();

  @override
  Future<bool> checkEnvironment() async => false;

  @override
  Future<List<IapPaywallProduct>> queryProducts() async => const [];

  @override
  Future<bool> purchase(IapPaywallPlan plan) async => false;

  @override
  Future<bool> restorePurchases() async => false;

  @override
  Future<void> manageSubscriptions() async {}
}

const defaultIapPaywallProducts = <IapPaywallProduct>[
  IapPaywallProduct(
    productId: 'monthly',
    plan: IapPaywallPlan.monthly,
    priceLabel: '¥12',
    periodLabel: '月',
  ),
  IapPaywallProduct(
    productId: 'yearly',
    plan: IapPaywallPlan.yearly,
    priceLabel: '¥68',
    periodLabel: '年',
    discountLabel: '52%折扣',
  ),
  IapPaywallProduct(
    productId: 'lifetime',
    plan: IapPaywallPlan.lifetime,
    priceLabel: '¥99',
    originalPriceLabel: '¥128',
    periodLabel: '永久',
    discountLabel: '77%折扣',
    promoLabel: '限时特惠',
  ),
];

const defaultIapPaywallMetrics = <IapPaywallMetric>[
  IapPaywallMetric(value: '8', label: '权益'),
  IapPaywallMetric(value: '全部', label: '内容'),
  IapPaywallMetric(value: '不限', label: '容量'),
];

const defaultIapPaywallBenefits = <IapPaywallBenefit>[
  IapPaywallBenefit(icon: '✨', title: '解锁全部 PRO 权益'),
  IapPaywallBenefit(icon: '📚', title: '持续更新高级内容'),
];
