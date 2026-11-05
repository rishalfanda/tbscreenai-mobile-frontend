import 'package:myapp/domain/models/dataset.dart';
import 'package:myapp/domain/models/dataset_page.dart';

abstract interface class DatasetReadRepository {
  Future<DatasetPage<DatasetEntry>> list({String query = '', int offset = 0});
  Future<DatasetEntry> detail(String id);
  Future<DatasetPage<DatasetScreening>> items(String id, {int offset = 0});
}

abstract interface class DatasetWriteRepository {
  Future<DatasetEntry> create({required String name, String? description});
  Future<DatasetEntry> update(String id, Map<String, Object?> changes);
  Future<void> delete(String id);
  Future<void> addItems(String id, List<String> diagnosisIds);
  Future<void> removeItem(String id, String diagnosisId);
}

/// Contract for training-dataset management.
abstract class DatasetRepository {
  Future<List<DatasetModel>> getDatasets();

  Future<List<DatasetRecord>> getRecords();
}
