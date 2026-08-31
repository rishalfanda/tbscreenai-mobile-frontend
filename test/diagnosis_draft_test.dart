import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/data/mock/mock_diagnosis_repository.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/state/diagnosis_provider.dart';

void main() {
  group('DiagnosisProvider draft', () {
    test('keeps every form change in one draft and resets it completely', () {
      final provider = DiagnosisProvider(MockDiagnosisRepository())
        ..updatePatientName('Risha')
        ..updateGender('Male')
        ..updateAge(17)
        ..updateHeight(172)
        ..updateWeight(68)
        ..toggleSymptom('Cough', true)
        ..updatePediatricScore(7)
        ..updateComorbidity('None')
        ..attachPlaceholderImage('xray.png');

      expect(provider.draft.patientName, 'Risha');
      expect(provider.draft.gender, 'Male');
      expect(provider.draft.symptoms, contains('Cough'));
      expect(provider.requiresPediatricScore, isTrue);
      expect(provider.draft.pediatricScore, 7);
      expect(provider.canAnalyze, isTrue);

      provider.resetForNewDiagnosis();

      expect(provider.draft.patientName, isEmpty);
      expect(provider.draft.gender, isNull);
      expect(provider.draft.symptoms, isEmpty);
      expect(provider.draft.image, isNull);
      expect(provider.draft.pediatricScore, isNull);
      expect(provider.lastOutcome, isNull);
    });

    test('clears pediatric score when age changes to adult', () {
      final provider = DiagnosisProvider(MockDiagnosisRepository())
        ..updateAge(12)
        ..updatePediatricScore(8);

      provider.updateAge(18);

      expect(provider.requiresPediatricScore, isFalse);
      expect(provider.pediatricScore, isNull);
    });
  });

  group('XrayImage validation', () {
    test('rejects extension spoofing and validates from bytes', () {
      expect(
        () => XrayImage.fromBytes(
          bytes: Uint8List.fromList('not an image'.codeUnits),
          filename: 'fake.png',
          source: XrayImageSource.gallery,
        ),
        throwsA(isA<XrayImageValidationException>()),
      );
    });

    test('records format, source, size and checksum', () {
      final image = XrayImage.placeholder('scan.png');

      expect(image.format, XrayImageFormat.png);
      expect(image.source, XrayImageSource.demo);
      expect(image.mimeType, 'image/png');
      expect(image.sizeBytes, greaterThan(0));
      expect(image.checksumSha256, hasLength(64));
    });

    test('recognises DICOM from its Part-10 signature', () {
      final bytes = Uint8List(132)
        ..setRange(128, 132, const [0x44, 0x49, 0x43, 0x4d]);

      final image = XrayImage.fromBytes(
        bytes: bytes,
        filename: 'study.dcm',
        source: XrayImageSource.gallery,
      );

      expect(image.format, XrayImageFormat.dicom);
      expect(image.canPreview, isFalse);
      expect(image.mimeType, 'application/dicom');
    });
  });
}
