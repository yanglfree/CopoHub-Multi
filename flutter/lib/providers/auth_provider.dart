import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

// ── AuthService provider ──────────────────────────────────────────────────────

/// Single instance of [AuthService] shared across the app.
final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  return AuthService.instance;
});

// ── Derived state providers ───────────────────────────────────────────────────

/// Current [AuthState] – drives root-level routing (splash / login / home).
final authStateProvider = Provider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authState;
});

/// Current authenticated user, or null when logged out.
final currentUserProvider = Provider<GithubUser?>((ref) {
  return ref.watch(authServiceProvider).currentUser;
});

/// Whether the user is currently logged in.
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authServiceProvider).isLoggedIn;
});
