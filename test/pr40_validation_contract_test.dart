import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/data/sync/validation_score_contract.dart';

void main() {
  test(
    'PR40 contract supports ratings/delete and blocks legacy score-only submissions',
    () {
      final doc =
          jsonDecode(
                File(
                  'test/fixtures/pr40_validation_openapi.json',
                ).readAsStringSync(),
              )
              as Map;
      expect(hasValidationScoreContract(doc, lesion: true), true);
      expect(hasValidationScoreContract(doc), false);
      final paths = doc['paths'] as Map;
      paths.removeWhere(
        (key, value) => (key as String).endsWith('/validation'),
      );
      expect(hasValidationScoreContract(doc, lesion: true), false);
      expect(hasValidationScoreContract({}), false);
    },
  );
}
