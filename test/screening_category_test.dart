import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/domain/models/screening_category.dart';

void main() {
  group('ScreeningLevel classification', () {
    test('maps 0-20% to veryLow', () {
      expect(ScreeningLevel.fromScore(0), ScreeningLevel.veryLow);
      expect(ScreeningLevel.fromScore(10), ScreeningLevel.veryLow);
      expect(ScreeningLevel.fromScore(20), ScreeningLevel.veryLow);
      expect(ScreeningLevel.fromScore(-5), ScreeningLevel.veryLow);
    });

    test('maps 21-40% to low', () {
      expect(ScreeningLevel.fromScore(20.1), ScreeningLevel.low);
      expect(ScreeningLevel.fromScore(30), ScreeningLevel.low);
      expect(ScreeningLevel.fromScore(40), ScreeningLevel.low);
    });

    test('maps 41-60% to greyArea', () {
      expect(ScreeningLevel.fromScore(40.5), ScreeningLevel.greyArea);
      expect(ScreeningLevel.fromScore(50), ScreeningLevel.greyArea);
      expect(ScreeningLevel.fromScore(60), ScreeningLevel.greyArea);
    });

    test('maps 61-80% to high', () {
      expect(ScreeningLevel.fromScore(60.1), ScreeningLevel.high);
      expect(ScreeningLevel.fromScore(70), ScreeningLevel.high);
      expect(ScreeningLevel.fromScore(80), ScreeningLevel.high);
    });

    test('maps 81-100% to veryHigh', () {
      expect(ScreeningLevel.fromScore(80.1), ScreeningLevel.veryHigh);
      expect(ScreeningLevel.fromScore(90), ScreeningLevel.veryHigh);
      expect(ScreeningLevel.fromScore(100), ScreeningLevel.veryHigh);
      expect(ScreeningLevel.fromScore(150), ScreeningLevel.veryHigh);
    });
  });

  group('ScreeningLevel text information and terms', () {
    test('labels match specifications', () {
      expect(ScreeningLevel.veryLow.label, 'Very Low');
      expect(ScreeningLevel.low.label, 'Low');
      expect(ScreeningLevel.greyArea.label, 'Grey Area');
      expect(ScreeningLevel.high.label, 'High');
      expect(ScreeningLevel.veryHigh.label, 'Very High');
    });

    test('status labels use TB and Non-TB', () {
      expect(ScreeningLevel.veryLow.statusLabel, 'Non-TB');
      expect(ScreeningLevel.low.statusLabel, 'Non-TB');
      expect(ScreeningLevel.greyArea.statusLabel, 'Grey Area');
      expect(ScreeningLevel.high.statusLabel, 'TB');
      expect(ScreeningLevel.veryHigh.statusLabel, 'TB');
    });

    test('interpretations match result categories using TB', () {
      expect(
        ScreeningLevel.veryLow.interpretation,
        'Model memiliki keyakinan sangat rendah terhadap adanya indikasi TB.',
      );
      expect(
        ScreeningLevel.low.interpretation,
        'Kemungkinan TB rendah, namun belum dapat sepenuhnya dikesampingkan.',
      );
      expect(
        ScreeningLevel.greyArea.interpretation,
        'Model tidak dapat memberikan keputusan dengan keyakinan yang cukup.',
      );
      expect(
        ScreeningLevel.high.interpretation,
        'Model menunjukkan indikasi TB dengan keyakinan tinggi.',
      );
      expect(
        ScreeningLevel.veryHigh.interpretation,
        'Model menunjukkan indikasi TB dengan keyakinan sangat tinggi.',
      );
    });

    test('followUp next steps match clinical categories', () {
      expect(
        ScreeningLevel.veryLow.followUp,
        'Hasil skrining negatif. Tetap mempertimbangkan gejala klinis dan faktor risiko pasien.',
      );
      expect(
        ScreeningLevel.low.followUp,
        'Hasil skrining negatif. Pemeriksaan lanjutan bila terdapat gejala atau faktor risiko tinggi.',
      );
      expect(
        ScreeningLevel.greyArea.followUp,
        'Wajib dilakukan validasi tambahan oleh dokter, disertai evaluasi klinis dan pemeriksaan penunjang.',
      );
      expect(
        ScreeningLevel.high.followUp,
        'Hasil skrining positif. Perlu dilanjutkan dengan pemeriksaan lanjutan.',
      );
      expect(
        ScreeningLevel.veryHigh.followUp,
        'Hasil skrining positif. Perlu dilanjutkan dengan pemeriksaan lanjutan.',
      );
    });

    test('boolean indicators', () {
      expect(ScreeningLevel.veryLow.isPositive, isFalse);
      expect(ScreeningLevel.low.isPositive, isFalse);
      expect(ScreeningLevel.greyArea.isPositive, isFalse);
      expect(ScreeningLevel.high.isPositive, isTrue);
      expect(ScreeningLevel.veryHigh.isPositive, isTrue);

      expect(ScreeningLevel.veryLow.isGreyArea, isFalse);
      expect(ScreeningLevel.low.isGreyArea, isFalse);
      expect(ScreeningLevel.greyArea.isGreyArea, isTrue);
      expect(ScreeningLevel.high.isGreyArea, isFalse);
      expect(ScreeningLevel.veryHigh.isGreyArea, isFalse);
    });
  });
}

