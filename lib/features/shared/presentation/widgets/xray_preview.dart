import 'package:flutter/material.dart';

import 'package:myapp/core/theme/app_theme.dart';

/// Sample chest X-ray used as the preview placeholder until real images are
/// stored per patient. Drop the file in and every preview picks it up.
const String kSampleXrayAsset = 'assets/images/xray_sample.png';

/// Chest X-ray preview panel shared by Patients, Result and Validation.
///
/// Falls back to a labelled dark panel when the asset is missing, so the app
/// never shows a broken image — and works before the file is added.
class XrayPreview extends StatelessWidget {
  const XrayPreview({
    super.key,
    this.label = 'Latest chest X-ray preview',
    this.borderRadius = AppTheme.cardRadius,
    this.overlay,
  });

  final String label;
  final double borderRadius;

  /// Optional badges/buttons drawn on top of the image (AI score, view toggle).
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(
        color: AppTheme.xrayBackdrop,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              kSampleXrayAsset,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.image_outlined,
                        size: 48, color: Colors.white24),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ),
            ?overlay,
          ],
        ),
      ),
    );
  }
}
