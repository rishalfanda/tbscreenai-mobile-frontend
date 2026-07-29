/// Authenticated user of the app (Doctor role in this repo).
class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.email,
    this.role = 'doctor',
  });

  final String displayName;
  final String email;
  final String role;
}
