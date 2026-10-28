import 'package:myapp/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'result_theme.dart';

/// Shown while this tab has no outcome to render. Reachable in practice
/// only as an inert, off-screen `TabBarView` child — [DiagnosisScreen] keeps
/// this tab disabled until a real analysis exists — so it deliberately
/// carries no fabricated clinical numbers, unlike the old standalone
/// `/result` route's demo placeholder.
class EmptyResultState extends StatelessWidget {
  const EmptyResultState({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kResultBgColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 56,
                color: kResultTextLoColor,
              ),
              SizedBox(height: 16),
              AppText(
                'Belum ada hasil analisis.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kResultTextHiColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              AppText(
                'Lengkapi data pasien dan jalankan analisis pada tab Input Data.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kResultTextLoColor,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
