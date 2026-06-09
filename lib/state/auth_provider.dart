import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String _displayName = 'Dr. Maya Rizki';

  bool get isLoggedIn => _isLoggedIn;
  String get displayName => _displayName;

  void login({required String email}) {
    _displayName = email.split('@').first.replaceAll('.', ' ');
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }
}
