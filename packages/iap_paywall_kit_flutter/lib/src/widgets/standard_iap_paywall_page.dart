import 'dart:async';

import 'package:flutter/material.dart';

import '../models/iap_paywall_models.dart';
import '../theme/iap_paywall_theme.dart';

Color _alpha(Color color, double opacity) {
  return color.withAlpha((opacity.clamp(0, 1) * 255).round());
}

class StandardIapPaywallPage extends StatefulWidget {
  const StandardIapPaywallPage({
    super.key,
    required this.config,
    required this.adapter,
    this.theme = const IapPaywallTheme(),
    this.isPro = false,
    this.proStatusText = '',
    this.proExpiresText = '',
    this.onClose,
    this.onOpenTerms,
    this.onOpenPrivacy,
    this.onPaywallAppear,
    this.onPurchaseSucceeded,
    this.onRestoreSucceeded,
  });

  final IapPaywallConfig config;
  final IapPaywallPurchaseAdapter adapter;
  final IapPaywallTheme theme;
  final bool isPro;
  final String proStatusText;
  final String proExpiresText;
  final VoidCallback? onClose;
  final ValueChanged<String>? onOpenTerms;
  final ValueChanged<String>? onOpenPrivacy;
  final VoidCallback? onPaywallAppear;
  final VoidCallback? onPurchaseSucceeded;
  final VoidCallback? onRestoreSucceeded;

  @override
  State<StandardIapPaywallPage> createState() => _StandardIapPaywallPageState();
}

class _StandardIapPaywallPageState extends State<StandardIapPaywallPage> {
  static const _purchaseCooldown = Duration(seconds: 2);

  late IapPaywallPlan _selectedPlan;
  late List<IapPaywallProduct> _products;
  bool _isPurchasing = false;
  bool _isEnvironmentReady = true;
  bool _agreedPurchaseTerms = false;
  DateTime? _lastPurchaseAttemptAt;

  IapPaywallCopy get _copy => widget.config.copy;

  IapPaywallTheme get _theme => widget.theme;

  bool get _requiresAutoRenewConsent =>
      _selectedPlan != IapPaywallPlan.lifetime;

  bool get _isCoolingDown {
    final lastAttempt = _lastPurchaseAttemptAt;
    if (lastAttempt == null) {
      return false;
    }
    return DateTime.now().difference(lastAttempt) < _purchaseCooldown;
  }

  bool get _canPurchase =>
      _agreedPurchaseTerms &&
      !_isPurchasing &&
      !_isCoolingDown &&
      _isEnvironmentReady;

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.config.defaultSelectedPlan;
    _products = List<IapPaywallProduct>.of(widget.config.defaultProducts);
    widget.onPaywallAppear?.call();
    unawaited(_loadProducts());
  }

  Future<void> _loadProducts() async {
    try {
      final envOk = await widget.adapter.checkEnvironment();
      if (!mounted) {
        return;
      }
      setState(() {
        _isEnvironmentReady = envOk;
      });
      if (!envOk) {
        return;
      }
      final products = await widget.adapter.queryProducts();
      if (!mounted || products.isEmpty) {
        return;
      }
      setState(() {
        _products = products;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isEnvironmentReady = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _theme.bodyBackground,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(config: widget.config, theme: _theme),
                    const SizedBox(height: 16),
                    if (widget.isPro) ...[
                      _buildProStatusView(),
                    ] else ...[
                      _buildBenefitsSection(),
                      const SizedBox(height: 14),
                      if (!_isEnvironmentReady) ...[
                        _buildEnvironmentWarning(),
                        const SizedBox(height: 12),
                      ],
                      _buildPlanSelector(),
                      const SizedBox(height: 12),
                      _buildSelectedPlanNotice(),
                      const SizedBox(height: 12),
                      _buildPurchaseTermsConsent(),
                      const SizedBox(height: 14),
                      _buildPurchaseButton(),
                      const SizedBox(height: 12),
                      _buildSubscriptionInfoText(),
                      const SizedBox(height: 8),
                      _buildRestoreButton(),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 20,
              child: _IconCircleButton(
                icon: Icons.close_rounded,
                theme: _theme,
                onPressed: widget.onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProStatusView() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _alpha(_theme.accentColor, 0.14),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 58,
            color: _theme.accentColor,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _copy.proActivatedTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _theme.titleText,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _theme.buttonNormal,
            border: Border.all(color: _theme.bodyBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.proStatusText.isEmpty
                    ? _copy.memberExpiresHint
                    : widget.proStatusText,
                style: TextStyle(color: _theme.buttonText, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Text(
                widget.proExpiresText,
                style: TextStyle(
                  color: _theme.accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _FeatureList(benefits: widget.config.benefits, theme: _theme),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _theme.accentColor,
              foregroundColor: _theme.buttonTextActive,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: widget.onClose,
            child: Text(
              _copy.startUsing,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _theme.buttonText,
              side: BorderSide(color: _theme.bodyBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _handleManageSubscription,
            child: Text(_copy.manageSubscription),
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _theme.panelBackground,
        border: Border.all(color: _theme.bodyBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _copy.offerTitle,
            style: TextStyle(
              color: _theme.titleText,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _copy.offerSubtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _theme.buttonText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final metric in widget.config.metrics.take(3)) ...[
                Expanded(
                  child: _ValuePill(metric: metric, theme: _theme),
                ),
                if (metric != widget.config.metrics.take(3).last)
                  const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final benefit in widget.config.benefits.take(2)) ...[
                Expanded(
                  child: _BentoCard(benefit: benefit, theme: _theme),
                ),
                if (benefit != widget.config.benefits.take(2).last)
                  const SizedBox(width: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _alpha(_theme.warningColor, 0.12),
        border: Border.all(color: _alpha(_theme.warningColor, 0.34)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: _theme.warningColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _copy.iapEnvWarning,
              style: TextStyle(color: _theme.buttonText, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _loadProducts,
            child: Text(
              _copy.iapRetry,
              style: TextStyle(color: _theme.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelector() {
    return Column(
      children: [
        for (final product in _products) ...[
          _PlanCard(
            product: product,
            selected: product.plan == _selectedPlan,
            theme: _theme,
            title: _titleFor(product),
            hint: _hintFor(product),
            onTap: () {
              if (_selectedPlan == product.plan) {
                return;
              }
              setState(() {
                _selectedPlan = product.plan;
                _agreedPurchaseTerms = false;
              });
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildSelectedPlanNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _alpha(Colors.white, 0.08),
        border: Border.all(color: _theme.bodyBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'i',
            style: TextStyle(
              color: _theme.accentColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _requiresAutoRenewConsent
                  ? _copy.selectedSubscriptionNotice
                  : _copy.selectedLifetimeNotice,
              style: TextStyle(
                color: _theme.buttonText,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseTermsConsent() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _agreedPurchaseTerms = !_agreedPurchaseTerms;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: _agreedPurchaseTerms
                    ? _theme.accentColor
                    : Colors.transparent,
                border: Border.all(
                  color: _agreedPurchaseTerms
                      ? _theme.accentColor
                      : _theme.bodyBorder,
                  width: 1.5,
                ),
                shape: BoxShape.circle,
              ),
              child: _agreedPurchaseTerms
                  ? Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: _theme.buttonTextActive,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                runSpacing: 4,
                children: [
                  Text(
                    _requiresAutoRenewConsent
                        ? _copy.autoRenewAgreePrefix
                        : _copy.purchaseTermsAgreePrefix,
                    style: TextStyle(color: _theme.buttonText, fontSize: 12),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        widget.onOpenTerms?.call(widget.config.termsUrl),
                    child: Text(
                      _requiresAutoRenewConsent
                          ? _copy.autoRenewAgreementLink
                          : _copy.userAgreement,
                      style: TextStyle(
                        color: _theme.accentColor,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        decorationColor: _theme.accentColor,
                      ),
                    ),
                  ),
                  Text(
                    _requiresAutoRenewConsent
                        ? _copy.autoRenewAgreeSuffix
                        : _copy.purchaseTermsAgreeSuffix,
                    style: TextStyle(color: _theme.buttonText, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseButton() {
    final selectedProduct = _selectedProduct;
    final label = _purchaseButtonLabel(selectedProduct);
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor:
              _canPurchase ? _theme.accentColor : _theme.buttonNormal,
          disabledBackgroundColor: _theme.buttonNormal,
          disabledForegroundColor: _alpha(_theme.buttonText, 0.62),
          foregroundColor: _canPurchase
              ? _theme.buttonTextActive
              : _alpha(_theme.buttonText, 0.62),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: _canPurchase ? _handlePurchase : null,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildSubscriptionInfoText() {
    return Column(
      children: [
        if (_requiresAutoRenewConsent) ...[
          Text(
            _copy.subscriptionAutoRenewHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _alpha(_theme.buttonText, 0.85),
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Wrap(
          alignment: WrapAlignment.center,
          runSpacing: 4,
          children: [
            Text(
              _copy.purchaseAgreePrefix,
              style: TextStyle(color: _theme.buttonText, fontSize: 11),
            ),
            _LegalLink(
              label: _copy.userAgreement,
              color: _theme.accentColor,
              onTap: () => widget.onOpenTerms?.call(widget.config.termsUrl),
            ),
            Text(
              _copy.purchaseAgreeAnd,
              style: TextStyle(color: _theme.buttonText, fontSize: 11),
            ),
            _LegalLink(
              label: _copy.privacyPolicy,
              color: _theme.accentColor,
              onTap: () => widget.onOpenPrivacy?.call(widget.config.privacyUrl),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${_copy.supportEmailLabel}${widget.config.supportEmail}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _alpha(_theme.buttonText, 0.85),
            fontSize: 11,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildRestoreButton() {
    return Center(
      child: TextButton(
        onPressed: _isPurchasing ? null : _handleRestore,
        child: Text(
          _copy.restorePurchase,
          style: TextStyle(color: _theme.buttonText),
        ),
      ),
    );
  }

  IapPaywallProduct? get _selectedProduct {
    for (final product in _products) {
      if (product.plan == _selectedPlan) {
        return product;
      }
    }
    return _products.isEmpty ? null : _products.first;
  }

  String _titleFor(IapPaywallProduct product) {
    if (product.title != null && product.title!.isNotEmpty) {
      return product.title!;
    }
    return switch (product.plan) {
      IapPaywallPlan.monthly => _copy.monthlyPlanTitle,
      IapPaywallPlan.yearly => _copy.yearlyPlanTitle,
      IapPaywallPlan.lifetime => _copy.lifetimePlanTitle,
    };
  }

  String _hintFor(IapPaywallProduct product) {
    if (product.hintText != null && product.hintText!.isNotEmpty) {
      return product.hintText!;
    }
    return switch (product.plan) {
      IapPaywallPlan.monthly => _copy.monthlyHint,
      IapPaywallPlan.yearly => _copy.yearlyHint,
      IapPaywallPlan.lifetime => _copy.lifetimeHint,
    };
  }

  String _purchaseButtonLabel(IapPaywallProduct? product) {
    if (_isPurchasing) {
      return _copy.purchasing;
    }
    if (!_agreedPurchaseTerms) {
      return _copy.agreeTermsToContinue;
    }
    final action = _selectedPlan == IapPaywallPlan.lifetime
        ? _copy.purchaseNow
        : _copy.subscribeNow;
    if (product == null) {
      return action;
    }
    return '$action ${_titleFor(product)} ${product.priceLabel}';
  }

  Future<void> _handlePurchase() async {
    if (_isCoolingDown || _isPurchasing) {
      _showMessage(_copy.purchaseCoolingDown);
      return;
    }
    setState(() {
      _isPurchasing = true;
      _lastPurchaseAttemptAt = DateTime.now();
    });
    try {
      final success = await widget.adapter.purchase(_selectedPlan);
      if (!mounted) {
        return;
      }
      if (success) {
        _showMessage(_copy.purchaseSuccessToast);
        widget.onPurchaseSucceeded?.call();
      }
    } catch (err) {
      if (!mounted) {
        return;
      }
      final message = err.toString().contains(iapPaywallTooFrequentError)
          ? _copy.purchaseTooFrequent
          : '${_copy.purchaseLaunchFailedPrefix}: $err';
      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _handleRestore() async {
    if (_isPurchasing) {
      return;
    }
    setState(() {
      _isPurchasing = true;
    });
    try {
      final restored = await widget.adapter.restorePurchases();
      if (!mounted) {
        return;
      }
      _showMessage(
        restored ? _copy.restoreSuccessToast : _copy.restoreEmptyToast,
      );
      if (restored) {
        widget.onRestoreSucceeded?.call();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _handleManageSubscription() async {
    try {
      await widget.adapter.manageSubscriptions();
    } catch (err) {
      if (mounted) {
        _showMessage('${_copy.purchaseLaunchFailedPrefix}: $err');
      }
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.config, required this.theme});

  final IapPaywallConfig config;
  final IapPaywallTheme theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 58, 52, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accentColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    config.proName,
                    style: TextStyle(
                      color: theme.buttonTextActive,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  config.copy.membershipLabel,
                  style: TextStyle(
                    color: theme.buttonText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${config.appName}${config.copy.heroTitleSuffix}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.titleText,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              config.copy.heroSubtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.buttonText,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({
    required this.icon,
    required this.theme,
    this.onPressed,
  });

  final IconData icon;
  final IapPaywallTheme theme;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: theme.titleText,
      style: IconButton.styleFrom(
        backgroundColor: _alpha(Colors.white, 0.10),
        fixedSize: const Size(32, 32),
      ),
      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.metric, required this.theme});

  final IapPaywallMetric metric;
  final IapPaywallTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _alpha(Colors.white, 0.08),
        border: Border.all(color: _alpha(Colors.white, 0.08)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.accentColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: theme.buttonText, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  const _BentoCard({required this.benefit, required this.theme});

  final IapPaywallBenefit benefit;
  final IapPaywallTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _alpha(Colors.white, 0.06),
        border: Border.all(color: _alpha(Colors.white, 0.08)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(benefit.icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 12),
          Text(
            benefit.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.titleText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.benefits, required this.theme});

  final List<IapPaywallBenefit> benefits;
  final IapPaywallTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.panelBackground,
        border: Border.all(color: theme.bodyBorder),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (final benefit in benefits) ...[
            _FeatureItem(benefit: benefit, theme: theme),
            if (benefit != benefits.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.benefit, required this.theme});

  final IapPaywallBenefit benefit;
  final IapPaywallTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _alpha(theme.accentColor, 0.88),
            shape: BoxShape.circle,
          ),
          child: Text(benefit.icon, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                benefit.title,
                style: TextStyle(
                  color: theme.titleText,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (benefit.description != null &&
                  benefit.description!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  benefit.description!,
                  style: TextStyle(color: theme.buttonText, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.product,
    required this.selected,
    required this.theme,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final IapPaywallProduct product;
  final bool selected;
  final IapPaywallTheme theme;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.01 : 1,
      duration: const Duration(milliseconds: 180),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 96,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected
                ? _alpha(theme.accentColor, 0.18)
                : _alpha(Colors.white, 0.08),
            border: Border.all(
              color: selected ? theme.accentColor : _alpha(Colors.white, 0.10),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _alpha(theme.accentColor, 0.26),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            children: [
              _SelectionDot(selected: selected, theme: theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: theme.titleText,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (product.promoLabel.isNotEmpty)
                          _PlanTag(
                            label: product.promoLabel,
                            color: theme.warningColor,
                          ),
                        if (product.discountLabel.isNotEmpty)
                          _PlanTag(
                            label: product.discountLabel,
                            color: theme.dangerColor,
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: product.plan == IapPaywallPlan.monthly
                            ? theme.buttonText
                            : theme.accentColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (product.originalPriceLabel.isNotEmpty)
                    Text(
                      product.originalPriceLabel,
                      style: TextStyle(
                        color: _alpha(theme.buttonText, 0.70),
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    product.priceLabel,
                    style: TextStyle(
                      color: theme.accentColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (product.periodLabel.isNotEmpty)
                    Text(
                      '/${product.periodLabel}',
                      style: TextStyle(color: theme.buttonText, fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected, required this.theme});

  final bool selected;
  final IapPaywallTheme theme;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected ? theme.accentColor : Colors.transparent,
        border: Border.all(
          color: selected ? theme.accentColor : theme.bodyBorder,
          width: 1.5,
        ),
        shape: BoxShape.circle,
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 16, color: theme.buttonTextActive)
          : null,
    );
  }
}

class _PlanTag extends StatelessWidget {
  const _PlanTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      ),
    );
  }
}
