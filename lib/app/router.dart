import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';
import '../screens/heatmap_screen.dart';
import '../screens/login_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/workout_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/today',
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      if (isLoading) return null;
      final isLoggedIn = authState.valueOrNull != null;
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
            pageBuilder: (_, __) => const NoTransitionPage(child: HeatmapScreen()),
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
