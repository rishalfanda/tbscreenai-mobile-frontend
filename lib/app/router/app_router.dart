import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/features/account/presentation/account_screen.dart';
import 'package:myapp/features/auth/presentation/login_screen.dart';
import 'package:myapp/features/camera/presentation/camera_screen.dart';
import 'package:myapp/features/dashboard/presentation/dashboard_screen.dart';
import 'package:myapp/features/dataset/presentation/dataset_screen.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_screen.dart';
import 'package:myapp/features/patients/presentation/patients_screen.dart';
import 'package:myapp/features/result/presentation/result_screen.dart';
import 'package:myapp/features/validation/presentation/validation_screen.dart';
import 'package:myapp/features/shared/presentation/app_shell.dart';
import 'package:myapp/state/auth_provider.dart';

class AppRouter {
  static GoRouter create(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/login',
      refreshListenable: authProvider,
      redirect: (BuildContext context, GoRouterState state) {
        final isLoggedIn = authProvider.isLoggedIn;
        final isLoggingIn = state.matchedLocation == '/login';

        if (!isLoggedIn && !isLoggingIn) {
          return '/login';
        }

        if (isLoggedIn && isLoggingIn) {
          return '/dashboard';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) {
            return AppShell(location: state.uri.toString(), child: child);
          },
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/patients',
              builder: (context, state) => const PatientsScreen(),
            ),
            GoRoute(
              path: '/diagnosis',
              builder: (context, state) => const DiagnosisScreen(),
            ),
            GoRoute(
              path: '/validation',
              builder: (context, state) => const ValidationScreen(),
            ),
            GoRoute(
              path: '/dataset',
              builder: (context, state) => const DatasetScreen(),
            ),
            GoRoute(
              path: '/account',
              builder: (context, state) => const AccountScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/camera',
          builder: (context, state) => const CameraScreen(),
        ),
        GoRoute(
          path: '/result',
          builder: (context, state) => const ResultScreen(),
        ),
      ],
    );
  }
}
