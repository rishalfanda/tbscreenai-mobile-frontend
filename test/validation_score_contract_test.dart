import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/data/sync/validation_score_contract.dart';

Map<String, dynamic> contract() => {
  'paths': {
    '/api/v1/diagnoses/{diagnosis_id}/status': {
      'patch': {
        'requestBody': {
          'content': {
            'application/json': {
              'schema': {
                r'$ref': '#/components/schemas/DiagnosisValidationPatch',
              },
            },
          },
        },
        'responses': {
          '200': {
            'content': {
              'application/json': {
                'schema': {r'$ref': '#/components/schemas/DiagnosisOut'},
              },
            },
          },
        },
      },
    },
  },
  'components': {
    'schemas': {
      'DiagnosisValidationPatch': {
        'allOf': [
          {r'$ref': '#/components/schemas/Review'},
          {
            'properties': {'base_version': {}},
          },
        ],
      },
      'Review': {
        'properties': {
          'status': {},
          'validation_score': {},
          'validated_at': {},
        },
      },
      'DiagnosisOut': {
        'properties': {
          'validation_score': {},
          'validated_at': {},
          'validated_by': {},
        },
      },
    },
  },
};

void main() {
  test('accepts deployed patch reference and composed inherited fields', () {
    expect(hasValidationScoreContract(contract()), isTrue);
  });
  test('unused score schema cannot authorize sending to an old endpoint', () {
    final doc = contract();
    final schemas = (doc['components'] as Map)['schemas'] as Map;
    schemas['OldBody'] = {
      'properties': {'status': {}},
    };
    final patch = ((doc['paths'] as Map).values.single as Map)['patch'] as Map;
    patch['requestBody'] = {
      'content': {
        'application/json': {
          'schema': {r'$ref': '#/components/schemas/OldBody'},
        },
      },
    };
    expect(hasValidationScoreContract(doc), isFalse);
  });
  test('missing read-back fields and recursive references fail closed', () {
    final doc = contract();
    final schemas = (doc['components'] as Map)['schemas'] as Map;
    schemas['DiagnosisOut'] = {
      'properties': {'status': {}},
    };
    expect(hasValidationScoreContract(doc), isFalse);
    schemas['DiagnosisValidationPatch'] = {
      r'$ref': '#/components/schemas/DiagnosisValidationPatch',
    };
    expect(hasValidationScoreContract(doc), isFalse);
  });
}
