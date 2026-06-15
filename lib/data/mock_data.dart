import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';

class DashboardMetric {
  const DashboardMetric({
    required this.title,
    required this.value,
    required this.change,
    required this.icon,
    this.subtext,
    this.iconColor,
  });

  final String title;
  final String value;
  final String change;
  final String icon;
  final String? subtext;
  final Color? iconColor;
}

class ActivityItem {
  const ActivityItem({
    required this.name,
    required this.timestamp,
    required this.result,
    required this.confidence,
    required this.institution,
  });

  final String name;
  final String timestamp;
  final String result;
  final int confidence;
  final String institution;
}

class PatientSummary {
  const PatientSummary({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.status,
    required this.confidence,
    required this.lastVisit,
    required this.history,
  });

  final String id;
  final String name;
  final int age;
  final String gender;
  final String status;
  final int confidence;
  final String lastVisit;
  final List<String> history;
}

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

class TrendDataPoint {
  const TrendDataPoint({
    required this.date,
    required this.totalDiagnoses,
    required this.totalPatients,
  });

  final String date;
  final int totalDiagnoses;
  final int totalPatients;
}

class MockData {
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
      iconColor: AppTheme.success,
    ),
    DashboardMetric(
      title: 'Unvalidated',
      value: '428',
      change: '-5%',
      icon: 'pending',
      subtext: 'awaiting review',
      iconColor: AppTheme.warning,
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

  static const systemStatuses = <Map<String, String>>[
    {'label': 'AI Model', 'value': 'Active'},
    {'label': 'Database', 'value': 'Connected'},
    {'label': 'Storage', 'value': '68% Used'},
  ];

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

  static const patients = <PatientSummary>[
    PatientSummary(
      id: 'TB000001',
      name: 'Ahmad Fauzi',
      age: 44,
      gender: 'Male',
      status: 'Positive',
      confidence: 96,
      lastVisit: '2026-04-14',
      history: ['Initial screening completed', 'Xpert positive', 'Follow-up scheduled'],
    ),
    PatientSummary(
      id: 'TB000002',
      name: 'Nadia Putri',
      age: 29,
      gender: 'Female',
      status: 'Normal',
      confidence: 84,
      lastVisit: '2026-04-13',
      history: ['No infiltrates detected', 'Monitoring in 30 days'],
    ),
    PatientSummary(
      id: 'TB000003',
      name: 'Rian Saputra',
      age: 37,
      gender: 'Male',
      status: 'Positive',
      confidence: 92,
      lastVisit: '2026-04-12',
      history: ['Persistent cough reported', 'IGRA pending'],
    ),
    PatientSummary(
      id: 'TB000004',
      name: 'Mira Salsabila',
      age: 17,
      gender: 'Female',
      status: 'Normal',
      confidence: 81,
      lastVisit: '2026-04-10',
      history: ['Pediatric score captured', 'Image quality acceptable'],
    ),
    PatientSummary(
      id: 'TB000005',
      name: 'Hendra Wijaya',
      age: 52,
      gender: 'Male',
      status: 'Positive',
      confidence: 90,
      lastVisit: '2026-04-09',
      history: ['History of smoking', 'Culture sent to lab'],
    ),
    PatientSummary(
      id: 'TB000006',
      name: 'Lina Marlina',
      age: 31,
      gender: 'Female',
      status: 'Normal',
      confidence: 77,
      lastVisit: '2026-04-08',
      history: ['Chest pain resolved', 'No active lesion pattern'],
    ),
    PatientSummary(
      id: 'TB000007',
      name: 'Yusuf Maulana',
      age: 63,
      gender: 'Male',
      status: 'Positive',
      confidence: 95,
      lastVisit: '2026-04-07',
      history: ['Previous TB history', 'Urgent referral recommended'],
    ),
    PatientSummary(
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

  static const dataset = <DatasetRecord>[
    DatasetRecord(date: '2026-04-15', patientId: 'TB000001', image: 'xray_001.png', status: 'Labeled'),
    DatasetRecord(date: '2026-04-15', patientId: 'TB000002', image: 'xray_002.png', status: 'Pending'),
    DatasetRecord(date: '2026-04-14', patientId: 'TB000003', image: 'xray_003.png', status: 'Reviewed'),
    DatasetRecord(date: '2026-04-14', patientId: 'TB000004', image: 'xray_004.png', status: 'Labeled'),
    DatasetRecord(date: '2026-04-13', patientId: 'TB000005', image: 'xray_005.png', status: 'Pending'),
    DatasetRecord(date: '2026-04-12', patientId: 'TB000006', image: 'xray_006.png', status: 'Reviewed'),
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
}
