import 'package:myapp/domain/models/dataset.dart';

/// Contract for training-dataset management.
abstract class DatasetRepository {
  Future<List<DatasetModel>> getDatasets();

  Future<List<DatasetRecord>> getRecords();
}
