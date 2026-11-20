import 'api_client.dart';
import 'package:myapp/state/auth_provider.dart';

/// Reconnect checks do not turn network outages into a local logout.
Future<void> checkOnlineSession(ApiClient client, AuthProvider auth) async {
  final actor = auth.profile;
  if (!auth.isLoggedIn || actor == null) return;
  try {
    final data = (await client.dio.get<Object?>('/auth/me')).data;
    if (!auth.isLoggedIn || !identical(actor, auth.profile)) return;
    if (data is! Map ||
        data['id'] != actor.userId ||
        data['tenant_id'] != actor.tenantId ||
        data['role'] != actor.role ||
        data['is_active'] == false) {
      await auth.expireSession(code: 'session_ended');
    }
  } catch (_) {
    // ApiClient handles definitive auth refusals centrally. No response is
    // not evidence that the doctor's approved offline identity was revoked.
  }
}
