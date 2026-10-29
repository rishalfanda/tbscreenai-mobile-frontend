import 'package:flutter/foundation.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/core/utils/uuid.dart';
import 'package:myapp/domain/models/access_scope.dart';
import 'package:myapp/domain/models/user_profile.dart';

class InstitutionUser {
  const InstitutionUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.resetRequested = false,
  });
  final String id, name, email, role;
  final bool resetRequested;
}

class InstitutionWorkspace {
  final List<InstitutionUser> users = [];
  final List<String> models = ['TBScreen demo v1'];
  final List<String> events = [];
}

/// Explicitly synthetic, memory-only workspaces. Never reads another account's
/// medical cache or falls back here after an HTTP failure.
class InstitutionProvider extends ChangeNotifier {
  final Map<String, InstitutionWorkspace> _workspaces = {};
  bool get available => !AppConfig.useHttp;

  InstitutionWorkspace read(UserProfile actor) {
    if (!available || !demoInstitutions.containsKey(actor.tenantId)) {
      throw StateError('Institution API unavailable');
    }
    if (actor.mobileRole != MobileRole.technician) {
      throw StateError('Access denied');
    }
    return _workspaces.putIfAbsent(actor.tenantId, InstitutionWorkspace.new);
  }

  InstitutionWorkspace _write(UserProfile actor) {
    if (actor.mobileRole != MobileRole.technician) {
      throw StateError('Access denied');
    }
    return read(actor);
  }

  void saveUser(
    UserProfile actor, {
    String? id,
    required String name,
    required String email,
    required String role,
  }) {
    final workspace = _write(actor);
    if (name.trim().isEmpty ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        !const ['doctor', 'health_worker'].contains(role)) {
      throw ArgumentError('Invalid user');
    }
    if (workspace.users.any(
      (u) => u.id != id && u.email.toLowerCase() == email.trim().toLowerCase(),
    )) {
      throw ArgumentError('Duplicate email');
    }
    final index = workspace.users.indexWhere((u) => u.id == id);
    if (id != null && index < 0) throw StateError('Unknown user');
    final user = InstitutionUser(
      id: id ?? uuidV4(),
      name: name.trim(),
      email: email.trim(),
      role: role,
    );
    if (index < 0) {
      workspace.users.add(user);
    } else {
      workspace.users[index] = user;
    }
    workspace.events.insert(0, 'user_saved');
    notifyListeners();
  }

  void deleteUser(UserProfile actor, String id) {
    final workspace = _write(actor);
    if (!workspace.users.any((u) => u.id == id)) {
      throw StateError('Unknown user');
    }
    workspace.users.removeWhere((u) => u.id == id);
    workspace.events.insert(0, 'user_deleted');
    notifyListeners();
  }

  void resetPassword(UserProfile actor, String id) {
    final workspace = _write(actor);
    final index = workspace.users.indexWhere((u) => u.id == id);
    if (index < 0) throw StateError('Unknown user');
    final user = workspace.users[index];
    workspace.users[index] = InstitutionUser(
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      resetRequested: true,
    );
    workspace.events.insert(0, 'password_reset');
    notifyListeners();
  }

  void deleteModel(UserProfile actor, String model) {
    final workspace = _write(actor);
    if (!workspace.models.remove(model)) throw StateError('Unknown model');
    workspace.events.insert(0, 'model_deleted');
    notifyListeners();
  }
}
