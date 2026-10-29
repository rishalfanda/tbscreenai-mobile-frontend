import 'package:myapp/domain/models/access_scope.dart';

/// Authenticated identity and institution assigned by the server.
class UserProfile {
  const UserProfile({
    required this.userId,
    required this.tenantId,
    required this.displayName,
    required this.email,
    this.role = 'doctor',
  });

  final String userId;
  final String tenantId;
  final String displayName;
  final String email;
  final String role;
  MobileRole get mobileRole => MobileRole.parse(role);
  String get institution => demoInstitutions[tenantId] ?? tenantId;
}
