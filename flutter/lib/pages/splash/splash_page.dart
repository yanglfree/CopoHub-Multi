import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../router/app_router.dart';
import '../../utils/startup_trace.dart';

const _appIconAsset = 'assets/images/ic_icon.png';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _iconOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.58, curve: Curves.easeOut),
      ),
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.58, 1.0, curve: Curves.easeOut),
      ),
    );

    _ctrl.forward();
    _waitForAuth();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _waitForAuth() {
    final auth = AuthService.instance;
    StartupTrace.log('SplashPage.waitForAuth', 'authState=${auth.authState}');
    if (auth.authState != AuthState.initializing) {
      _navigateAfterDelay(auth.isLoggedIn);
      return;
    }
    void listener() {
      if (auth.authState != AuthState.initializing) {
        auth.removeListener(listener);
        StartupTrace.log('SplashPage.authResolved', 'authState=${auth.authState}');
        if (mounted) _navigateAfterDelay(auth.isLoggedIn);
      }
    }

    auth.addListener(listener);
  }

  void _navigateAfterDelay(bool loggedIn) {
    StartupTrace.log('SplashPage.navigateAfterDelay', 'loggedIn=$loggedIn');
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      final dest = loggedIn ? AppRoutes.dashboard : AppRoutes.login;
      StartupTrace.log('SplashPage.navigate', 'to=$dest');
      context.go(dest);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Centered logo + name ─────────────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _iconOpacity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          _appIconAsset,
                          width: 120,
                          height: 120,
                          cacheWidth: 240,
                          cacheHeight: 240,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      children: [
                        Text(
                          'CopoHub',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Github Client for Mobile',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: cs.outline,
                                    fontWeight: FontWeight.w400,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Copyright footer ─────────────────────────────────────────────
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _textOpacity,
                child: Text(
                  'Copyright © 2025-2026 Copohub',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
