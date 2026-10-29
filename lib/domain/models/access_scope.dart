/// Mobile permissions. Live roles come from the authenticated server profile.
enum MobileRole {
  clinician,
  technician,
  management,
  unsupported;

  static MobileRole parse(String? value) => switch (value) {
    'doctor' || 'health_worker' || 'user' => clinician,
    'technician' => technician,
    'management' || 'hospital_management' => management,
    _ => unsupported,
  };

  String get home => switch (this) {
    clinician => '/dashboard',
    technician => '/technician',
    management || unsupported => '/account',
  };

  bool allows(String path) {
    if (path == '/account') return true;
    return switch (this) {
      clinician => const {
        '/dashboard',
        '/patients',
        '/diagnosis',
        '/validation',
        '/dataset',
        '/result',
        '/camera',
      }.contains(path),
      technician => const {
        '/technician',
        '/users',
        '/dashboard',
        '/dataset',
      }.contains(path),
      management || unsupported => false,
    };
  }
}

/// Demo catalog only; it never changes the tenant assigned by the server.
const demoInstitutions = {
  'sardjito': 'Sardjito',
  'papua': 'Papua',
  'balkesmas': 'Balkesmas',
  'respira': 'Respira',
};
