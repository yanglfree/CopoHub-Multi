import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../components/dialogs/pat_help_dialog.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../components/policy/policy_dialog.dart';
import '../../services/auth_service.dart';
import '../../router/app_router.dart';
import '../../utils/constants.dart';
import '../../utils/platform_utils.dart';
import '../../utils/startup_trace.dart';
import '../../l10n/app_localizations.dart';

// webview_flutter uses the OpenHarmony-SIG fork which provides ohos support.
bool get _isOhos => isOhos;

// Used only for the user-initiated paste button on HarmonyOS. The OHOS
// pasteboard.getData callback correctly suspends until the user responds to
// the permission dialog, making the paste succeed in a single tap.
const _ohosClipboardChannel = MethodChannel('com.youdroid/clipboard');

const _appIconAsset = 'assets/images/ic_icon.png';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _showWebView = false;
  bool _loading = false;
  bool _webLoading = false;
  bool _showTokenLogin = false;
  bool _handlingCallback = false;
  bool _agreementAccepted = false;
  bool _tokenObscured = true;
  final _tokenController = TextEditingController();
  WebViewController? _webViewController;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    StartupTrace.log('LoginPage.initState', StartupTrace.windowSummary());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstLaunch());
  }

  Future<void> _checkFirstLaunch() async {
    StartupTrace.log('LoginPage.checkFirstLaunch.start');
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final accepted = prefs.getBool(Constants.storagePrivacyAccepted) ?? false;
    StartupTrace.log('LoginPage.checkFirstLaunch.end', 'accepted=$accepted');
    if (!accepted) _showFirstLaunchPolicyDialog();
  }

  void _showFirstLaunchPolicyDialog() {
    StartupTrace.log('LoginPage.showFirstLaunchPolicyDialog');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PolicyDialog(
        showActions: true,
        onAccept: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(Constants.storagePrivacyAccepted, true);
          if (mounted) setState(() => _agreementAccepted = true);
        },
        onDecline: () => exit(0),
      ),
    );
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  // ── OAuth flow ─────────────────────────────────────────────────────────────

  void _startOAuth() {
    final url = AuthService.instance.getGitHubOAuthUrl();
    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          if (req.url.startsWith('coderepo://')) {
            _handleCallback(req.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageStarted: (_) => setState(() => _webLoading = true),
        onPageFinished: (_) => setState(() => _webLoading = false),
        // Android: server-side 302 redirect to custom scheme fires
        // ERR_UNKNOWN_URL_SCHEME instead of onNavigationRequest.
        onWebResourceError: (error) {
          final url = error.url ?? '';
          if (url.startsWith('coderepo://')) {
            _handleCallback(url);
          }
        },
      ))
      ..loadRequest(Uri.parse(url));

    setState(() {
      _webViewController = ctrl;
      _showWebView = true;
      _errorMessage = '';
    });
  }

  Future<void> _handleCallback(String url) async {
    if (_handlingCallback) return;
    _handlingCallback = true;
    // Stop the webview from loading before removing it from the tree.
    // On iOS, removing WebViewWidget while WKWebView is still navigating causes
    // pending native delegate callbacks to fire against a closed Flutter channel,
    // which triggers NSAssert(!error) → NSInternalInconsistencyException.
    final ctrl = _webViewController;
    if (ctrl != null) {
      await ctrl.loadRequest(Uri.dataFromString(''));
    }
    setState(() {
      _showWebView = false;
      _webViewController = null;
      _loading = true;
      _errorMessage = '';
    });

    final result = await AuthService.instance.handleGitHubCallback(url);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      context.go(AppRoutes.dashboard);
    } else {
      _handlingCallback = false;
      setState(() => _errorMessage =
          result.message ?? AppLocalizations.of(context).loginFailedRetry);
    }
  }

  // ── PAT token flow ─────────────────────────────────────────────────────────

  Future<void> _loginWithToken() async {
    final l10n = AppLocalizations.of(context);
    if (!_agreementAccepted) {
      setState(() => _errorMessage = l10n.acceptTermsFirst);
      return;
    }

    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _errorMessage = l10n.enterPATFirst);
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = '';
    });

    final result = await AuthService.instance.loginWithToken(token);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      context.go(AppRoutes.dashboard);
    } else {
      setState(() => _errorMessage = result.message ?? l10n.tokenLoginFailed);
    }
  }

  Future<String?> _getClipboardText() async {
    try {
      if (_isOhos) {
        // On HarmonyOS, pasteboard.getData suspends until the user responds to
        // the READ_PASTEBOARD permission dialog, so this succeeds in one tap.
        return (await _ohosClipboardChannel.invokeMethod<String>('getText'))
            ?.replaceAll(RegExp(r'\s'), '');
      }
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text?.replaceAll(RegExp(r'\s'), '');
    } catch (_) {
      return null;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    StartupTrace.log(
      'LoginPage.build',
      '${StartupTrace.windowSummary()} webView=$_showWebView '
          'token=$_showTokenLogin loading=$_loading',
    );
    final l10n = AppLocalizations.of(context);
    if (_showWebView && _webViewController != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.loginWithGithub),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              _showWebView = false;
              _webViewController = null;
            }),
          ),
          bottom: _webLoading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(),
                )
              : null,
        ),
        body: WebViewWidget(controller: _webViewController!),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minContentHeight =
                constraints.maxHeight > 48 ? constraints.maxHeight - 48 : 0.0;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minContentHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 44),
                    _buildHeader(context),
                    const SizedBox(height: 48),
                    if (_loading)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(),
                      ))
                    else if (_showTokenLogin)
                      _buildTokenPanel(context)
                    else
                      _buildLoginActions(context),
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildError(),
                    ],
                    const SizedBox(height: 48),
                    _buildAgreement(context),
                    const SizedBox(height: 14),
                    _buildFooter(context),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              _appIconAsset,
              width: 108,
              height: 108,
              cacheWidth: 216,
              cacheHeight: 216,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'CopoHub',
          style: Theme.of(context)
              .textTheme
              .displaySmall
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0),
        ),
        const SizedBox(height: 6),
        Text(
          AppLocalizations.of(context).githubMobileClient,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: cs.outline),
        ),
      ],
    );
  }

  Widget _buildLoginActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: _agreementAccepted && !_loading ? _startOAuth : null,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return Theme.of(context).colorScheme.onSurface.withAlpha(30);
                }
                return const Color(0xFF24292F);
              }),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              elevation: const WidgetStatePropertyAll(0),
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            child: Text(AppLocalizations.of(context).loginWithGithub),
          ),
        ),
        const SizedBox(height: 24),
        _buildDivider(context),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                      _showTokenLogin = true;
                      _errorMessage = '';
                    }),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              disabledBackgroundColor:
                  Theme.of(context).colorScheme.primaryContainer.withAlpha(128),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(AppLocalizations.of(context).loginWithToken),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: cs.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            AppLocalizations.of(context).or,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(child: Divider(color: cs.outlineVariant)),
      ],
    );
  }

  Widget _buildTokenPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.key_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.loginWithToken,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.patDesc,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 16),
        _buildTokenInput(context),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: _loading ? null : _loginWithToken,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return cs.onSurface.withAlpha(30);
                }
                return const Color(0xFF24292F);
              }),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
              shape: const WidgetStatePropertyAll(
                RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(28))),
              ),
              elevation: const WidgetStatePropertyAll(0),
              textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            child: Text(l10n.login),
          ),
        ),
        TextButton(
          onPressed: _loading
              ? null
              : () => setState(() {
                    _showTokenLogin = false;
                    _tokenController.clear();
                    _errorMessage = '';
                  }),
          child: Text(l10n.back),
        ),
      ],
    );
  }

  Widget _buildTokenInput(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: _tokenController,
      obscureText: _tokenObscured,
      keyboardType: TextInputType.visiblePassword,
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
      ],
      decoration: InputDecoration(
        hintText: l10n.enterPAT,
        hintStyle: TextStyle(color: cs.outline, fontSize: 13),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        contentPadding:
            const EdgeInsets.only(left: 16, top: 14, bottom: 14, right: 4),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: cs.primary, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _tokenObscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              onPressed: () => setState(() => _tokenObscured = !_tokenObscured),
            ),
            IconButton(
              icon: Icon(Icons.content_paste_rounded,
                  size: 20, color: cs.primary),
              tooltip: l10n.paste,
              onPressed: () async {
                final text = await _getClipboardText();
                if (!mounted || text == null || text.isEmpty) return;
                setState(() {
                  _tokenController.text = text;
                  _errorMessage = '';
                });
              },
            ),
          ],
        ),
      ),
      onSubmitted: (_) => _loginWithToken(),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              size: 16, color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreement(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: _agreementAccepted,
          onChanged: (value) =>
              setState(() => _agreementAccepted = value ?? false),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.readAndAccept,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              _FooterLink(
                text: l10n.termsOfService,
                onTap: () => _showPolicy(PolicyTab.terms),
              ),
              Text(
                l10n.and,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              _FooterLink(
                text: l10n.privacyPolicy,
                onTap: () => _showPolicy(PolicyTab.privacy),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _FooterLink(
          text: l10n.howToGetPAT,
          fontSize: 16,
          onTap: _showTokenHelp,
        ),
        const SizedBox(height: 10),
        Text(
          '${l10n.version} ${Constants.appVersion}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.outline,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '© 2025 CopoHub Team',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.outline,
              ),
        ),
      ],
    );
  }

  void _showPolicy(PolicyTab tab) {
    showDialog<void>(
      context: context,
      builder: (_) => PolicyDialog(initialTab: tab),
    );
  }

  void _showTokenHelp() {
    showDialog<void>(
      context: context,
      builder: (_) => const PATHelpDialog(),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.text,
    required this.onTap,
    this.fontSize,
  });

  final String text;
  final VoidCallback onTap;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontSize: fontSize,
              decoration: TextDecoration.underline,
              decorationColor: color,
              decorationThickness: 1.2,
            ),
      ),
    );
  }
}
