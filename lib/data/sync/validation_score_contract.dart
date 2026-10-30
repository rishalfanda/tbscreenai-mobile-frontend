import 'package:dio/dio.dart';
import 'package:myapp/data/http/api_client.dart';

/// Older servers silently ignore unknown score fields. Never send numeric
/// reviews unless the deployed write AND read schemas advertise PR38 fields.
Future<bool> supportsValidationScore(ApiClient client) async {
  try {
    final uri = Uri.parse(
      client.baseUrl,
    ).replace(path: '/openapi.json', query: '', fragment: '');
    final response = await client.dio.getUri<Object?>(
      uri,
      options: Options(
        followRedirects: false,
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    return hasValidationScoreContract(response.data);
  } catch (_) {
    return false;
  }
}

bool hasValidationScoreContract(Object? document) {
  if (document is! Map) return false;
  final components = document['components'];
  if (components is! Map || components['schemas'] is! Map) return false;
  final schemas = components['schemas'] as Map;
  Map<String, dynamic>? properties(Object? raw, [int depth = 0]) {
    if (raw is! Map || depth > 8) return null;
    final ref = raw[r'$ref'];
    if (ref is String) {
      const prefix = '#/components/schemas/';
      if (!ref.startsWith(prefix)) return null;
      return properties(schemas[ref.substring(prefix.length)], depth + 1);
    }
    final props = <String, dynamic>{};
    if (raw['properties'] is Map) {
      props.addAll(Map<String, dynamic>.from(raw['properties'] as Map));
    }
    if (raw['allOf'] is List) {
      for (final part in raw['allOf'] as List) {
        final inherited = properties(part, depth + 1);
        if (inherited == null) return null;
        props.addAll(inherited);
      }
    }
    return props;
  }

  final paths = document['paths'];
  if (paths is! Map) return false;
  for (final entry in paths.entries) {
    if (entry.key is! String ||
        !RegExp(r'/diagnoses/\{[^/]+\}/status$').hasMatch(entry.key as String)) {
      continue;
    }
    final path = entry.value;
    if (path is! Map || path['patch'] is! Map) continue;
    final patch = path['patch'] as Map;
    Object? schemaAt(Object? container) {
      if (container is! Map || container['content'] is! Map) return null;
      final json = (container['content'] as Map)['application/json'];
      return json is Map ? json['schema'] : null;
    }

    final write = properties(schemaAt(patch['requestBody']));
    final responses = patch['responses'];
    final read = properties(
      schemaAt(responses is Map ? responses['200'] : null),
    );
    if (write != null &&
        read != null &&
        [
          'status',
          'base_version',
          'validation_score',
          'validated_at',
        ].every(write.containsKey) &&
        [
          'validation_score',
          'validated_at',
          'validated_by',
        ].every(read.containsKey)) {
      return true;
    }
  }
  return false;
}
