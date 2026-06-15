class DatasetImage {
  final String code;
  final String addedDate;
  final String diagnosis; // "Positive / TBC" | "Negative / Normal"
  final String? imageUrl;

  const DatasetImage({
    required this.code,
    required this.addedDate,
    required this.diagnosis,
    this.imageUrl,
  });
}

class DatasetModel {
  final String id;
  final String name;
  final String description;
  final int totalImages;
  final String size;
  final String lastUpdated;
  final String status; // "ACTIVE" | "ARCHIVED"
  final List<DatasetImage> images;

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
}

final List<DatasetModel> mockDatasets = [
  DatasetModel(
    id: "DS001",
    name: "TB_Screening_Adults_2026",
    description: "Primary dataset for adult TB screening containing verified X-rays.",
    totalImages: 1247,
    size: "1.2 GB",
    lastUpdated: "2026-04-15",
    status: "ACTIVE",
    images: [
      DatasetImage(code: "XRAY-7721", addedDate: "2026-04-01", diagnosis: "Positive / TBC"),
      DatasetImage(code: "XRAY-7722", addedDate: "2026-04-02", diagnosis: "Negative / Normal"),
      DatasetImage(code: "XRAY-7723", addedDate: "2026-04-03", diagnosis: "Positive / TBC"),
      DatasetImage(code: "XRAY-7724", addedDate: "2026-04-04", diagnosis: "Negative / Normal"),
    ],
  ),
  DatasetModel(
    id: "DS002",
    name: "TB_Screening_Pediatric_2025",
    description: "Dataset for pediatric TB screening from Q4 2025.",
    totalImages: 856,
    size: "450 MB",
    lastUpdated: "2025-11-20",
    status: "ACTIVE",
    images: [
      DatasetImage(code: "XRAY-5501", addedDate: "2025-11-15", diagnosis: "Negative / Normal"),
      DatasetImage(code: "XRAY-5502", addedDate: "2025-11-16", diagnosis: "Positive / TBC"),
    ],
  ),
  DatasetModel(
    id: "DS003",
    name: "TB_Screening_Smokers_2024",
    description: "Dataset for smokers TB screening from 2024.",
    totalImages: 523,
    size: "780 MB",
    lastUpdated: "2026-01-10",
    status: "ARCHIVED",
    images: [
      DatasetImage(code: "XRAY-3301", addedDate: "2024-12-01", diagnosis: "Positive / TBC"),
    ],
  ),
];
