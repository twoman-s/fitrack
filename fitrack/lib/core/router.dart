import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/main_scaffold.dart';
import '../screens/home_dashboard.dart';
import '../screens/add_weight_screen.dart';
import '../screens/progress_graph_screen.dart';
import '../screens/photo_progress_screen.dart';
import '../screens/add_photos_screen.dart';
import '../screens/compare_progress_screen.dart';
import '../screens/heatmap_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/weight_history_screen.dart';
import '../screens/onboarding/onboarding_goal_screen.dart';
import '../screens/onboarding/onboarding_motivation_screen.dart';
import '../screens/goal_edit_screen.dart';
import '../screens/goals_list_screen.dart';
import '../models/weight.dart';
import '../models/goal.dart';
import '../providers/auth_provider.dart';
import '../providers/nav_state_provider.dart';

Page<dynamic> _buildPageWithTransition({
  required Widget child,
  required int index,
  required Ref ref,
}) {
  final navState = ref.read(navStateProvider);
  final isForward = index >= navState.current; 
  // Note: Since we update index BEFORE navigation in MainScaffold,
  // index will equal navState.current.
  // We compare index with previous to determine direction.
  final beginOffset = index > navState.previous 
      ? const Offset(1.0, 0.0) 
      : const Offset(-1.0, 0.0);

  return CustomTransitionPage(
    key: ValueKey('${index}_${navState.previous}'), // Force recreation on index change
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: beginOffset,
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        )),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

Page<dynamic> _buildBottomToTopPage({required Widget child}) {
  return CustomTransitionPage(
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        )),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 400),
  );
}

/// Bridges Riverpod auth state into a [ChangeNotifier] that GoRouter can
/// listen to via [GoRouter.refreshListenable]. This keeps the GoRouter
/// instance stable — it is never recreated on auth-state changes, which
/// means in-flight navigations (e.g. context.go after login) are not lost.
class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  AppAuthState _authState = AppAuthState.initializing;
  bool _showOnboarding = false;

  _RouterNotifier(this._ref) {
    _authState = _ref.read(authStateProvider);
    _showOnboarding = _ref.read(showOnboardingProvider);

    _ref.listen<AppAuthState>(authStateProvider, (_, next) {
      _authState = next;
      notifyListeners();
    });
    // Update silently — auth-state listener already triggers the redirect.
    _ref.listen<bool>(showOnboardingProvider, (_, next) {
      _showOnboarding = next;
    });
  }

  AppAuthState get authState => _authState;
  bool get showOnboarding => _showOnboarding;
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = notifier.authState;
      final isLoggingIn = state.uri.path == '/login' || state.uri.path == '/signup';
      final isSplash = state.uri.path == '/';

      if (authState == AppAuthState.initializing) {
        return isSplash ? null : '/';
      }

      if (authState == AppAuthState.unauthenticated) {
        if (!isLoggingIn) return '/login';
      }

      if (authState == AppAuthState.authenticated) {
        final isOnboarding = state.uri.path.startsWith('/onboarding');
        if ((isLoggingIn || isSplash) && !isOnboarding) {
          return notifier.showOnboarding ? '/onboarding' : '/home';
        }
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
            pageBuilder: (context, state) => _buildPageWithTransition(
              child: const HomeDashboard(),
              index: 0,
              ref: ref,
            ),
          ),
          GoRoute(
            path: '/progress',
            pageBuilder: (context, state) => _buildPageWithTransition(
              child: const ProgressGraphScreen(),
              index: 1,
              ref: ref,
            ),
          ),
          GoRoute(
            path: '/photos',
            pageBuilder: (context, state) => _buildPageWithTransition(
              child: const PhotoProgressScreen(),
              index: 2,
              ref: ref,
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => _buildPageWithTransition(
              child: const ProfileScreen(),
              index: 3,
              ref: ref,
            ),
          ),
        ],
      ),
      // Full screen routes
      GoRoute(
        path: '/add-weight',
        pageBuilder: (context, state) {
          final entry = state.extra as WeightEntry?;
          return _buildBottomToTopPage(child: AddWeightScreen(entry: entry));
        },
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const WeightHistoryScreen(),
      ),
      GoRoute(
        path: '/add-photos',
        pageBuilder: (context, state) {
          final date = state.extra as String? ??
              DateFormat('yyyy-MM-dd').format(DateTime.now());
          return _buildBottomToTopPage(child: AddPhotosScreen(date: date));
        },
      ),
      GoRoute(
        path: '/compare',
        builder: (context, state) => const CompareProgressScreen(),
      ),
      GoRoute(
        path: '/heatmap',
        builder: (context, state) => const HeatmapScreen(),
      ),

      // Onboarding
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingGoalScreen(),
      ),
      GoRoute(
        path: '/onboarding/motivation',
        builder: (context, state) {
          final goalType = (state.extra as String?) ?? 'LOSE';
          return OnboardingMotivationScreen(goalType: goalType);
        },
      ),

      // Goals
      GoRoute(
        path: '/goals',
        builder: (context, state) => const GoalsListScreen(),
      ),
      GoRoute(
        path: '/goal/new',
        builder: (context, state) => const GoalEditScreen(),
      ),
      GoRoute(
        path: '/goal/:id/edit',
        builder: (context, state) {
          final goal = state.extra as WeightGoal?;
          return GoalEditScreen(existingGoal: goal);
        },
      ),
    ],
  );
});
