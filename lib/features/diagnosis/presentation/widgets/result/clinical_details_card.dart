import 'package:myapp/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/domain/models/diagnosis_draft.dart';
import 'result_theme.dart';

/// Card E: Detail Klinis (Hide/Unhide ExpansionTile).
class ClinicalDetailsCard extends StatelessWidget {
  const ClinicalDetailsCard({super.key, required this.snapshot});

  final DiagnosisDraft snapshot;

  @override
  Widget build(BuildContext context) {
    return DarkCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const Key('clinical-details-expansion-panel'),
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: kResultTextHiColor,
          collapsedIconColor: kResultTextLoColor,
          textColor: kResultTextHiColor,
          collapsedTextColor: kResultTextHiColor,
          leading: const Icon(
            Icons.description_outlined,
            color: kResultTextLoColor,
            size: 20,
          ),
          title: const AppText(
            'Detail Klinis (Hide/Unhide)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: const AppText(
            'Gejala, komorbiditas, dan riwayat klinis pasien',
            style: TextStyle(fontSize: 11, color: kResultTextLoColor),
          ),
          children: [
            if (snapshot.symptoms.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: snapshot.symptoms
                    .map(
                      (s) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: AppText(
                          kSymptomLabels[s] ?? s,
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            Table(
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(),
              },
              children: [
                _clinicalRow(
                  'Komorbiditas',
                  snapshot.comorbidity ?? 'Tidak diisi',
                ),
                _clinicalRow(
                  'Status Merokok',
                  snapshot.smoking ?? 'Tidak diisi',
                ),
                _clinicalRow('Kontak TB', snapshot.tbContact ?? 'Tidak diisi'),
                _clinicalRow('Dahak (BTA)', snapshot.bta ?? 'Tidak diisi'),
                _clinicalRow('Kultur', snapshot.culture ?? 'Tidak diisi'),
                _clinicalRow('Xpert MTB/Rif', snapshot.xpert ?? 'Tidak diisi'),
                _clinicalRow('IGRA', snapshot.igra ?? 'Tidak diisi'),
                _clinicalRow('Riwayat TB', snapshot.tbHistory ?? 'Tidak diisi'),
                _clinicalRow('Status TB', snapshot.tbStatus ?? 'Tidak diisi'),
                _clinicalRow(
                  'Keberadaan Jendela',
                  snapshot.windowsPresence ?? 'Tidak diisi',
                ),
                _clinicalRow(
                  'Paparan Sinar Matahari',
                  snapshot.sunlightExposure ?? 'Tidak diisi',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static TableRow _clinicalRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AppText(
            label,
            style: const TextStyle(fontSize: 12, color: kResultTextLoColor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AppText(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kResultTextHiColor,
            ),
          ),
        ),
      ],
    );
  }
}
