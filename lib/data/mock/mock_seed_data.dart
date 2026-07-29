import 'package:myapp/domain/models/models.dart';

/// Central seed data for every Mock* repository.
/// Content is a 1:1 carry-over of the former lib/data/mock_data.dart,
/// dataset_mock.dart and validation_mock.dart — only the representation
/// changed (immutable domain models instead of raw maps).
class MockSeedData {
  MockSeedData._();

  // === Section: Dashboard ===

  static const dashboardMetrics = <DashboardMetric>[
    DashboardMetric(
      title: 'Total Patients',
      value: '1,248',
      change: '+12%',
      icon: 'people',
    ),
    DashboardMetric(
      title: 'Total Diagnoses',
      value: '3,567',
      change: '+8%',
      icon: 'analytics',
    ),
    DashboardMetric(
      title: 'Validated',
      value: '3,139',
      change: '+15%',
      icon: 'verified',
      subtext: 'of 3,567 total',
      tone: MetricTone.success,
    ),
    DashboardMetric(
      title: 'Unvalidated',
      value: '428',
      change: '-5%',
      icon: 'pending',
      subtext: 'awaiting review',
      tone: MetricTone.warning,
    ),
  ];

  static const recentActivities = <ActivityItem>[
    ActivityItem(
      name: 'John Doe',
      timestamp: '2026-04-02 14:30',
      result: 'Negative',
      confidence: 95,
      institution: 'RS. Sardjito',
    ),
    ActivityItem(
      name: 'Jane Smith',
      timestamp: '2026-04-02 13:15',
      result: 'Positive',
      confidence: 87,
      institution: 'RS. Bethesda',
    ),
    ActivityItem(
      name: 'Mike Johnson',
      timestamp: '2026-04-02 11:45',
      result: 'Negative',
      confidence: 92,
      institution: 'RS. PKU Muhammadiyah',
    ),
    ActivityItem(
      name: 'Sarah Williams',
      timestamp: '2026-04-02 10:20',
      result: 'Negative',
      confidence: 89,
      institution: 'RS. Sardjito',
    ),
  ];

  static const systemStatuses = <SystemStatus>[
    SystemStatus(label: 'AI Model', value: 'Active'),
    SystemStatus(label: 'Database', value: 'Connected'),
    SystemStatus(label: 'Storage', value: '68% Used'),
  ];

  static const trendData = <TrendDataPoint>[
    TrendDataPoint(date: 'Apr 1', totalDiagnoses: 20, totalPatients: 15),
    TrendDataPoint(date: 'Apr 4', totalDiagnoses: 24, totalPatients: 18),
    TrendDataPoint(date: 'Apr 7', totalDiagnoses: 18, totalPatients: 14),
    TrendDataPoint(date: 'Apr 10', totalDiagnoses: 26, totalPatients: 20),
    TrendDataPoint(date: 'Apr 14', totalDiagnoses: 22, totalPatients: 16),
    TrendDataPoint(date: 'Apr 17', totalDiagnoses: 24, totalPatients: 18),
    TrendDataPoint(date: 'Apr 20', totalDiagnoses: 21, totalPatients: 16),
    TrendDataPoint(date: 'Apr 24', totalDiagnoses: 28, totalPatients: 22),
    TrendDataPoint(date: 'Apr 27', totalDiagnoses: 23, totalPatients: 17),
    TrendDataPoint(date: 'Apr 30', totalDiagnoses: 25, totalPatients: 19),
  ];

  // === Section: Diagnosis ===

  static const symptomOptions = <String>[
    'Fever',
    'Cough',
    'Dyspnea',
    'Fatigue',
    'Hemoptysis',
    'Night Sweats',
    'Anorexia',
    'Weight Loss',
    'Chest Pain',
    'Other',
  ];

  // === Section: Patients ===

  static const patients = <Patient>[
    Patient(
      id: 'TB000001',
      name: 'Ahmad Fauzi',
      age: 44,
      gender: 'Male',
      status: 'Positive',
      confidence: 96,
      lastVisit: '2026-04-14',
      history: ['Initial screening completed', 'Xpert positive', 'Follow-up scheduled'],
    ),
    Patient(
      id: 'TB000002',
      name: 'Nadia Putri',
      age: 29,
      gender: 'Female',
      status: 'Normal',
      confidence: 84,
      lastVisit: '2026-04-13',
      history: ['No infiltrates detected', 'Monitoring in 30 days'],
    ),
    Patient(
      id: 'TB000003',
      name: 'Rian Saputra',
      age: 37,
      gender: 'Male',
      status: 'Positive',
      confidence: 92,
      lastVisit: '2026-04-12',
      history: ['Persistent cough reported', 'IGRA pending'],
    ),
    Patient(
      id: 'TB000004',
      name: 'Mira Salsabila',
      age: 17,
      gender: 'Female',
      status: 'Normal',
      confidence: 81,
      lastVisit: '2026-04-10',
      history: ['Pediatric score captured', 'Image quality acceptable'],
    ),
    Patient(
      id: 'TB000005',
      name: 'Hendra Wijaya',
      age: 52,
      gender: 'Male',
      status: 'Positive',
      confidence: 90,
      lastVisit: '2026-04-09',
      history: ['History of smoking', 'Culture sent to lab'],
    ),
    Patient(
      id: 'TB000006',
      name: 'Lina Marlina',
      age: 31,
      gender: 'Female',
      status: 'Normal',
      confidence: 77,
      lastVisit: '2026-04-08',
      history: ['Chest pain resolved', 'No active lesion pattern'],
    ),
    Patient(
      id: 'TB000007',
      name: 'Yusuf Maulana',
      age: 63,
      gender: 'Male',
      status: 'Positive',
      confidence: 95,
      lastVisit: '2026-04-07',
      history: ['Previous TB history', 'Urgent referral recommended'],
    ),
    Patient(
      id: 'TB000008',
      name: 'Sarah Amelia',
      age: 24,
      gender: 'Female',
      status: 'Normal',
      confidence: 86,
      lastVisit: '2026-04-06',
      history: ['Fatigue noted', 'Recheck if symptoms persist'],
    ),
  ];

  // === Section: Dataset ===

  static const datasetRecords = <DatasetRecord>[
    DatasetRecord(date: '2026-04-15', patientId: 'TB000001', image: 'xray_001.png', status: 'Labeled'),
    DatasetRecord(date: '2026-04-15', patientId: 'TB000002', image: 'xray_002.png', status: 'Pending'),
    DatasetRecord(date: '2026-04-14', patientId: 'TB000003', image: 'xray_003.png', status: 'Reviewed'),
    DatasetRecord(date: '2026-04-14', patientId: 'TB000004', image: 'xray_004.png', status: 'Labeled'),
    DatasetRecord(date: '2026-04-13', patientId: 'TB000005', image: 'xray_005.png', status: 'Pending'),
    DatasetRecord(date: '2026-04-12', patientId: 'TB000006', image: 'xray_006.png', status: 'Reviewed'),
  ];

  static const datasets = <DatasetModel>[
    DatasetModel(
      id: 'DS001',
      name: 'TB_Screening_Adults_2026',
      description: 'Primary dataset for adult TB screening containing verified X-rays.',
      totalImages: 1247,
      size: '1.2 GB',
      lastUpdated: '2026-04-15',
      status: 'ACTIVE',
      images: [
        DatasetImage(code: 'XRAY-7721', addedDate: '2026-04-01', diagnosis: 'Positive / TBC'),
        DatasetImage(code: 'XRAY-7722', addedDate: '2026-04-02', diagnosis: 'Negative / Normal'),
        DatasetImage(code: 'XRAY-7723', addedDate: '2026-04-03', diagnosis: 'Positive / TBC'),
        DatasetImage(code: 'XRAY-7724', addedDate: '2026-04-04', diagnosis: 'Negative / Normal'),
      ],
    ),
    DatasetModel(
      id: 'DS002',
      name: 'TB_Screening_Pediatric_2025',
      description: 'Dataset for pediatric TB screening from Q4 2025.',
      totalImages: 856,
      size: '450 MB',
      lastUpdated: '2025-11-20',
      status: 'ACTIVE',
      images: [
        DatasetImage(code: 'XRAY-5501', addedDate: '2025-11-15', diagnosis: 'Negative / Normal'),
        DatasetImage(code: 'XRAY-5502', addedDate: '2025-11-16', diagnosis: 'Positive / TBC'),
      ],
    ),
    DatasetModel(
      id: 'DS003',
      name: 'TB_Screening_Smokers_2024',
      description: 'Dataset for smokers TB screening from 2024.',
      totalImages: 523,
      size: '780 MB',
      lastUpdated: '2026-01-10',
      status: 'ARCHIVED',
      images: [
        DatasetImage(code: 'XRAY-3301', addedDate: '2024-12-01', diagnosis: 'Positive / TBC'),
      ],
    ),
  ];

  // === Section: Validation ===

  static const validationCases = <ValidationCase>[
    ValidationCase(
      id: 'TB000001',
      name: 'John Doe',
      initials: 'JD',
      age: 45,
      gender: 'Male',
      aiScore: 66,
      diagnosisDate: 'Apr 30, 2026',
      status: 'pending',
      findings: ValidationFindings(
        consolidation: 26.34,
        cavity: 0.58,
        effusion: 5.64,
        fibrotic: 0,
        calcification: 0,
      ),
    ),
    ValidationCase(
      id: 'TB000002',
      name: 'Sarah Williams',
      initials: 'SW',
      age: 32,
      gender: 'Female',
      aiScore: 31,
      diagnosisDate: 'Apr 26, 2026',
      status: 'pending',
      findings: ValidationFindings(
        consolidation: 12.10,
        cavity: 0,
        effusion: 3.20,
        fibrotic: 1.50,
        calcification: 0,
      ),
    ),
    ValidationCase(
      id: 'TB000003',
      name: 'Emily Davis',
      initials: 'ED',
      age: 58,
      gender: 'Female',
      aiScore: 55,
      diagnosisDate: 'Apr 24, 2026',
      status: 'pending',
      findings: ValidationFindings(
        consolidation: 20.00,
        cavity: 1.20,
        effusion: 4.80,
        fibrotic: 0,
        calcification: 2.10,
      ),
    ),
    ValidationCase(
      id: 'TB000004',
      name: 'Jane Smith',
      initials: 'JS',
      age: 29,
      gender: 'Female',
      aiScore: 87,
      diagnosisDate: 'Apr 23, 2026',
      status: 'agreed',
      doctorNote: 'Confirmed positive. Consolidation pattern consistent with TB.',
      findings: ValidationFindings(
        consolidation: 38.50,
        cavity: 4.20,
        effusion: 8.10,
        fibrotic: 0,
        calcification: 0,
      ),
    ),
    ValidationCase(
      id: 'TB000005',
      name: 'Michael Chen',
      initials: 'MC',
      age: 41,
      gender: 'Male',
      aiScore: 22,
      diagnosisDate: 'Apr 20, 2026',
      status: 'disagreed',
      doctorNote: 'Patient has old scarring from previous pneumonia, not active TB.',
      findings: ValidationFindings(
        consolidation: 8.00,
        cavity: 0,
        effusion: 1.10,
        fibrotic: 14.30,
        calcification: 5.60,
      ),
    ),
    ValidationCase(
      id: 'TB000006',
      name: 'Robert Brown',
      initials: 'RB',
      age: 63,
      gender: 'Male',
      aiScore: 74,
      diagnosisDate: 'Apr 18, 2026',
      status: 'agreed',
      doctorNote: '',
      findings: ValidationFindings(
        consolidation: 30.10,
        cavity: 3.80,
        effusion: 6.90,
        fibrotic: 0,
        calcification: 0,
      ),
    ),
  ];

  // === Section: Sync Center ===

  static const modelVersionInfo = ModelVersionInfo(
    currentVersion: 'v1.2.0',
    latestVersion: 'v1.3.1',
    fileSize: '47.2 MB',
    releaseDate: '10 Juni 2025',
    changelog: [
      'Peningkatan akurasi deteksi TB aktif sebesar 3.2%',
      'Perbaikan false positive pada pasien pediatrik',
      'Optimasi kecepatan inferensi pada perangkat low-end',
    ],
  );

  static const syncSummary = SyncSummary(
    totalPatients: 32,
    totalDiagnoses: 89,
    totalSizeMB: 128,
    lastSyncDate: null,
  );
}
