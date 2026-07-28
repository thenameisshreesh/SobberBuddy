import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import '../core/constants/theme.dart';
import '../guards/user_type_guard.dart';
import '../models/trip_model.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/dashboard/trip_completion_screen.dart';
import '../screens/dashboard/trip_screen.dart';
import '../screens/history/earnings_screen.dart';
import '../screens/history/rating_history_screen.dart';
import '../screens/history/trip_details_screen.dart';
import '../screens/history/trip_history_screen.dart';
import '../screens/onboarding/document_upload_screen.dart';
import '../screens/profile/help_screen.dart';
import '../screens/profile/report_issue_screen.dart';
import '../screens/profile/safety_guidelines_screen.dart';
import '../screens/profile/profile_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/drive',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isLoading = authProvider.loading;
      final isLoggedIn = authProvider.isAuthenticated;
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/signup') ||
          state.matchedLocation.startsWith('/forgot-password');

      if (isLoading) return null;
      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/drive';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => UserTypeGuard(
          child: MainShell(child: child),
        ),
        routes: [
          GoRoute(
            path: '/drive',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/earnings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: EarningsScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/trip',
        builder: (context, state) {
          final trip = state.extra as TripModel;
          return TripScreen(trip: trip);
        },
      ),
      GoRoute(
        path: '/trip-completion',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return TripCompletionScreen(tripData: extra);
        },
      ),
      GoRoute(
        path: '/trip-history',
        builder: (context, state) => const TripHistoryScreen(),
      ),
      GoRoute(
        path: '/trip-details/:tripId',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId']!;
          return TripDetailsScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: '/rating-history',
        builder: (context, state) => const RatingHistoryScreen(),
      ),
      GoRoute(
        path: '/onboarding/documents',
        builder: (context, state) => const DocumentUploadScreen(),
      ),
      GoRoute(
        path: '/report-issue',
        builder: (context, state) => const ReportIssueScreen(),
      ),
      GoRoute(
        path: '/safety-guidelines',
        builder: (context, state) => const SafetyGuidelinesScreen(),
      ),
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpScreen(),
      ),
    ],
  );
}

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/earnings')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        height: 80,
        backgroundColor: AppColors.surface,
        indicatorColor: Colors.transparent,
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/drive');
            case 1:
              context.go('/earnings');
            case 2:
              context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Ionicons.car_outline),
            selectedIcon: Icon(Ionicons.car, color: AppColors.primary),
            label: 'Drive',
          ),
          NavigationDestination(
            icon: Icon(Ionicons.wallet_outline),
            selectedIcon: Icon(Ionicons.wallet, color: AppColors.primary),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Ionicons.person_outline),
            selectedIcon: Icon(Ionicons.person, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
