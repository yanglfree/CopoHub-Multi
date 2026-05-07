import 'package:flutter/material.dart';

/// Hand-written localization class — supports 'en' and 'zh'.
/// Add strings here as the app grows; run flutter gen-l10n if migrating to ARB.
class AppLocalizations {
  AppLocalizations(this.locale);
  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get _zh => locale.languageCode == 'zh';

  String get retry => _zh ? '重试' : 'Retry';
  String get cancel => _zh ? '取消' : 'Cancel';
  String get confirm => _zh ? '确定' : 'Confirm';
  String get close => _zh ? '关闭' : 'Close';
  String get settings => _zh ? '设置' : 'Settings';
  String get accept => _zh ? '接受' : 'Accept';
  String get decline => _zh ? '拒绝' : 'Decline';

  // ── Components ─────────────────────────────────────────────────────────────
  // Contribution Calendar
  String get contributionHeatmap => _zh ? '贡献热力图' : 'Contribution Heatmap';
  String get changeHeatmapColor => _zh ? '更改贡献图颜色' : 'Change colors';
  String get mon => _zh ? '周一' : 'Mon';
  String get wed => _zh ? '周三' : 'Wed';
  String get fri => _zh ? '周五' : 'Fri';
  String get less => _zh ? '少' : 'Less';
  String get more => _zh ? '多' : 'More';
  String contributionsInLastYear(int count) => _zh
      ? '过去一年有 $count 次贡献'
      : '$count contributions in the last year';
  String contributionsInYear(int count, int year) => _zh
      ? '$year 年有 $count 次贡献'
      : '$count contributions in $year';
  String contributionsOnDate(int count, String date) => _zh
      ? '$date 有 $count 次贡献'
      : '$count contributions on $date';
  String noContributionsOnDate(String date) => _zh
      ? '$date 无贡献'
      : 'No contributions on $date';

  List<String> get months => _zh

      ? ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月']
      : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  // Daily Report
  String get dailyReportTitle => _zh ? 'GitHub Trending 日报' : 'GitHub Trending Daily';
  String get languageTrends => _zh ? '语言动态' : 'Language Trends';
  String get featuredRepos => _zh ? '精选仓库' : 'Featured Repos';
  String get today => _zh ? '今天' : 'Today';
  String get yesterday => _zh ? '昨天' : 'Yesterday';
  String get openDetails => _zh ? '打开详情' : 'Open Details';
  String get updated => _zh ? '更新' : 'Updated';
  String get sharePreview => _zh ? '分享预览' : 'Share Preview';
  String get shareImage => _zh ? '分享图片' : 'Share Image';
  String get generating => _zh ? '生成中…' : 'Generating…';
  String get shareSlogan => _zh ? '每天发现更多精彩仓库，尽在 CopoHub' : 'Discover more amazing repos every day on CopoHub';
  String get highlight => _zh ? '本期亮点' : 'Highlights';

  // Policy
  String get privacyPolicyTitle => _zh ? '隐私政策与协议' : 'Privacy Policy & Terms';

  String get privacyContent => _zh ? _privacyContentZh : _privacyContentEn;
  String get termsContent => _zh ? _termsContentZh : _termsContentEn;

  static const _privacyContentZh = '''隐私条款
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
如对本隐私条款有任何疑问或投诉，请通过应用内反馈或邮箱联系：copohub@163.com''';

  static const _privacyContentEn = '''Privacy Policy
Effective Date: 2025-09-01

We value your privacy and the protection of your personal information. This Privacy Policy explains how we collect, use, store, share, and protect your personal information, as well as the rights you enjoy. Please read this carefully before using the application.

1. Information We Collect
1. Account Information: When you log in using GitHub OAuth or an access token, we obtain public profile information (such as login name, avatar, public email, etc.) within the scope of your authorization.
2. Device and Log Information: To ensure service safety and stability, we may collect device model, system version, device identifiers, network type, crash logs, and basic performance data.
3. Usage Data: To improve the experience, we track page visits and feature usage frequency, but do not use this to build a personal profile.

2. How We Use Information
1. Provide core features (such as browsing repositories, user profiles, followers lists, etc.) and authentication.
2. Ensure the safety of products and services, locate and fix problems, and optimize performance and experience.
3. Use for new feature evaluation and service improvement with your consent or as permitted by law.

3. Information Sharing and Third Parties
1. We do not sell or rent your personal information to third parties.
2. To achieve corresponding functions, we use third-party services (such as GitHub API) within the minimum necessary scope and are bound by their terms and policies.
3. We may provide necessary information as required by laws and regulations or justified requests from law enforcement agencies.

4. Storage and Protection of Information
1. We take reasonable security measures to prevent unauthorized access, disclosure, use, modification, or destruction of information.
2. We keep your information only for the minimum period necessary to achieve the processing purpose, and delete or anonymize it after the expiration of the period, unless otherwise provided by laws and regulations.

5. Your Rights
1. Access, Correction, and Deletion: You can access, correct, or delete related information through account settings or by contacting us.
2. Withdrawal of Authorization: You can log out or withdraw authorization in system settings, which may affect related functions.
3. Complaints and Feedback: If you have questions or suggestions about privacy protection, please communicate with us through the contact information below.

6. Protection of Minors
We do not actively provide services to or collect information from minors. If you are a minor, please use this application under the consent and guidance of a guardian.

7. Changes to Privacy Policy
We may update the Privacy Policy from time to time. Major changes will be notified through in-app prompts; your continued use indicates agreement to the updated terms.

8. Contact Information
If you have any questions or complaints about this Privacy Policy, please contact us through in-app feedback or email: copohub@163.com''';

  static const _termsContentZh = '''服务协议
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

联系邮箱：copohub@163.com''';

  static const _termsContentEn = '''Terms of Service
Effective Date: 2025-09-01

Using this application indicates that you have read and agree to comply with all terms of this agreement.

1. Account and Use
1. You should ensure that the information during registration and use is true, accurate, and legal, and properly keep login credentials.
2. You may use this application only for legal purposes and shall not engage in behaviors that destroy platform security, infringe on others' rights, or violate public order and good customs.

2. License and Intellectual Property
1. We grant you a personal, non-transferable, non-exclusive license to use this application on supported devices.
2. The intellectual property rights of this application and its content (including trademarks, logos, interfaces, documents, and code, etc.) belong to us or related right holders. Without written permission, you may not copy, modify, reverse engineer, distribute, or create derivative works.

3. Third-party Services and Content
1. This application connects to third-party services such as GitHub, and related data and availability are bound by third-party terms and policies.
2. We do not assume guarantee responsibility for functional abnormalities caused by third-party changes, failures, or restrictions, but will reasonably assist in troubleshooting and optimization.

4. Updates and Interruptions
To improve experience and safety, we may update, change, or interrupt some functions of the application and notify in a reasonable manner within the application.

5. Disclaimer and Limitation of Liability
1. Within the scope permitted by law, this application is provided on an "as is" and "as available" basis, and no express or implied warranty is made for continuous availability, suitability, or error-free operation.
2. We do not assume corresponding responsibility for losses caused by force majeure, third-party reasons, or your fault.
3. To the maximum extent permitted by applicable law, we are not liable for any indirect, incidental, special, or punitive damages.

6. Termination
If you violate this agreement or related laws and regulations, we may suspend or terminate services with or without notice. You can also stop using and uninstall this application at any time.

7. Governing Law and Dispute Resolution
This agreement is governed by the mandatory laws of your country/region; in the absence of mandatory provisions, the laws of the People's Republic of China shall be the governing law. Disputes should be settled through friendly negotiation first; if negotiation fails, they shall be submitted to the people's court with jurisdiction in our location for litigation.

8. Others
1. We may revise this agreement from time to time, and major changes will be prompted within the application; your continued use after the change is deemed as agreement.
2. If any term of this agreement is found to be invalid or unenforceable, the remaining terms shall still be valid.

Contact Email: copohub@163.com''';

  // ── Notifications ─────────────────────────────────────────────────────────
  String get notificationsTitle => _zh ? '通知' : 'Notifications';
  String get markAllAsRead => _zh ? '全部标为已读' : 'Mark all as read';
  String get unread => _zh ? '未读' : 'Unread';
  String get noNotifications => _zh ? '暂无通知' : 'No notifications';

  // Notification reasons
  String get reasonMention => _zh ? '提及' : 'Mention';
  String get reasonAssign => _zh ? '分配' : 'Assign';
  String get reasonAuthor => _zh ? '作者' : 'Author';
  String get reasonComment => _zh ? '评论' : 'Comment';
  String get reasonSubscribed => _zh ? '订阅' : 'Subscribed';
  String get reasonReviewRequested => _zh ? '审阅' : 'Review requested';
  String get reasonStateChange => _zh ? '状态变更' : 'State change';
  String get reasonTeamMention => _zh ? '团队提及' : 'Team mention';

  // ── Profile ────────────────────────────────────────────────────────────────
  String get editProfile => _zh ? '编辑资料' : 'Edit Profile';
  String get setStatus => _zh ? '设置状态' : 'Set Status';
  String get changeStatus => _zh ? '修改状态' : 'Change Status';
  String get save => _zh ? '保存' : 'Save';
  String get clear => _zh ? '清除' : 'Clear';
  String get followers => _zh ? '关注者' : 'Followers';
  String get following => _zh ? '正在关注' : 'Following';
  String get repositories => _zh ? '仓库' : 'Repositories';

  // Activity
  String get recentActivity => _zh ? '近期动态' : 'Recent Activity';
  String get last90Days => _zh ? '近90天' : 'Last 90 days';
  String get commits => _zh ? '提交' : 'Commits';
  String get newRepos => _zh ? '新仓库' : 'New Repos';
  String get pullRequests => _zh ? 'PR' : 'PRs';

  // Sections
  String get organizations => _zh ? '所属组织' : 'Organizations';
  String get pinnedRepos => _zh ? '置顶仓库' : 'Pinned Repos';
  String get topRepos => _zh ? '热门仓库' : 'Top Repos';
  String get social => _zh ? '社交' : 'Social';
  String get viewAll => _zh ? '查看全部' : 'View All';
  String get noFollowers => _zh ? '暂无关注者' : 'No followers';
  String get noFollowing => _zh ? '暂无正在关注' : 'No following';
  String get socialLoadFailed => _zh ? '社交信息加载失败' : 'Failed to load social info';

  // Dialogs & Forms
  String get editProfileTitle => _zh ? '编辑资料' : 'Edit Profile';
  String get nameLabel => 'Name';
  String get emailLabel => 'Public email';
  String get blogLabel => 'Blog';
  String get companyLabel => 'Company';
  String get locationLabel => 'Location';
  String get bioLabel => 'Bio';
  String get availableForHire => _zh ? '允许雇佣' : 'Available for hire';
  String get statusMessageLabel => _zh ? '状态信息' : 'Status message';
  String get busyLabel => _zh ? '忙碌 / 限制可用性' : 'Busy / limited availability';
  String get notFilled => _zh ? '未填写' : 'Not filled';

  // ── Navigation & Router ────────────────────────────────────────────────────
  String get home => _zh ? '首页' : 'Home';
  String get featured => _zh ? '精选' : 'Featured';
  String get notifications => _zh ? '通知' : 'Notifications';
  String get profile => _zh ? '我的' : 'Profile';
  String get missingRepoInfo => _zh ? '仓库信息缺失' : 'Missing repository info';
  String get missingParams => _zh ? '参数缺失' : 'Missing parameters';

  // ── Login Page ─────────────────────────────────────────────────────────────
  String get loginWithGithub => _zh ? '使用 GitHub 登录' : 'Sign in with GitHub';
  String get githubMobileClient => _zh ? 'GitHub 移动客户端' : 'GitHub Mobile Client';
  String get loginWithToken => _zh ? '使用访问令牌登录' : 'Sign in with Access Token';
  String get or => _zh ? '或者' : 'Or';
  String get loginWithPAT => _zh ? '使用 Personal Access Token 登录' : 'Sign in with Personal Access Token';
  String get patDesc => _zh ? '请在 GitHub 设置中生成 Personal Access Token，并确保包含 repo 和 user 权限。' : 'Generate a Personal Access Token in GitHub settings and ensure it has repo and user permissions.';
  String get paste => _zh ? '粘贴' : 'Paste';
  String get login => _zh ? '登录' : 'Login';
  String get back => _zh ? '返回' : 'Back';
  String get enterPAT => _zh ? '输入您的 Personal Access Token' : 'Enter your Personal Access Token';
  String get readAndAccept => _zh ? '我已阅读并接受 ' : 'I have read and accept ';
  String get termsOfService => _zh ? '《服务协议》' : 'Terms of Service';
  String get and => _zh ? ' 和 ' : ' and ';
  String get privacyPolicy => _zh ? '《隐私条款》' : 'Privacy Policy';
  String get howToGetPAT => _zh ? '如何获取 Personal Access Token?' : 'How to get Personal Access Token?';
  String get version => _zh ? '版本' : 'Version';

  // Login Errors
  String get loginFailedRetry => _zh ? '登录失败，请重试' : 'Login failed, please try again';
  String get acceptTermsFirst => _zh ? '请先阅读并接受服务协议和隐私条款' : 'Please read and accept the Terms and Privacy Policy first';
  String get enterPATFirst => _zh ? '请输入 Personal Access Token' : 'Please enter your Personal Access Token';
  String get tokenLoginFailed => _zh ? 'Token 登录失败，请检查后重试' : 'Token login failed, please check and try again';

  // ── Discover page ──────────────────────────────────────────────────────────
  String get discoverTitle => _zh ? '发现' : 'Discover';
  String get search => _zh ? '搜索' : 'Search';
  String get popular => _zh ? '热门' : 'Popular';
  String get trending => _zh ? '趋势' : 'Trending';
  String get latest => _zh ? '最新' : 'Latest';

  // ── Repository page tabs ──────────────────────────────────────────────────
  String get tabReadme => 'README';
  String get tabCode => _zh ? '代码' : 'Code';
  String get tabIssues => _zh ? '问题' : 'Issues';
  String get tabCommits => _zh ? '提交' : 'Commits';
  String get tabReleases => _zh ? '发布' : 'Releases';

  // ── Issues filter ─────────────────────────────────────────────────────────
  String get filterAll => _zh ? '全部' : 'All';
  String get filterOpen => _zh ? '开放' : 'Open';
  String get filterClosed => _zh ? '已关闭' : 'Closed';

  // ── Empty & error states ──────────────────────────────────────────────────
  String get noReadme => _zh ? '暂无 README' : 'No README';
  String get noIssues => _zh ? '暂无 Issues' : 'No Issues';
  String get noReleases => _zh ? '暂无 Release' : 'No Releases';
  String get noCommits => _zh ? '暂无提交' : 'No commits';
  String get noFiles => _zh ? '暂无文件' : 'No files';
  String get loadFailed => _zh ? '加载失败' : 'Load failed';
  String get readmeLoadFailed => _zh ? 'README 加载失败' : 'Failed to load README';

  // ── Branch ────────────────────────────────────────────────────────────────
  String get branch => _zh ? '分支' : 'Branch';
  String get selectBranch => _zh ? '选择分支' : 'Select branch';
  String get branchesAndTags => _zh ? '分支与标签' : 'Branches & Tags';

  // ── Code tab ──────────────────────────────────────────────────────────────
  String get root => _zh ? '根目录' : 'Root';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
