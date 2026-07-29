import 'package:flutter/foundation.dart';
import 'package:myapp/domain/models/models.dart';
import 'package:myapp/domain/repositories/dashboard_repository.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._repository) {
    _loadDashboardData();
  }

  final DashboardRepository _repository;

  String _selectedTimePeriod = 'Last 30 days';
  String _selectedInstitution = 'All Institutions';
  String _selectedDistributionFilter = 'All Cases';
  bool _isLoading = false;

  List<DashboardMetric> _metrics = const [];
  List<ActivityItem> _recentActivities = const [];
  List<TrendDataPoint> _trendData = const [];
  List<SystemStatus> _systemStatuses = const [];

  String get selectedTimePeriod => _selectedTimePeriod;
  String get selectedInstitution => _selectedInstitution;
  String get selectedDistributionFilter => _selectedDistributionFilter;
  bool get isLoading => _isLoading;

  List<DashboardMetric> get metrics => _metrics;
  List<ActivityItem> get recentActivities => _recentActivities;
  List<TrendDataPoint> get trendData => _trendData;
  List<SystemStatus> get systemStatuses => _systemStatuses;

  final List<String> timePeriods = [
    'Last 30 days',
    'Last 60 days',
    'Last 3 months',
    'Last 6 months',
  ];

  final List<String> institutions = [
    'All Institutions',
    'RS. Sardjito',
    'RS. Bethesda',
    'RS. PKU Muhammadiyah',
  ];

  final List<String> distributionFilters = [
    'All Cases',
    'Positive TB',
    'Negative TB',
  ];

  /// Uses .then instead of await so the mock's SynchronousFuture resolves
  /// before the first build — no loading flash on screen entry.
  void _loadDashboardData() {
    _repository.getMetrics().then((value) {
      _metrics = value;
      notifyListeners();
    });
    _repository.getRecentActivities().then((value) {
      _recentActivities = value;
      notifyListeners();
    });
    _repository.getTrendData().then((value) {
      _trendData = value;
      notifyListeners();
    });
    _repository.getSystemStatuses().then((value) {
      _systemStatuses = value;
      notifyListeners();
    });
  }

  void setTimePeriod(String value) {
    if (_selectedTimePeriod != value) {
      _selectedTimePeriod = value;
      _fetchData();
      notifyListeners();
    }
  }

  void setInstitution(String value) {
    if (_selectedInstitution != value) {
      _selectedInstitution = value;
      _fetchData();
      notifyListeners();
    }
  }

  void setDistributionFilter(String value) {
    if (_selectedDistributionFilter != value) {
      _selectedDistributionFilter = value;
      notifyListeners();
    }
  }

  Future<void> _fetchData() async {
    _isLoading = true;
    notifyListeners();

    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 800));

    _isLoading = false;
    notifyListeners();
  }
}
