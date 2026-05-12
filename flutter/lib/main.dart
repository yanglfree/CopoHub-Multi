import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api/api_cache.dart';
import 'components/dialogs/app_dialog.dart';
import 'l10n/app_localizations.dart';
import 'services/app_update_service.dart';
import 'services/auth_service.dart';
import 'services/clipboard_detector_service.dart';
import 'services/pro_member_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // 8-second timeout guards against Hive/file-system hangs on some
    // HarmonyOS 2-in-1 devices where openBox can block indefinitely.
    await ApiCache.init().timeout(const Duration(seconds: 8), onTimeout: () {
      debugPrint('ApiCache.init timed out (non-fatal)');
    });
  } catch (e) {
    debugPrint('ApiCache.init failed (non-fatal): $e');
  }
  try {
    await ProMemberService.instance
        .initialize()
        .timeout(const Duration(seconds: 8), onTimeout: () {
      debugPrint('ProMemberService.initialize timed out (non-fatal)');
    });
  } catch (e) {
    debugPrint('ProMemberService.initialize failed (non-fatal): $e');
  }
  // AuthService & ThemeService auto-initialize in their constructors.
  AuthService.instance;
  ThemeService.instance;
  // Reset clipboard de-dup on each launch (mirrors HarmonyOS EntryAbility).
  ClipboardDetectorService.instance.resetDuplicateCheck();
  runApp(const ProviderScope(child: CopoHubApp()));
}

class CopoHubApp extends ConsumerStatefulWidget {
  const CopoHubApp({super.key});

  @override
  ConsumerState<CopoHubApp> createState() => _CopoHubAppState();
}

class _CopoHubAppState extends ConsumerState<CopoHubApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Delay update check and initial clipboard detection until after first
    // frame so the router is ready and the user has landed on the home screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.instance.checkAndShowDialogIfNeeded(context);
      _detectClipboard();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _detectClipboard();
    }
  }

  Future<void> _detectClipboard() async {
    // Only detect clipboard after the user has logged in, to avoid triggering
    // the HarmonyOS clipboard-access permission dialog before the user has
    // agreed to the privacy policy.
    if (!AuthService.instance.isLoggedIn) return;

    final result = await ClipboardDetectorService.instance.detect();
    if (result == null) return;

    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;

    _showClipboardDialog(navContext, result);
  }

  void _showClipboardDialog(BuildContext context, ClipboardDetectionResult result) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: '检测到 GitHub 仓库',
        icon: Icons.link,
        actions: [
          AppDialogAction(
            label: '忽略',
            onPressed: () {
              Navigator.pop(dialogContext);
              ClipboardDetectorService.instance.clearClipboard();
            },
          ),
          AppDialogAction(
            label: '查看仓库',
            isPrimary: true,
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(routerProvider).push(
                    '/repository/${result.owner}/${result.repo}',
                  );
            },
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            result.fullName,
            style: const TextStyle(fontSize: 15),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'CopoHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh'),
        Locale('en'),
      ],
    );
  }
}
