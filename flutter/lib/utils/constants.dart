import 'dart:math';

// Contribution chart theme
class ContributionTheme {
  final String name;
  final List<String> colors;
  const ContributionTheme({required this.name, required this.colors});
}

class Constants {
  // ── GitHub OAuth ────────────────────────────────────────────────────────────
  static const String githubClientId = 'Ov23litQwfVyaJZHybK5';
  // NOTE: client_secret in mobile apps is inherently public.
  // For production, consider a backend proxy for the token exchange step.
  static const String githubClientSecret =
      '7242fd7ed2792dc5e7a9b266fcf6026017368c21';
  static const String githubRedirectUri = 'coderepo://auth/callback';
  static const String githubScope = 'user repo notifications';

  static const String githubOAuthUrl =
      'https://github.com/login/oauth/authorize';
  static const String githubTokenUrl =
      'https://github.com/login/oauth/access_token';

  // ── API ─────────────────────────────────────────────────────────────────────
  static const String apiBaseUrl = 'https://api.github.com';
  static const String apiVersion = '2022-11-28';
  static const String userAgent = 'CopoHub-Flutter/1.0';

  static const String copoHubBaseUrl = 'https://github.fq6825.top';
  static const String dailyBaseUrl = 'https://github.fq6825.top';

  // ── Storage keys ────────────────────────────────────────────────────────────
  static const String storageAccessToken = 'github_access_token';
  static const String storageUserInfo = 'github_user_info';
  static const String storageThemeMode = 'app_theme_mode';
  static const String storageContributionTheme = 'contribution_theme_color';

  // ── Pagination ──────────────────────────────────────────────────────────────
  static const int defaultPageSize = 30;

  // ── Cache ───────────────────────────────────────────────────────────────────
  static const Duration defaultCacheTtl = Duration(minutes: 5);
  static const Duration socialCacheTtl = Duration(minutes: 10);
  static const Duration repositoryCacheTtl = Duration(minutes: 15);

  // ── Network timeouts ────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);

  // ── App info ─────────────────────────────────────────────────────────────────
  static const String appName = 'CopoHub';
  static const String appVersion = '1.4.0';
  static const String privacyUrl = 'https://copohub.com/privacy';
  static const String termsUrl = 'https://copohub.com/terms';

  // ── Language colors ──────────────────────────────────────────────────────────
  static const Map<String, String> languageColors = {
    'JavaScript': '#f1e05a',
    'TypeScript': '#2b7489',
    'Python': '#3572A5',
    'Java': '#b07219',
    'Swift': '#fa7343',
    'Kotlin': '#F18E33',
    'Go': '#00ADD8',
    'Rust': '#dea584',
    'C++': '#f34b7d',
    'C': '#555555',
    'C#': '#239120',
    'PHP': '#4F5D95',
    'Ruby': '#701516',
    'Vue': '#41b883',
    'HTML': '#e34c26',
    'CSS': '#563d7c',
    'Dart': '#00B4AB',
    'Shell': '#89e051',
    'Objective-C': '#438eff',
    'Scala': '#c22d40',
    'R': '#198CE7',
    'Perl': '#0298c3',
    'Lua': '#000080',
    'MATLAB': '#e16737',
  };

  static String getLanguageColor(String language) {
    return languageColors[language] ?? '#586069';
  }

  // ── Contribution chart themes ────────────────────────────────────────────────
  static const List<ContributionTheme> contributionThemes = [
    ContributionTheme(
        name: 'Green',
        colors: ['#ebedf0', '#9be9a8', '#40c463', '#30a14e', '#216e39']),
    ContributionTheme(
        name: 'Blue',
        colors: ['#ebedf0', '#9ecbff', '#0969da', '#0550ae', '#0a3069']),
    ContributionTheme(
        name: 'Purple',
        colors: ['#ebedf0', '#ddd6fe', '#8b5cf6', '#7c3aed', '#5b21b6']),
    ContributionTheme(
        name: 'Yellow',
        colors: ['#ebedf0', '#fef3c7', '#fbbf24', '#f59e0b', '#d97706']),
    ContributionTheme(
        name: 'Orange',
        colors: ['#ebedf0', '#fed7aa', '#fb923c', '#f97316', '#ea580c']),
    ContributionTheme(
        name: 'Red',
        colors: ['#ebedf0', '#fecaca', '#f87171', '#ef4444', '#b91c1c']),
    ContributionTheme(
        name: 'Pink',
        colors: ['#ebedf0', '#fbcfe8', '#f472b6', '#ec4899', '#be185d']),
    ContributionTheme(
        name: 'Teal',
        colors: ['#ebedf0', '#99f6e4', '#5eead4', '#2dd4bf', '#115e59']),
  ];

  static List<String> getContributionThemeColors(String themeName) {
    return contributionThemes
            .where((t) => t.name == themeName)
            .firstOrNull
            ?.colors ??
        contributionThemes.first.colors;
  }

  // ── OAuth helpers ────────────────────────────────────────────────────────────
  static String generateRandomState() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static String buildGitHubOAuthUrl() {
    final state = generateRandomState();
    final params = Uri(queryParameters: {
      'client_id': githubClientId,
      'redirect_uri': githubRedirectUri,
      'scope': githubScope,
      'state': state,
    }).query;
    return '$githubOAuthUrl?$params';
  }

  static bool isValidGitHubCallback(String url) {
    return url.startsWith(githubRedirectUri);
  }

  static Map<String, String?> extractAuthCallbackParams(String url) {
    try {
      final uri = Uri.parse(
          url.replaceFirst(RegExp(r'^coderepo://'), 'https://dummy.host/'));
      return {
        'code': uri.queryParameters['code'],
        'error': uri.queryParameters['error'],
        'state': uri.queryParameters['state'],
      };
    } catch (_) {
      return {'error': 'invalid_callback'};
    }
  }
}
