/// Single X-ray image inside a dataset.
class DatasetImage {
  const DatasetImage({
    required this.code,
    required this.addedDate,
    required this.diagnosis,
    this.imageUrl,
  });

  final String code;
  final String addedDate;

  /// "Positive / TBC" | "Negative / Normal"
  final String diagnosis;
  final String? imageUrl;
}

/// Immutable training dataset (list + detail views on DatasetScreen).
class DatasetModel {
  const DatasetModel({
    required this.id,
    required this.name,
    required this.description,
    required this.totalImages,
    required this.size,
    required this.lastUpdated,
    required this.status,
    required this.images,
  });

  final String id;
  final String name;
  final String description;
  final int totalImages;
  final String size;
  final String lastUpdated;

  /// "ACTIVE" | "ARCHIVED"
  final String status;
  final List<DatasetImage> images;
}

/// Flat dataset log entry (date / patient / image / labeling status).
class DatasetRecord {
  const DatasetRecord({
    required this.date,
    required this.patientId,
    required this.image,
    required this.status,
  });

  final String date;
  final String patientId;
  final String image;
  final String status;
}
