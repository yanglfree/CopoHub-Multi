import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/github_api_client.dart';
import '../models/user.dart';
import '../utils/constants.dart';

// ── Types ─────────────────────────────────────────────────────────────────────

enum AuthState {
  initializing,
  loggedOut,
  loggingIn,
  loggedIn,
  error,
}

class AuthResult {
  final bool success;
  final GithubUser? user;
  final String? error;
  final String? message;

  const AuthResult({
    required this.success,
    this.user,
    this.error,
    this.message,
  });

  factory AuthResult.ok(GithubUser user) =>
      AuthResult(success: true, user: user, message: '登录成功');

  factory AuthResult.fail(String message, {String? error}) =>
      AuthResult(success: false, error: error ?? message, message: message);
}

// ── Service ───────────────────────────────────────────────────────────────────

class AuthService extends ChangeNotifier {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  AuthService._() {
    _api = GitHubApiClient.instance;
    _api.setAuthInvalidationHandler(_handleTokenInvalidation);
    _initialize();
  }

  late final GitHubApiClient _api;
  SharedPreferences? _prefs;

  AuthState _state = AuthState.initializing;
  GithubUser? _currentUser;
  String _accessToken = '';
  bool _handlingInvalidation = false;
  String _pendingLogoutMessage = '';

  // ── Getters ──────────────────────────────────────────────────────────────────

  AuthState get authState => _state;
  GithubUser? get currentUser => _currentUser;
  String get accessToken => _accessToken;
  bool get isLoggedIn =>
      _state == AuthState.loggedIn && _accessToken.isNotEmpty;

  /// Returns the pending logout reason and clears it (one-time read).
  String consumeLogoutMessage() {
    final msg = _pendingLogoutMessage;
    _pendingLogoutMessage = '';
    return msg;
  }

  // ── Initialization ────────────────────────────────────────────────────────────

  Future<void> _initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _restoreAuthState();
    } catch (e) {
      debugPrint('AuthService init failed: $e');
      _setState(AuthState.loggedOut);
    }
  }

  Future<void> _restoreAuthState() async {
    final token = _prefs?.getString(Constants.storageAccessToken) ?? '';
    final userJson = _prefs?.getString(Constants.storageUserInfo) ?? '';

    if (token.isNotEmpty && userJson.isNotEmpty) {
      try {
        _accessToken = token;
        _currentUser = GithubUser.fromJson(
            jsonDecode(userJson) as Map<String, dynamic>);
        _api.setAccessToken(_accessToken);
        _setState(AuthState.loggedIn, user: _currentUser);
      } catch (e) {
        debugPrint('Restore auth state failed: $e');
        await logout();
      }
    } else {
      _setState(AuthState.loggedOut);
    }
  }

  // ── State helpers ─────────────────────────────────────────────────────────────

  void _setState(AuthState state, {GithubUser? user}) {
    _state = state;
    if (user != null) _currentUser = user;
    notifyListeners();
  }

  // ── Persistence ───────────────────────────────────────────────────────────────

  Future<void> _saveAuthInfo(String token, GithubUser user) async {
    await _prefs?.setString(Constants.storageAccessToken, token);
    await _prefs?.setString(
        Constants.storageUserInfo, jsonEncode(user.toJson()));
  }

  Future<void> _clearAuthInfo() async {
    await _prefs?.remove(Constants.storageAccessToken);
    await _prefs?.remove(Constants.storageUserInfo);
  }

  // ── Token invalidation ────────────────────────────────────────────────────────

  Future<void> _handleTokenInvalidation(String message) async {
    if (_handlingInvalidation || _state != AuthState.loggedIn) return;
    _handlingInvalidation = true;
    _pendingLogoutMessage = message;
    try {
      await logout();
    } finally {
      _handlingInvalidation = false;
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────────

  /// Builds the GitHub OAuth URL to open in the WebView.
  String getGitHubOAuthUrl() => Constants.buildGitHubOAuthUrl();

  /// Handles the OAuth callback URL returned from the WebView.
  Future<AuthResult> handleGitHubCallback(String callbackUrl) async {
    if (!Constants.isValidGitHubCallback(callbackUrl)) {
      return AuthResult.fail('无效的回调URL');
    }

    final params = Constants.extractAuthCallbackParams(callbackUrl);
    final code = params['code'];
    final error = params['error'];

    if (error != null) {
      return AuthResult.fail('用户取消授权或授权失败', error: error);
    }
    if (code == null || code.isEmpty) {
      return AuthResult.fail('未收到授权码');
    }

    _setState(AuthState.loggingIn);

    final tokenResult = await _api.exchangeCodeForToken(code);
    if (!tokenResult.success) {
      _setState(AuthState.error);
      return AuthResult.fail(tokenResult.message ?? '令牌交换失败',
          error: tokenResult.error);
    }

    return _completeLogin(tokenResult.data!);
  }

  /// Login with a Personal Access Token (PAT).
  Future<AuthResult> loginWithToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return AuthResult.fail('请输入有效的访问令牌');

    _setState(AuthState.loggingIn);
    return _completeLogin(trimmed);
  }

  Future<AuthResult> _completeLogin(String token) async {
    _accessToken = token;
    _api.setAccessToken(token);

    final userResult = await _api.getCurrentUser();
    if (!userResult.isSuccess) {
      _accessToken = '';
      _api.setAccessToken('');
      _setState(AuthState.error);
      return AuthResult.fail('获取用户信息失败', error: userResult.error);
    }

    final user = userResult.data!;
    _currentUser = user;
    await _saveAuthInfo(token, user);
    _setState(AuthState.loggedIn, user: user);
    return AuthResult.ok(user);
  }

  /// Refresh current user profile from the API and persist locally.
  Future<void> refreshCurrentUser() async {
    try {
      final result = await _api.getCurrentUser();
      if (result.isSuccess) {
        _currentUser = result.data!;
        await _saveAuthInfo(_accessToken, _currentUser!);
        _setState(AuthState.loggedIn, user: _currentUser);
      }
    } catch (e) {
      debugPrint('refreshCurrentUser failed: $e');
    }
  }

  /// Logout and clear all persisted auth info.
  Future<void> logout() async {
    _accessToken = '';
    _currentUser = null;
    _api.setAccessToken('');
    await _api.clearAllCaches();
    await _clearAuthInfo();
    _setState(AuthState.loggedOut);
  }
}
