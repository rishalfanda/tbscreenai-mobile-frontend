class DatasetPage<T> {
  const DatasetPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });
  final List<T> items;
  final int total;
  final int limit;
  final int offset;
  bool get hasMore => offset + items.length < total;
}

class DatasetEntry {
  const DatasetEntry({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.description,
    required this.status,
    required this.itemCount,
    required this.sizeBytes,
    required this.lastUpdated,
  });
  final String id;
  final String tenantId;
  final String name;
  final String? description;
  final String status;
  final int itemCount;
  final int sizeBytes;
  final DateTime lastUpdated;
}

class DatasetScreening {
  const DatasetScreening({
    required this.diagnosisId,
    required this.patientCode,
    required this.diagnosedAt,
    required this.isPositive,
    required this.confidence,
    required this.status,
    required this.modelVersion,
  });
  final String diagnosisId;
  final String patientCode;
  final DateTime diagnosedAt;
  final bool isPositive;
  final int confidence;
  final String status;
  final String modelVersion;
}
