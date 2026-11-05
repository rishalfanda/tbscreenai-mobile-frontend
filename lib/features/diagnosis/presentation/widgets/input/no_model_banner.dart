import 'package:myapp/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_palette.dart';

class NoModelBanner extends StatelessWidget {
  const NoModelBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        border: Border.all(color: diagnosisAccent),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: diagnosisAccent),
              const SizedBox(width: 10),
              const Expanded(
                child: AppText(
                  'Model AI belum terpasang di perangkat ini. Hubungi teknisi '
                  'instansi untuk memasang model sebelum menjalankan analisis.',
                  style: TextStyle(color: diagnosisText, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
