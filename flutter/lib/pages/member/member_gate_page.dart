import 'package:flutter/material.dart';
import '../../services/iap_service.dart';
import '../../services/pro_member_service.dart';
import '../../components/policy/policy_dialog.dart';

/// Pro membership paywall.
///
/// Loads live prices from the platform store (iOS StoreKit / HarmonyOS IAPKit)
/// via [IapService] and handles the full purchase and restore flow.
class MemberGatePage extends StatefulWidget {
  const MemberGatePage({super.key});

  @override
  State<MemberGatePage> createState() => _MemberGatePageState();
}

class _MemberGatePageState extends State<MemberGatePage> {
  final _proService = ProMemberService.instance;
  final _iapService = IapService.instance;

  int _selectedPlanIndex = 1; // Default: yearly
  bool _agreed = false;
  bool _loading = false;

  // productId → localised price string (populated after queryProducts).
  final Map<String, String> _livePrices = {};

  static const _plans = [
    _Plan(
      id: 'monthly',
      name: 'Pro 月会员',
      price: '¥5',
      period: '/月',
      badge: '',
      isBest: false,
    ),
    _Plan(
      id: 'yearly',
      name: 'Pro 年会员',
      price: '¥39',
      period: '/年',
      badge: '推荐',
      isBest: true,
    ),
    _Plan(
      id: 'lifetime',
      name: 'Pro 永久会员',
      price: '¥68',
      originalPrice: '¥99',
      discountTag: '立省¥31',
      period: '一次性',
      badge: '最划算',
      isBest: false,
    ),
  ];

  static const _benefits = [
    _Benefit(
      icon: Icons.whatshot_outlined,
      title: '历史趋势回溯',
      description: '查看任意日期的 GitHub 热门项目，洞察技术演变趋势',
    ),
    _Benefit(
      icon: Icons.bar_chart,
      title: '完整每日报告',
      description: '每日技术趋势报告，涵盖热门话题与语言聚焦',
    ),
    _Benefit(
      icon: Icons.auto_awesome_outlined,
      title: '仓库深度分析',
      description: '无限制查看任意仓库的技术特点与代码结构',
    ),
    _Benefit(
      icon: Icons.star_border,
      title: '更多精彩即将推出',
      description: '个性化技术周报、自定义趋势通知等 Pro 专属功能',
    ),
  ];

  static const _planTypes = [
    ProPlanType.monthly,
    ProPlanType.yearly,
    ProPlanType.lifetime,
  ];

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    try {
      final products = await _iapService.queryProducts();
      if (!mounted) return;
      setState(() {
        for (final p in products) {
          _livePrices[p.planType.name] = p.localPrice;
        }
      });
    } catch (_) {
      // Fall back to hard-coded prices silently.
    }
  }

  String _displayPrice(_Plan plan) {
    final live = _livePrices[plan.id];
    return live != null && live.isNotEmpty ? live : plan.price;
  }

  Future<void> _subscribe() async {
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先同意隐私条款和服务协议')),
      );
      return;
    }
    if (_loading) return;

    setState(() => _loading = true);
    try {
      final planType = _planTypes[_selectedPlanIndex];
      await _iapService.purchase(planType);
      if (!mounted) return;
      setState(() {}); // Refresh to show member view.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Pro 会员已激活！')),
      );
    } on IapException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'USER_CANCELLED' => '已取消',
        'PAYMENTS_DISABLED' => '设备已禁用应用内购买',
        _ => '购买失败（${e.code}），请稍后重试',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final restored = await _iapService.restorePurchases();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(restored ? '购买记录已恢复' : '未找到购买记录，请尝试直接点击订阅按钮恢复'),
        ),
      );
    } on IapException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('恢复失败（${e.code}），请稍后重试')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMember = _proService.isPro;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CopoHub Pro',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: isMember ? _buildMemberView(cs) : _buildPaywallView(cs),
    );
  }

  // ── Already-member view ───────────────────────────────────────────────────

  Widget _buildMemberView(ColorScheme cs) {
    final planLabel = switch (_proService.planType) {
      ProPlanType.monthly => '月度会员',
      ProPlanType.yearly => '年度会员',
      ProPlanType.lifetime => '永久会员',
      ProPlanType.none => 'Pro 会员',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withAlpha(10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFD75A), Color(0xFFE49A22)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '您已是 Pro 会员',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '所有高级功能已解锁',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withAlpha(
                      cs.brightness == Brightness.dark ? 92 : 150,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_rounded, color: cs.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          planLabel,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      if (_proService.expiryLabel.isNotEmpty)
                        Text(
                          _proService.expiryLabel,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Pro 专属权益',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              children: [
                for (final benefit in _benefits) _BenefitRow(benefit: benefit),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Paywall view ──────────────────────────────────────────────────────────

  Widget _buildPaywallView(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withAlpha(10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFD75A), Color(0xFFE49A22)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '解锁 CopoHub Pro',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '历史趋势、完整日报和仓库深度分析，面向持续追踪技术趋势的开发者。',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Pro 专属权益',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              children: [
                for (final benefit in _benefits) _BenefitRow(benefit: benefit),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '选择方案',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ..._plans.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PlanCard(
                  plan: entry.value,
                  selected: _selectedPlanIndex == entry.key,
                  displayPrice: _displayPrice(entry.value),
                  onTap: () => setState(() => _selectedPlanIndex = entry.key),
                ),
              )),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _agreed = !_agreed),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface,
                        height: 1.45,
                      ),
                      children: [
                        const TextSpan(text: '我已阅读并同意 '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => const PolicyDialog(
                                initialTab: PolicyTab.privacy,
                              ),
                            ),
                            child: Text(
                              '隐私条款',
                              style: TextStyle(
                                color: cs.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: '、'),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => const PolicyDialog(
                                initialTab: PolicyTab.terms,
                              ),
                            ),
                            child: Text(
                              '服务协议',
                              style: TextStyle(
                                color: cs.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: ' 和自动续费服务协议'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: (_loading || !_agreed) ? null : _subscribe,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0969DA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      '订阅 ${_plans[_selectedPlanIndex].name}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '月会员和年会员在订阅到期前 24 小时自动续费，可随时在系统设置中取消订阅。客服邮箱：youdroid2048@gmail.com',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _loading ? null : _restore,
              child: Text(
                '恢复购买',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _Plan {
  const _Plan({
    required this.id,
    required this.name,
    required this.price,
    required this.period,
    this.originalPrice,
    this.discountTag,
    required this.badge,
    required this.isBest,
  });
  final String id;
  final String name;
  final String price;
  final String period;
  final String? originalPrice;
  final String? discountTag;
  final String badge;
  final bool isBest;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(
      {required this.plan,
      required this.selected,
      required this.displayPrice,
      required this.onTap});
  final _Plan plan;
  final bool selected;
  final String displayPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? const Color(0xFF1A237E) : cs.outlineVariant,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? const Color(0xFF1A237E).withAlpha(12)
              : cs.surfaceContainerLowest,
        ),
        child: Row(
          children: [
            // Selection indicator
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? const Color(0xFF1A237E) : cs.outlineVariant,
                  width: 2,
                ),
                color: selected ? const Color(0xFF1A237E) : null,
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
            const SizedBox(width: 12),

            // Plan info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(plan.name,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color:
                                  selected ? const Color(0xFF1A237E) : null)),
                      if (plan.badge.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: plan.isBest
                                ? const Color(0xFF1A237E)
                                : const Color(0xFFF7C948),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            plan.badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color:
                                  plan.isBest ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (plan.discountTag != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        plan.discountTag!,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFE53935)),
                      ),
                    ),
                ],
              ),
            ),

            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      displayPrice,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color:
                            selected ? const Color(0xFF1A237E) : cs.onSurface,
                      ),
                    ),
                    Text(
                      plan.period,
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                if (plan.originalPrice != null)
                  Text(
                    plan.originalPrice!,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Benefit row ───────────────────────────────────────────────────────────────

class _Benefit {
  const _Benefit(
      {required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title;
  final String description;
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.benefit});
  final _Benefit benefit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(benefit.icon, size: 18, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(benefit.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(benefit.description,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
