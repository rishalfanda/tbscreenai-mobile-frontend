import 'package:flutter/material.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_palette.dart';

class NoModelBanner extends StatelessWidget {
  const NoModelBanner({super.key, required this.onGoToSync});

  final VoidCallback onGoToSync;

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
                child: Text(
                  'Model AI belum terpasang di perangkat ini. Unduh model dari '
                  'Pusat Sinkronisasi sebelum menjalankan analisis.',
                  style: TextStyle(color: diagnosisText, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onGoToSync,
              style: TextButton.styleFrom(foregroundColor: diagnosisAccent),
              child: const Text('Buka Pusat Sinkronisasi'),
            ),
          ),
        ],
      ),
    );
  }
}

