import 'package:flutter/foundation.dart';

class DashboardProvider extends ChangeNotifier {
  String _selectedTimePeriod = 'Last 30 days';
  String _selectedInstitution = 'All Institutions';
  String _selectedDistributionFilter = 'All Cases';
  bool _isLoading = false;

  String get selectedTimePeriod => _selectedTimePeriod;
  String get selectedInstitution => _selectedInstitution;
  String get selectedDistributionFilter => _selectedDistributionFilter;
  bool get isLoading => _isLoading;

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
