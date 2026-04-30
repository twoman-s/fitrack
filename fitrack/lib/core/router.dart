import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/main_scaffold.dart';
import '../screens/home_dashboard.dart';
import '../screens/add_weight_screen.dart';
import '../screens/progress_graph_screen.dart';
import '../screens/photo_progress_screen.dart';
import '../screens/upload_photo_screen.dart';
import '../screens/compare_progress_screen.dart';
import '../screens/heatmap_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/weight_history_screen.dart';
import '../models/weight.dart';
import '../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggingIn = state.uri.path == '/login' || state.uri.path == '/signup';
      final isSplash = state.uri.path == '/';

      if (authState == AppAuthState.initializing) {
        return isSplash ? null : '/';
      }

      if (authState == AppAuthState.unauthenticated) {
        if (!isLoggingIn) return '/login';
      }

      if (authState == AppAuthState.authenticated) {
        if (isLoggingIn || isSplash) return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      // ShellRoute for bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeDashboard(),
          ),
          GoRoute(
            path: '/progress',
            builder: (context, state) => const ProgressGraphScreen(),
          ),
          GoRoute(
            path: '/photos',
            builder: (context, state) => const PhotoProgressScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      // Full screen routes
      GoRoute(
        path: '/add-weight',
        builder: (context, state) {
          final entry = state.extra as WeightEntry?;
          return AddWeightScreen(entry: entry);
        },
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const WeightHistoryScreen(),
      ),
      GoRoute(
        path: '/upload-photo',
        builder: (context, state) => const UploadPhotoScreen(),
      ),
      GoRoute(
        path: '/compare',
        builder: (context, state) => const CompareProgressScreen(),
      ),
      GoRoute(
        path: '/heatmap',
        builder: (context, state) => const HeatmapScreen(),
      ),
    ],
  );
});
