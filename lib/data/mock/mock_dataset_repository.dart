import 'package:flutter/foundation.dart';
import 'package:myapp/data/mock/mock_seed_data.dart';
import 'package:myapp/domain/models/dataset.dart';
import 'package:myapp/domain/repositories/dataset_repository.dart';

/// Mock datasets, returned synchronously (no loading flash).
class MockDatasetRepository implements DatasetRepository {
  @override
  Future<List<DatasetModel>> getDatasets() =>
      SynchronousFuture(List.unmodifiable(MockSeedData.datasets));

  @override
  Future<List<DatasetRecord>> getRecords() =>
      SynchronousFuture(List.unmodifiable(MockSeedData.datasetRecords));
}
