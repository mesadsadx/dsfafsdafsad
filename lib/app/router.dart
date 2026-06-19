import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';
import '../screens/heatmap_screen.dart';
import '../screens/login_screen.dart';
import '../screens/progression_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/workout_screen.dart';

/// Owns the current user so redirect never races with authStateProvider.
class _AuthRefreshNotifier extends ChangeNotifier {
  User? _user;
  bool _ready = false;

  _AuthRefreshNotifier(Stream<User?> stream) {
    _sub = stream.listen((user) {
      _user = user;
      _ready = true;
      notifyListeners();
    });
  }

  bool get ready => _ready;
  bool get isLoggedIn => _user != null;

  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.read(authServiceProvider);
  final notifier = _AuthRefreshNotifier(authService.authStateChanges);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/today',
    refreshListenable: notifier,
    redirect: (context, state) {
      if (!notifier.ready) return null;
      final isLoggedIn = notifier.isLoggedIn;
      if (!isLoggedIn && state.matchedLocation != '/login') return '/login';
      if (isLoggedIn && state.matchedLocation == '/login') return '/today';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: '/today',
            pageBuilder: (_, __) => const NoTransitionPage(child: WorkoutScreen()),
          ),
          GoRoute(
            path: '/activity',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: HeatmapScreen()),
          ),
          GoRoute(
            path: '/progression',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ProgressionScreen()),
          ),
          GoRoute(
            path: '/workout/:date',
            builder: (_, state) =>
                WorkoutScreen(date: state.pathParameters['date']),
          ),
        ],
      ),
    ],
  );
});
