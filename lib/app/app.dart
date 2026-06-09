import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/app/router/app_router.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/config/scroll_behavior.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/diagnosis_provider.dart';
import 'package:myapp/state/dashboard_provider.dart';

class TBScreenApp extends StatelessWidget {
  const TBScreenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DiagnosisProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: Builder(
        builder: (context) {
          final authProvider = context.watch<AuthProvider>();
          final router = AppRouter.create(authProvider);

          return MaterialApp.router(
            title: 'TBScreen',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: router,
            scrollBehavior: AppScrollBehavior(),
          );
        },
      ),
    );
  }
}
