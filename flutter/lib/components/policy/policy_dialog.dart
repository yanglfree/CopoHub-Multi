import 'package:flutter/material.dart';
import '../dialogs/app_dialog.dart';

/// Privacy policy + service terms dialog — mirrors HarmonyOS PolicyDialog.
///
/// Usage:
/// ```dart
/// showDialog(context: context, builder: (_) => const PolicyDialog());
/// // or start on the terms tab:
/// showDialog(context: context, builder: (_) => const PolicyDialog(initialTab: PolicyTab.terms));
/// ```
enum PolicyTab { privacy, terms }

class PolicyDialog extends StatefulWidget {
  const PolicyDialog({
    super.key,
    this.initialTab = PolicyTab.privacy,
    this.onAccept,
    this.onDecline,
    this.showActions = false,
  });

  final PolicyTab initialTab;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  /// When [showActions] is true, shows Accept / Decline buttons (used in
  /// first-launch flow). Otherwise shows only a "关闭" button.
  final bool showActions;

  @override
  State<PolicyDialog> createState() => _PolicyDialogState();
}

class _PolicyDialogState extends State<PolicyDialog> {
  late PolicyTab _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppDialog(
      title: '隐私政策与协议',
      icon: Icons.privacy_tip_outlined,
      maxWidth: 520,
      actions: widget.showActions
          ? [
              AppDialogAction(
                label: '拒绝',
                onPressed: () {
                  widget.onDecline?.call();
                  Navigator.of(context).pop();
                },
              ),
              AppDialogAction(
                label: '接受',
                isPrimary: true,
                onPressed: () {
                  widget.onAccept?.call();
                  Navigator.of(context).pop();
                },
              ),
            ]
          : [
              AppDialogAction(
                label: '关闭',
                isPrimary: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App icon
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/icon.png',
              width: 48,
              height: 48,
              errorBuilder: (_, __, ___) => Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.hub, color: cs.primary, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Tab selector
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TabButton(
                label: '隐私条款',
                selected: _activeTab == PolicyTab.privacy,
                onTap: () => setState(() => _activeTab = PolicyTab.privacy),
              ),
              const SizedBox(width: 8),
              _TabButton(
                label: '服务协议',
                selected: _activeTab == PolicyTab.terms,
                onTap: () => setState(() => _activeTab = PolicyTab.terms),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Flexible(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _activeTab == PolicyTab.privacy
                      ? _privacyContent
                      : _termsContent,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? cs.onPrimary : cs.primary,
          ),
        ),
      ),
    );
  }
}

// ── Policy text content ───────────────────────────────────────────────────────

const _privacyContent = '''隐私条款

生效日期：2025-09-01

我们重视您的隐私与个人信息保护。本隐私条款说明我们如何收集、使用、存储、共享与保护您的个人信息，以及您所享有的权利。请您在使用本应用前仔细阅读。

一、我们收集的信息
1. 账户信息：当您使用 GitHub OAuth 或访问令牌登录时，我们会在您授权范围内获取公开资料（如登录名、头像、公开邮箱等）。
2. 设备与日志信息：为保障服务安全与稳定，我们可能收集设备型号、系统版本、设备标识、网络类型、崩溃日志与基础性能数据。
3. 使用数据：为改进体验，我们统计页面访问与功能使用频率，但不用于建立您的个人画像。

二、我们如何使用信息
1. 提供核心功能（如浏览仓库、用户资料、关注者列表等）与身份验证。
2. 保障产品与服务的运行安全，定位并修复问题，优化性能与体验。
3. 在取得您的同意或法律允许的前提下，用于新功能评估与服务改进。

三、信息共享与第三方
1. 我们不会向第三方出售或出租您的个人信息。
2. 为实现相应功能，我们会在必要最小范围内使用第三方服务（如 GitHub API），并受其条款与政策约束。
3. 在法律法规要求或执法监管机构提出正当请求时，我们可能依法提供必要信息。

四、信息的存储与保护
1. 我们采取合理的安全措施，防止信息被未经授权访问、披露、使用、修改或毁坏。
2. 我们仅在实现处理目的所必需的最短期限内保存您的信息，期限届满后删除或匿名化处理，法律法规另有规定的除外。

五、您的权利
1. 访问、更正与删除：您可以通过账户设置或联系我们访问、更正或删除相关信息。
2. 撤回授权：您可以退出登录或在系统设置中撤回授权，撤回后可能影响相关功能。
3. 投诉与反馈：如对隐私保护有疑问或建议，请通过下述联系方式与我们沟通。

六、未成年人保护
我们不会主动针对未成年人提供服务或收集其信息。若您为未成年人，请在监护人同意与指导下使用本应用。

七、隐私条款的变更
我们可能适时更新隐私条款。重大变更将以应用内提示等方式告知；您继续使用即表示同意更新后的条款。

八、联系方式
如对本隐私条款有任何疑问或投诉，请通过应用内反馈或邮箱联系：copohub@163.com

© 2025 CopoHub Team''';

const _termsContent = '''服务协议

生效日期：2025-09-01

使用本应用即表示您已阅读并同意遵守本协议全部条款。

一、账户与使用
1. 您应保证注册与使用过程中的信息真实、准确、合法，并妥善保管登录凭证。
2. 您仅可为合法目的使用本应用，不得从事破坏平台安全、侵害他人权益或违反公序良俗的行为。

二、许可与知识产权
1. 我们授予您个人的、不可转让、非排他性的许可，以在受支持设备上使用本应用。
2. 本应用及其内容（含商标、Logo、界面、文档与代码等）的知识产权归我们或相关权利人所有。未经书面许可，您不得复制、修改、反向工程、分发或制作衍生作品。

三、第三方服务与内容
1. 本应用对接 GitHub 等第三方服务，相关数据与可用性受第三方条款与政策约束。
2. 因第三方变更、故障或限制导致的功能异常，我们不承担保证责任，但将合理协助排查与优化。

四、更新与中断
为提升体验与安全，我们可能对应用进行更新、变更或中断部分功能，并以合理方式在应用内提示。

五、免责声明与责任限制
1. 在法律允许范围内，本应用按"现状"与"可用"基础提供，不对持续可用性、适用性或无错误作出明示或默示保证。
2. 因不可抗力、第三方原因或您的过错导致的损失，我们不承担相应责任。
3. 在适用法律允许的最大范围内，我们不对任何间接、附带、特殊或惩罚性损害承担责任。

六、终止
如您违反本协议或相关法律法规，我们可在通知或不通知的情况下暂停或终止服务。您也可随时停止使用并卸载本应用。

七、适用法律与争议解决
本协议受您所在国家/地区的强制性法律所约束；在无强制性规定时，以中华人民共和国法律为准据法。争议应先友好协商，协商不成的，提交我方所在地有管辖权的人民法院诉讼解决。

八、其他
1. 我们可能适时修订本协议，重大变更将于应用内提示；变更后您继续使用即视为同意。
2. 如本协议任何条款被认定无效或不可执行，其余条款仍有效。

联系邮箱：copohub@163.com

© 2025 CopoHub Team''';
