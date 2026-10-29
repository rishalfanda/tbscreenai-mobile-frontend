import 'package:myapp/domain/models/dataset.dart';
import 'package:myapp/domain/models/dataset_page.dart';

abstract interface class DatasetReadRepository {
  Future<DatasetPage<DatasetEntry>> list({String query = '', int offset = 0});
  Future<DatasetEntry> detail(String id);
  Future<DatasetPage<DatasetScreening>> items(String id, {int offset = 0});
}

/// Contract for training-dataset management.
abstract class DatasetRepository {
  Future<List<DatasetModel>> getDatasets();

  Future<List<DatasetRecord>> getRecords();
}
