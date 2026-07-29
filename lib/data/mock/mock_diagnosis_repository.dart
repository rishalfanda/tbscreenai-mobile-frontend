import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:myapp/data/mock/mock_seed_data.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/repositories/diagnosis_repository.dart';

/// Mock AI inference — identical simulation to the old DiagnosisProvider:
/// 3s delay, randomized confidence/findings.
class MockDiagnosisRepository implements DiagnosisRepository {
  final math.Random _random = math.Random();

  @override
  Future<List<String>> getSymptomOptions() =>
      SynchronousFuture(List.unmodifiable(MockSeedData.symptomOptions));

  @override
  Future<DiagnosisOutcome> runInference({required String imageLabel}) async {
    // AI simulation per CLAUDE.md: Future.delayed(Duration(seconds: 3)).
    await Future<void>.delayed(const Duration(seconds: 3));

    final confidence = 75 + _random.nextInt(24);
    final isPositive = _random.nextBool();
    final processingMs = 2600 + _random.nextInt(500);

    return DiagnosisOutcome(
      isPositive: isPositive,
      confidence: confidence,
      processingTime: '${(processingMs / 1000).toStringAsFixed(1)}s',
      modelVersion: 'TBScreen v2.1.0',
      createdAt: DateTime.now(),
      consolidation: isPositive ? (20 + _random.nextDouble() * 15) : (1 + _random.nextDouble() * 4),
      cavity: isPositive ? (_random.nextDouble() * 5) : 0.0,
      effusion: isPositive ? (3 + _random.nextDouble() * 8) : (_random.nextDouble() * 2),
      fibrotic: _random.nextDouble() * 2,
      calcification: _random.nextDouble() * 3,
    );
  }
}
