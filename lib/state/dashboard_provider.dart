import 'package:flutter/foundation.dart';
import 'package:myapp/domain/models/models.dart';
import 'package:myapp/domain/repositories/dashboard_repository.dart';
import 'package:myapp/domain/models/dashboard_snapshot.dart';
import 'package:myapp/state/auth_provider.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._repository, {AuthProvider? session})
    : _session = session {
    if (isLive) {
      _session?.addListener(_sessionChanged);
      _sessionChanged();
    } else {
      _loadDashboardData();
    }
  }

  final DashboardRepository _repository;
  final AuthProvider? _session;
  DashboardSnapshot? _snapshot;
  String? _owner;
  String? _error;
  int _generation = 0;
  bool _disposed = false;
  bool get isLive => _repository is DashboardSnapshotRepository;
  DashboardSnapshot? get snapshot => _snapshot;
  String? get error => _error;
  int get days => switch (_selectedTimePeriod) {
    'Last 60 days' => 60,
    'Last 3 months' => 90,
    'Last 6 months' => 180,
    _ => 30,
  };

  void _sessionChanged() {
    final session = _session;
    final next = session == null
        ? 'isolated-dashboard'
        : session.isLoggedIn &&
              !session.mustChangePassword &&
              session.mobileRole.allows('/dashboard')
        ? '${session.userId}:${session.tenantId}'
        : null;
    if (next == _owner) return;
    _owner = next;
    _generation++;
    _clearLive();
    if (next == null) {
      notifyListeners();
    } else {
      refresh();
    }
  }

  void _clearLive() {
    _snapshot = null;
    _metrics = const [];
    _recentActivities = const [];
    _trendData = const [];
    _systemStatuses = const [];
    _isLoading = false;
    _error = null;
  }

  Future<void> refresh() async {
    if (!isLive) return _fetchData();
    if (_disposed || _owner == null) return;
    final generation = ++_generation;
    _clearLive();
    _isLoading = true;
    notifyListeners();
    try {
      final result = await (_repository as DashboardSnapshotRepository).load(
        days: days,
        tzOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
      if (_disposed || generation != _generation) return;
      _snapshot = result;
      _metrics = result.metrics;
      _recentActivities = result.activities;
      _trendData = result.trend;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _error = 'Dashboard tidak dapat dimuat. Periksa koneksi dan coba lagi.';
    }
    if (_disposed || generation != _generation) return;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _session?.removeListener(_sessionChanged);
    super.dispose();
  }

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

  final List<String> institutions = ['All Institutions'];

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
    if (!timePeriods.contains(value)) return;
    if (_selectedTimePeriod != value) {
      _selectedTimePeriod = value;
      _fetchData();
      notifyListeners();
    }
  }

  void setInstitution(String value) {
    if (isLive) return;
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
    if (isLive) return refresh();
    _isLoading = true;
    notifyListeners();

    // Simulate API delay
    _loadDashboardData();

    _isLoading = false;
    notifyListeners();
  }
}
