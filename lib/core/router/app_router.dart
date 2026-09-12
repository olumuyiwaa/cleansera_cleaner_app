import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/jobs/presentation/job_detail_screen.dart';
import '../../features/jobs/presentation/jobs_list_screen.dart';
import '../../features/profile/presentation/availability_screen.dart';
import '../../features/profile/presentation/documents_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/splash_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final status = auth.status;
      final loggingIn = state.matchedLocation == '/login';

      if (status == AuthStatus.unknown) return null;

      if (status == AuthStatus.unauthenticated) {
        return loggingIn ? null : '/login';
      }

      if (loggingIn || state.matchedLocation == '/') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeShell(),
        routes: [
          GoRoute(
            path: 'jobs',
            builder: (_, __) => const JobsListScreen(),
          ),
          GoRoute(
            path: 'jobs/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return JobDetailScreen(jobId: id);
            },
          ),
          GoRoute(
            path: 'profile',
            builder: (_, __) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'availability',
                builder: (_, __) => const AvailabilityScreen(),
              ),
              GoRoute(
                path: 'documents',
                builder: (_, __) => const DocumentsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Lightweight listenable so GoRouter rebuilds on auth changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
