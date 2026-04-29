import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'api/api_cache.dart';
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
    await ApiCache.init();
  } catch (e) {
    debugPrint('ApiCache.init failed (non-fatal): $e');
  }
  try {
    await ProMemberService.instance.initialize();
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
    // Delay update check until after first frame so router is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.instance.checkAndShowDialogIfNeeded(context);
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
    final result = await ClipboardDetectorService.instance.detect();
    if (result == null || !mounted) return;
    _showClipboardDialog(result);
  }

  void _showClipboardDialog(ClipboardDetectionResult result) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('检测到 GitHub 仓库'),
        content: Text(result.fullName),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ClipboardDetectorService.instance.clearClipboard();
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.push(
                '/repository/${result.owner}/${result.repo}',
              );
            },
            child: const Text('查看'),
          ),
        ],
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
