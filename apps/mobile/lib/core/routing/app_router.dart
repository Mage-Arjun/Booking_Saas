import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_home.dart';
import '../../features/auth/application/auth_session.dart';
import '../../features/auth/data/models/user.dart';
import '../../features/auth/presentation/auth_screens.dart';
import '../../features/client/presentation/client_home.dart';
import '../../features/provider/presentation/provider_home.dart';

/// Central application navigation configuration.
///
/// Authentication and role redirects live here rather than in individual
/// screens. This prevents protected screens from accidentally becoming
/// reachable through an unguarded route.
class AppRouter {
  const AppRouter._();

  static GoRouter createRouter(AuthSessionController session) {
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: session,
      redirect: (context, state) {
        final path = state.uri.path;
        final publicRoute = path == '/login' || path == '/register';

        if (session.status == AuthStatus.unknown) return '/splash';

        if (!session.isAuthenticated) {
          return publicRoute ? null : '/login';
        }

        final role = session.user?.role;
        if (path == '/splash' || publicRoute) {
          return switch (role) {
            UserRole.client => '/client',
            UserRole.provider => '/provider',
            UserRole.admin => '/admin',
            null => '/login',
          };
        }

        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
        GoRoute(path: '/client', builder: (_, _) => const ClientHomeScreen()),
        GoRoute(path: '/provider', builder: (_, _) => const ProviderHomeScreen()),
        GoRoute(path: '/admin', builder: (_, _) => const AdminHomeScreen()),
      ],
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Loading your workspace…'),
            ],
          ),
        ),
      );
}
