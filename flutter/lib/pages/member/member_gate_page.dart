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
          content:
              Text(restored ? '购买记录已恢复' : '未找到购买记录，请尝试直接点击订阅按钮恢复'),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            Text('您已是 Pro 会员',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(planLabel, style: TextStyle(color: cs.primary, fontSize: 15)),
            if (_proService.expiryLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_proService.expiryLabel,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            ],
            const SizedBox(height: 32),
            ..._benefits.map((b) => _BenefitRow(benefit: b)),
          ],
        ),
      ),
    );
  }

  // ── Paywall view ──────────────────────────────────────────────────────────

  Widget _buildPaywallView(ColorScheme cs) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header gradient banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF283593)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 12),
                const Text(
                  'CopoHub Pro',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '解锁全部高级功能',
                  style: TextStyle(
                      color: Colors.white.withAlpha(180), fontSize: 14),
                ),
              ],
            ),
          ),

          // Benefits + plans
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pro 专属权益',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ..._benefits.map((b) => _BenefitRow(benefit: b)),
                const SizedBox(height: 20),

                // Plan selector
                Text(
                  '选择方案',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ..._plans.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PlanCard(
                        plan: entry.value,
                        selected: _selectedPlanIndex == entry.key,
                        displayPrice: _displayPrice(entry.value),
                        onTap: () =>
                            setState(() => _selectedPlanIndex = entry.key),
                      ),
                    )),
                const SizedBox(height: 16),

                // Agreement checkbox
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
                                color: Theme.of(context).colorScheme.onSurface),
                            children: [
                              const TextSpan(text: '我已阅读并同意 '),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () => showDialog(
                                    context: context,
                                    builder: (_) => const PolicyDialog(
                                        initialTab: PolicyTab.privacy),
                                  ),
                                  child: Text(
                                    '隐私条款',
                                    style: TextStyle(
                                        color: cs.primary,
                                        fontSize: 12,
                                        decoration: TextDecoration.underline),
                                  ),
                                ),
                              ),
                              const TextSpan(text: ' 和 '),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () => showDialog(
                                    context: context,
                                    builder: (_) => const PolicyDialog(
                                        initialTab: PolicyTab.terms),
                                  ),
                                  child: Text(
                                    '服务协议',
                                    style: TextStyle(
                                        color: cs.primary,
                                        fontSize: 12,
                                        decoration: TextDecoration.underline),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Subscribe button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _loading ? null : _subscribe,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '随时可取消 · 安全支付',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 8),

                // Restore button
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : _restore,
                    child: Text(
                      '恢复购买',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
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
