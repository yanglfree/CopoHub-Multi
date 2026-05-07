import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../components/navigation/adaptive_bottom_navigation.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../pages/splash/splash_page.dart';
import '../pages/login/login_page.dart';
import '../pages/dashboard/home_page.dart';
import '../pages/notification/notifications_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/discover/discover_page.dart';
import '../pages/daily/daily_page.dart';
import '../pages/repository/repository_page.dart';
import '../pages/search/search_page.dart';
import '../pages/user/user_profile_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/social/social_list_page.dart';
import '../pages/user_profile/starred_repositories_page.dart';
import '../pages/curated/curated_detail_page.dart';
import '../pages/repo_analysis/repo_analysis_page.dart';
import '../models/copohub_curated_item.dart';
import '../models/repository.dart';
import '../pages/member/member_gate_page.dart';
import '../pages/user_profile/user_repositories_page.dart';
import '../pages/create_repo/create_repo_page.dart';
import '../pages/issue/issue_detail_page.dart';
import '../pages/commit/commit_detail_page.dart';
import '../pages/commit/diff_file_detail_page.dart';
import '../pages/file_viewer/file_viewer_page.dart';
import '../pages/featured/featured_page.dart';
import '../l10n/app_localizations.dart';

// ── Route names ───────────────────────────────────────────────────────────────

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const home = '/dashboard/home';
  static const discover = '/dashboard/discover';
  static const featured = '/dashboard/featured';
  static const notifications = '/dashboard/notifications';
  static const profile = '/dashboard/profile';

  // Repository
  static const repository = '/repository/:owner/:repo';
  static const repositoryTree = '/repository/:owner/:repo/tree';
  static const repositoryCommits = '/repository/:owner/:repo/commits';
  static const repositoryIssues = '/repository/:owner/:repo/issues';
  static const repositoryReleases = '/repository/:owner/:repo/releases';

  // Commit
  static const commit = '/commit/:owner/:repo/:sha';

  // Issue
  static const issue = '/issue/:owner/:repo/:number';

  // File viewer
  static const fileViewer = '/file-viewer';

  // User
  static const userProfile = '/user/:username';
  static const social = '/social/:username/:type';
  static const starred = '/starred/:username';

  // Search
  static const search = '/search';

  // Curated / Daily
  static const curated = '/curated';
  static const daily = '/daily';

  // Settings / Repo analysis
  static const settings = '/settings';
  static const createRepo = '/repository/new';
  static const member = '/member';
  static const repoAnalysis = '/repo-analysis';
  static const myRepos = '/my-repos';
  static const userRepos = '/repos/:username';

  // Diff file detail
  static const diffFile = '/diff-file';

  // OAuth callback handled via redirect, not a real route
}

// ── Router provider ───────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = ref.read(authServiceProvider);
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: listenable,
    redirect: (context, state) {
      final authState = listenable.authState;
      final path = state.matchedLocation;

      if (authState == AuthState.initializing) {
        return path == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final isLoggedIn = authState == AuthState.loggedIn;
      final isOnLogin = path == AppRoutes.login;
      final isOnSplash = path == AppRoutes.splash;

      if (!isLoggedIn && !isOnLogin && !isOnSplash) {
        return AppRoutes.login;
      }
      if (isLoggedIn && isOnLogin) {
        return AppRoutes.home;
      }
      // Bare /dashboard → redirect to first tab
      if (path == AppRoutes.dashboard) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginPage(),
      ),

      // ── Dashboard shell (4 tabs) ─────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _DashboardShell(shell: shell),
        branches: [
          // Tab 0: 首页
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, __) => const HomePage(),
            ),
          ]),
          // Tab 1: 发现
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.discover,
              builder: (_, __) => const DiscoverPage(),
            ),
          ]),
          // Tab 2: 精选
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.featured,
              builder: (_, __) => const FeaturedPage(),
            ),
          ]),
          // Tab 3: 通知
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.notifications,
              builder: (_, __) => const NotificationsPage(),
            ),
          ]),
          // Tab 4: 我的
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (_, __) => const ProfilePage(),
            ),
          ]),
        ],
      ),

      // ── Repository ──────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.repository,
        builder: (_, state) {
          final extra = state.extra;
          return RepositoryPage(
            owner: state.pathParameters['owner']!,
            repo: state.pathParameters['repo']!,
            initialRepo: extra is Repository ? extra : null,
          );
        },
      ),

      // ── Commit ──────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.commit,
        builder: (_, state) => CommitDetailPage(
          owner: state.pathParameters['owner']!,
          repo: state.pathParameters['repo']!,
          sha: state.pathParameters['sha']!,
        ),
      ),

      // ── Issue ───────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.issue,
        builder: (_, state) => IssueDetailPage(
          owner: state.pathParameters['owner']!,
          repo: state.pathParameters['repo']!,
          number: int.tryParse(state.pathParameters['number']!) ?? 0,
        ),
      ),

      // ── File viewer ─────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.fileViewer,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return FileViewerPage(
            owner: extra['owner'] as String? ?? '',
            repo: extra['repo'] as String? ?? '',
            path: extra['path'] as String? ?? '',
            branch: extra['branch'] as String? ?? 'main',
            fileName: extra['fileName'] as String?,
          );
        },
      ),

      // ── Diff file detail ────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.diffFile,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return DiffFileDetailPage(
            filename: extra['filename'] as String? ?? '',
            status: extra['status'] as String? ?? 'modified',
            additions: extra['additions'] as int? ?? 0,
            deletions: extra['deletions'] as int? ?? 0,
            patch: extra['patch'] as String?,
          );
        },
      ),

      // ── User profile ─────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.userProfile,
        builder: (_, state) =>
            UserProfilePage(username: state.pathParameters['username']!),
      ),
      GoRoute(
        path: AppRoutes.social,
        builder: (_, state) => SocialListPage(
          username: state.pathParameters['username']!,
          type: state.pathParameters['type']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.starred,
        builder: (_, state) => StarredRepositoriesPage(
          username: state.pathParameters['username']!,
        ),
      ),

      // ── Search / Curated / Daily ────────────────────────────────────────────
      GoRoute(path: AppRoutes.search, builder: (_, __) => const SearchPage()),
      GoRoute(
          path: AppRoutes.curated,
          builder: (context, state) {
            final item = state.extra as CopoHubCuratedItem?;
            if (item == null) {
              return Scaffold(
                  body: Center(
                      child: Text(AppLocalizations.of(context).missingRepoInfo)));
            }
            return CuratedDetailPage(item: item);
          }),
      GoRoute(path: AppRoutes.daily, builder: (_, __) => const DailyPage()),

      // ── Settings / Misc ─────────────────────────────────────────────────────
      GoRoute(
          path: AppRoutes.settings, builder: (_, __) => const SettingsPage()),
      GoRoute(
          path: AppRoutes.member, builder: (_, __) => const MemberGatePage()),
      GoRoute(
          path: AppRoutes.repoAnalysis,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final owner = extra?['owner'] as String? ?? '';
            final repo = extra?['repo'] as String? ?? '';
            if (owner.isEmpty || repo.isEmpty) {
              return Scaffold(
                  body: Center(
                      child: Text(AppLocalizations.of(context).missingParams)));
            }
            return RepoAnalysisPage(owner: owner, repo: repo);
          }),
      GoRoute(
          path: AppRoutes.createRepo,
          builder: (_, __) => const CreateRepoPage()),

      // ── User repositories ─────────────────────────────────────────────
      GoRoute(
          path: AppRoutes.myRepos,
          builder: (_, __) => const UserRepositoriesPage()),
      GoRoute(
          path: AppRoutes.userRepos,
          builder: (_, state) => UserRepositoriesPage(
                username: state.pathParameters['username'],
              )),
    ],
  );
});

// ── Dashboard shell widget ────────────────────────────────────────────────────

class _DashboardShell extends StatelessWidget {
  const _DashboardShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: l10n.discoverTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.star_outline),
            selectedIcon: const Icon(Icons.star),
            label: l10n.featured,
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_outlined),
            selectedIcon: const Icon(Icons.notifications),
            label: l10n.notifications,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.profile,
          ),
        ],
      ),
    );
  }
}
