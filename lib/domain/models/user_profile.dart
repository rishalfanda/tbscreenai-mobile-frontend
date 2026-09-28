/// Authenticated user of the app (Doctor role in this repo).
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
}
