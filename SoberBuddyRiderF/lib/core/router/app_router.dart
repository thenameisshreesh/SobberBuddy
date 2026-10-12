import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/booking/presentation/booking_confirmation_screen.dart';
import '../../features/booking/presentation/booking_screen.dart';
import '../../features/booking/presentation/home_screen.dart';
import '../../features/booking/presentation/qr_scanner_screen.dart';
import '../../features/booking/presentation/terms_conditions_screen.dart';
import '../../features/support/presentation/support_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/payment/presentation/payment_summary_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/trip/presentation/trip_details_screen.dart';
import '../constants/app_theme.dart';
import 'shell_tab_notifier.dart';

/// Reads route [extra] params passed as a [Map].
T? routeExtra<T>(GoRouterState state, String key) {
  final extra = state.extra;
  if (extra is Map<String, dynamic>) {
    return extra[key] as T?;
  }
  return null;
}

Map<String, dynamic> routeExtraMap(GoRouterState state) {
  final extra = state.extra;
  if (extra is Map<String, dynamic>) {
    return extra;
  }
  return const {};
}

final splashReadyProvider = FutureProvider<bool>((ref) async {
  await Future<void>.delayed(const Duration(seconds: 2));
  return true;
});

final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  final splashReady = ref.watch(splashReadyProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final splashLoading = splashReady.isLoading;
      final authLoading = auth.loading;

      if (splashLoading || authLoading) {
        return location == '/splash' ? null : '/splash';
      }

      final isLoggedIn = auth.isAuthenticated;
      final isAuthRoute = _authRoutes.contains(location);

      if (!isLoggedIn) {
        if (isAuthRoute || location == '/splash') {
          return location == '/splash' ? '/login' : null;
        }
        return '/login';
      }

      if (isLoggedIn && (location == '/splash' || isAuthRoute)) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
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
        builder: (context, state, child) => _MainShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/history',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HistoryScreen(),
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
        path: '/booking-confirmation',
        builder: buildBookingConfirmationScreen,
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: '/qr-scan',
        builder: (context, state) => const QrScannerScreen(),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) => const TermsConditionsScreen(),
      ),
      GoRoute(
        path: '/booking',
        builder: buildBookingScreen,
      ),
      GoRoute(
        path: '/trip-details',
        builder: (context, state) {
          final extra = routeExtraMap(state);
          return TripDetailsScreen(
            tripId: extra['tripId'] as String? ?? '',
            driver: (extra['driver'] as Map<String, dynamic>?) ?? const {},
            tripData: (extra['tripData'] as Map<String, dynamic>?) ?? const {},
          );
        },
      ),
      GoRoute(
        path: '/payment-summary',
        builder: (context, state) {
          final extra = routeExtraMap(state);
          return PaymentSummaryScreen(
            tripData: (extra['tripData'] as Map<String, dynamic>?) ?? const {},
            driver: (extra['driver'] as Map<String, dynamic>?) ?? const {},
          );
        },
      ),
    ],
  );
});

const _authRoutes = {'/login', '/signup', '/forgot-password'};

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/splash-logo.png',
              width: 280,
              height: 280,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: AppSpacing.xl),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _MainShell extends ConsumerStatefulWidget {
  const _MainShell({required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  String? _lastNotifiedLocation;

  int _selectedIndex() {
    if (widget.location.startsWith('/history')) return 1;
    if (widget.location.startsWith('/profile')) return 2;
    return 0;
  }

  void _notifyTabActivation(String location) {
    if (_lastNotifiedLocation == location) return;
    _lastNotifiedLocation = location;
    ref.read(shellTabNotifierProvider.notifier).activateTab(location);
  }

  void _onTap(int index) {
    final target = switch (index) {
      0 => '/home',
      1 => '/history',
      2 => '/profile',
      _ => '/home',
    };

    if (widget.location == target) {
      ref.read(shellTabNotifierProvider.notifier).activateTab(target);
    }

    context.go(target);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyTabActivation(widget.location);
    });
  }

  @override
  void didUpdateWidget(covariant _MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyTabActivation(widget.location);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex(),
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Book Ride',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            activeIcon: Icon(Icons.history),
            label: 'My Trips',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'My Profile',
          ),
        ],
      ),
    );
  }
}
