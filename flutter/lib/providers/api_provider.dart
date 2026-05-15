import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/copohub_api_client.dart';
import '../api/daily_api_client.dart';
import '../api/github_api_client.dart';

final githubApiClientProvider = Provider<GitHubApiClient>((ref) {
  return GitHubApiClient.instance;
});

final dailyApiClientProvider = Provider<DailyApiClient>((ref) {
  return DailyApiClient.instance;
});

final copohubApiClientProvider = Provider<CopoHubApiClient>((ref) {
  return CopoHubApiClient.instance;
});
