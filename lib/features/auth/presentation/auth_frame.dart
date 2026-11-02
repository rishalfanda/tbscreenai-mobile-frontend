import 'package:myapp/features/shared/presentation/widgets/connection_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/core/localization/language_toggle.dart';

class AuthFrame extends StatelessWidget {
  const AuthFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.background,
    body: SafeArea(
      child: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: LayoutBuilder(
                          builder: (context, size) {
                            final branding = Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/favicon.png',
                                  width: 80,
                                  height: 80,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'TBScreen.AI',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  context.trRead(
                                    'Skrining TB berbasis AI pada perangkat Anda.',
                                    'AI-assisted TB screening on your device.',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                            if (size.maxWidth < 640) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  branding,
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Divider(),
                                  ),
                                  child,
                                ],
                              );
                            }
                            return IntrinsicHeight(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: branding,
                                    ),
                                  ),
                                  const VerticalDivider(width: 48),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 32,
                                      ),
                                      child: child,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '© ${DateTime.now().year} TBScreen.AI',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const Positioned(top: 16, left: 24, child: ConnectionStatusBadge()),
          const Positioned(top: 16, right: 24, child: LanguageToggle()),
        ],
      ),
    ),
  );
}
