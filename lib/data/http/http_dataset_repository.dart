import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/domain/models/dataset.dart';
import 'package:myapp/domain/models/dataset_page.dart';
import 'package:myapp/domain/repositories/dataset_repository.dart';

class HttpDatasetRepository
    implements DatasetRepository, DatasetReadRepository {
  HttpDatasetRepository(this._client);
  final ApiClient _client;
  static const pageSize = 20;

  @override
  Future<DatasetPage<DatasetEntry>> list({
    String query = '',
    int offset = 0,
  }) async {
    final response = await _client.dio.get<Object?>(
      '/datasets',
      queryParameters: {
        'limit': pageSize,
        'offset': offset,
        if (query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    return _page(response.data, offset, _entry);
  }

  @override
  Future<DatasetEntry> detail(String id) async {
    final response = await _client.dio.get<Object?>(
      '/datasets/${Uri.encodeComponent(id)}',
    );
    final entry = _entry(response.data);
    if (entry.id != id) {
      throw const FormatException('Dataset identity mismatch');
    }
    return entry;
  }

  @override
  Future<DatasetPage<DatasetScreening>> items(
    String id, {
    int offset = 0,
  }) async {
    final response = await _client.dio.get<Object?>(
      '/datasets/${Uri.encodeComponent(id)}/items',
      queryParameters: {'limit': pageSize, 'offset': offset},
    );
    return _page(response.data, offset, (raw) {
      final value = _object(raw);
      final positive = value['is_positive'];
      final confidence = _count(value['confidence']);
      final status = _text(value['status']);
      if (positive is! bool ||
          confidence > 100 ||
          !const ['pending', 'agreed', 'disagreed'].contains(status)) {
        throw const FormatException('Dataset screening is invalid');
      }
      return DatasetScreening(
        diagnosisId: _text(value['diagnosis_id']),
        patientCode: _text(value['patient_code']),
        diagnosedAt: DateTime.parse(_text(value['diagnosed_at'])),
        isPositive: positive,
        confidence: confidence,
        status: status,
        modelVersion: _text(value['model_version']),
      );
    });
  }

  DatasetPage<T> _page<T>(
    Object? raw,
    int expectedOffset,
    T Function(Object?) parse,
  ) {
    final value = _object(raw);
    final entries = value['items'];
    final total = _count(value['total']);
    final limit = _count(value['limit']);
    final offset = _count(value['offset']);
    if (entries is! List ||
        limit != pageSize ||
        offset != expectedOffset ||
        entries.length > limit ||
        (entries.isNotEmpty && offset + entries.length > total) ||
        (entries.length < limit && offset + entries.length < total) ||
        (entries.isEmpty && offset < total)) {
      throw const FormatException('Dataset pagination is invalid');
    }
    return DatasetPage(
      items: List.unmodifiable(entries.map(parse)),
      total: total,
      limit: limit,
      offset: offset,
    );
  }

  DatasetEntry _entry(Object? raw) {
    final value = _object(raw);
    final status = _text(value['status']);
    final description = value['description'];
    if (!const ['active', 'archived'].contains(status) ||
        !value.containsKey('description') ||
        (description != null && description is! String)) {
      throw const FormatException('Dataset metadata is invalid');
    }
    return DatasetEntry(
      id: _text(value['id']),
      tenantId: _text(value['tenant_id']),
      name: _text(value['name']),
      description: description as String?,
      status: status,
      itemCount: _count(_object(value['counts'])['items']),
      sizeBytes: _count(value['size_bytes']),
      lastUpdated: DateTime.parse(_text(value['last_updated'])),
    );
  }

  Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Dataset object is invalid');
    }
    return value;
  }

  String _text(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Dataset text is invalid');
    }
    return value;
  }

  int _count(Object? value) {
    if (value is! int || value < 0) {
      throw const FormatException('Dataset count is invalid');
    }
    return value;
  }

  @override
  Future<List<DatasetModel>> getDatasets() async => (await list()).items
      .map(
        (entry) => DatasetModel(
          id: entry.id,
          name: entry.name,
          description: entry.description ?? '',
          totalImages: entry.itemCount,
          size: '${entry.sizeBytes} B',
          lastUpdated: entry.lastUpdated.toIso8601String(),
          status: entry.status.toUpperCase(),
          images: const [],
        ),
      )
      .toList(growable: false);
  @override
  Future<List<DatasetRecord>> getRecords() =>
      throw UnsupportedError('Read dataset-specific items instead');
}
