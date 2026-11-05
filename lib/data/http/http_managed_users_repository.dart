import 'package:myapp/data/http/api_client.dart';

class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    required this.mustChangePassword,
    this.specialization,
  });
  final String id, tenantId, name, email, role;
  final bool active, mustChangePassword;
  final String? specialization;
  static ManagedUser parse(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid user');
    }
    String value(String key) {
      final v = raw[key];
      if (v is! String || v.isEmpty) {
        throw const FormatException('Invalid user field');
      }
      return v;
    }

    if (raw['is_active'] is! bool ||
        raw['must_change_password'] is! bool ||
        (raw['specialization'] != null && raw['specialization'] is! String)) {
      throw const FormatException('Invalid user status');
    }
    return ManagedUser(
      id: value('id'),
      tenantId: value('tenant_id'),
      name: value('full_name'),
      email: value('email'),
      role: value('role'),
      active: raw['is_active'] as bool,
      mustChangePassword: raw['must_change_password'] as bool,
      specialization: raw['specialization'] as String?,
    );
  }
}

class ManagedUserPage {
  const ManagedUserPage(this.items, this.total, this.offset);
  final List<ManagedUser> items;
  final int total, offset;
}

/// Passwords only live in the response/UI until the one-time dialog is closed.
class IssuedPassword {
  const IssuedPassword(this.user, this.password, this.expiresAt);
  final ManagedUser user;
  final String password;
  final DateTime expiresAt;
}

class HttpManagedUsersRepository {
  HttpManagedUsersRepository(this.client);
  final ApiClient client;
  static const pageSize = 20;
  Future<ManagedUserPage> list(
    String tenant, {
    String query = '',
    int offset = 0,
    bool? active,
  }) async {
    final response = await client.dio.get<Object?>(
      '/users',
      queryParameters: {
        'limit': pageSize,
        'offset': offset,
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'is_active': ?active,
      },
    );
    final raw = response.data;
    if (raw is! Map<String, dynamic> ||
        raw['items'] is! List ||
        raw['total'] is! int ||
        (raw['total'] as int) < 0 ||
        raw['limit'] != pageSize ||
        raw['offset'] != offset) {
      throw const FormatException('Invalid user page');
    }
    final items = (raw['items'] as List)
        .map((v) => _owned(v, tenant))
        .toList(growable: false);
    final total = raw['total'] as int;
    if (items.length > pageSize ||
        (items.isNotEmpty && offset + items.length > total) ||
        (items.length < pageSize && offset + items.length < total)) {
      throw const FormatException('Invalid user pagination');
    }
    return ManagedUserPage(items, total, offset);
  }

  ManagedUser _owned(Object? raw, String tenant, [String? id]) {
    final user = ManagedUser.parse(raw);
    if (user.tenantId != tenant || (id != null && user.id != id)) {
      throw const FormatException('User institution mismatch');
    }
    return user;
  }

  Future<ManagedUser> detail(String tenant, String id) async => _owned(
    (await client.dio.get<Object?>('/users/${Uri.encodeComponent(id)}')).data,
    tenant,
    id,
  );
  Future<IssuedPassword> create(
    String tenant, {
    required String name,
    required String email,
    String? specialization,
  }) async => _issued(
    (await client.dio.post<Object?>(
      '/users',
      data: {
        'full_name': name.trim(),
        'email': email.trim(),
        'role': 'doctor',
        'specialization': specialization,
      },
    )).data,
    tenant,
  );
  Future<ManagedUser> update(
    String tenant,
    String id,
    Map<String, Object?> changes,
  ) async => _owned(
    (await client.dio.patch<Object?>(
      '/users/${Uri.encodeComponent(id)}',
      data: changes,
    )).data,
    tenant,
    id,
  );
  Future<IssuedPassword> reset(String tenant, String id) async => _issued(
    (await client.dio.post<Object?>(
      '/users/${Uri.encodeComponent(id)}/reset-password',
    )).data,
    tenant,
    id,
  );
  IssuedPassword _issued(Object? raw, String tenant, [String? id]) {
    if (raw is! Map<String, dynamic> ||
        raw['temporary_password'] is! String ||
        (raw['temporary_password'] as String).isEmpty ||
        raw['expires_at'] is! String) {
      throw const FormatException('Invalid one-time password response');
    }
    return IssuedPassword(
      _owned(raw['user'], tenant, id),
      raw['temporary_password'] as String,
      DateTime.parse(raw['expires_at'] as String),
    );
  }
}
