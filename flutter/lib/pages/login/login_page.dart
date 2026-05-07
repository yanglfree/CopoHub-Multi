import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../components/policy/policy_dialog.dart';
import '../../services/auth_service.dart';
import '../../router/app_router.dart';
import '../../utils/constants.dart';
import '../../utils/platform_utils.dart';
import '../../l10n/app_localizations.dart';

// webview_flutter uses the OpenHarmony-SIG fork which provides ohos support.
bool get _isOhos => isOhos;

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
  final _tokenController = TextEditingController();
  WebViewController? _webViewController;
  String _errorMessage = '';

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
    setState(() {
      _showWebView = false;
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

  Future<void> _pasteTokenFromClipboard(
      EditableTextState editableTextState) async {
    final pastedText = await _getClipboardText();
    if (pastedText == null || pastedText.isEmpty) {
      editableTextState.hideToolbar();
      return;
    }

    final value = _tokenController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final newText = selection.textBefore(value.text) +
        pastedText +
        selection.textAfter(value.text);
    final newOffset = selection.start + pastedText.length;

    editableTextState.userUpdateTextEditingValue(
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newOffset),
      ),
      SelectionChangedCause.toolbar,
    );
    editableTextState.hideToolbar();
  }

  Future<String?> _getClipboardText() async {
    try {
      if (_isOhos) {
        return (await _ohosClipboardChannel.invokeMethod<String>('getText'))
            ?.replaceAll(RegExp(r'\s'), '');
      }

      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text?.replaceAll(RegExp(r'\s'), '');
    } catch (_) {
      return null;
    }
  }

  Widget _buildOhosTokenContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    var hasPasteButton = false;
    final buttonItems = editableTextState.contextMenuButtonItems.map((item) {
      if (item.type != ContextMenuButtonType.paste) {
        return item;
      }

      hasPasteButton = true;
      return item.copyWith(
        onPressed: () => _pasteTokenFromClipboard(editableTextState),
      );
    }).toList();

    if (!hasPasteButton) {
      buttonItems.add(
        ContextMenuButtonItem(
          type: ContextMenuButtonType.paste,
          onPressed: () => _pasteTokenFromClipboard(editableTextState),
        ),
      );
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  48,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 44),
                  _buildHeader(context),
                  const Spacer(flex: 2),
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
                  const Spacer(flex: 2),
                  _buildAgreement(context),
                  const SizedBox(height: 14),
                  _buildFooter(context),
                ],
              ),
            ),
          ),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withAlpha(128)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.loginWithPAT,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.patDesc,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildTokenInput(context)),
              const SizedBox(width: 8),
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () async {
                    final text = await _getClipboardText();
                    if (text == null || text.isEmpty) return;
                    setState(() {
                      _tokenController.text = text;
                      _errorMessage = '';
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(l10n.paste),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: _loading ? null : _loginWithToken,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(l10n.login),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                        _showTokenLogin = false;
                        _tokenController.clear();
                        _errorMessage = '';
                      }),
              child: Text(l10n.back),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenInput(BuildContext context) {
    return TextField(
      controller: _tokenController,
      obscureText: true,
      keyboardType: TextInputType.visiblePassword,
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
      ],
      contextMenuBuilder: _isOhos ? _buildOhosTokenContextMenu : null,
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context).enterPAT,
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.outline,
          fontSize: 13,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
          borderRadius: BorderRadius.circular(8),
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
          onTap: _openTokenHelp,
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

  Future<void> _openTokenHelp() async {
    await launchUrl(
      Uri.parse('https://github.com/settings/tokens'),
      mode: LaunchMode.externalApplication,
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
