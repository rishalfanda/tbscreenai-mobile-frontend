import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter/foundation.dart';

import 'package:myapp/data/onnx/bundle_manifest.dart';
import 'package:myapp/data/onnx/bundle_store.dart';
import 'package:myapp/data/models_ota/pinned_key.dart';

/// Fully verify an extracted bundle directory. Throws [BundleException] on any
/// failure. On success writes `verified.json` into [dir] and returns the
/// parsed manifest.
///
/// Checks, in order:
/// 1. Ed25519 signature of `SHA256SUMS` against the pinned public key,
/// 2. every listed file's streamed sha256 vs its `SHA256SUMS` line,
/// 3. `manifest.schema_version` is one this app can execute,
/// 4. every `pipeline[].model` is present,
/// 5. `manifest.file_digests_sha256` agrees with `SHA256SUMS`.
Future<BundleManifest> verifyBundleDir(Directory dir) async {
  final sep = Platform.pathSeparator;
  final sumsFile = File('${dir.path}${sep}SHA256SUMS');
  final sigFile = File('${dir.path}${sep}SHA256SUMS.sig');
  final manifestFile = File('${dir.path}${sep}manifest.json');

  if (!await manifestFile.exists()) {
    throw BundleException('not a model bundle — no manifest.json');
  }
  if (!await sumsFile.exists()) throw BundleException('bundle has no SHA256SUMS');
  if (!await sigFile.exists()) {
    throw BundleException('bundle has no SHA256SUMS.sig — cannot verify it');
  }

  // 1. signature over the raw bytes of SHA256SUMS (CRLF included, never normalized).
  final sumsBytes = await sumsFile.readAsBytes();
  final sigBytes = await sigFile.readAsBytes();
  if (sigBytes.length != 64) {
    throw BundleException(
      'SHA256SUMS.sig is ${sigBytes.length} bytes, expected 64',
    );
  }
  final signatureOk = ed.verify(
    ed.PublicKey(pinnedPublicKeyBytes()),
    Uint8List.fromList(sumsBytes),
    Uint8List.fromList(sigBytes),
  );
  if (!signatureOk) {
    throw BundleException(
      'the bundle signature does not match this app\'s pinned key',
    );
  }

  // 2. every listed file's digest, streamed on a background isolate.
  final expected = _parseSums(utf8.decode(sumsBytes));
  final entries = <List<String>>[
    for (final e in expected.entries)
      if (e.key != 'SHA256SUMS' && e.key != 'SHA256SUMS.sig') [e.key, e.value],
  ];
  final digestError = await compute(_hashCheck, <String, dynamic>{
    'dir': dir.path,
    'entries': entries,
  });
  if (digestError != null) throw BundleException(digestError);

  // 3. manifest + schema gate.
  final manifest = BundleManifest.parse(await manifestFile.readAsString());
  if (!manifest.schemaSupported) {
    throw BundleException(
      'bundle schema v${manifest.schemaVersion} is newer than this app '
      'supports (v${BundleManifest.maxSupportedSchema}) — update the app',
    );
  }

  // 4. every referenced model file present.
  for (final f in manifest.referencedModelFiles().toSet()) {
    final stem = f.split('/').last.split('.').first;
    final present = expected.keys.any(
      (k) =>
          k.startsWith('models/') &&
          k.split('/').last.split('.').first == stem,
    );
    if (!present) {
      throw BundleException('manifest needs models/$f, missing from the bundle');
    }
  }

  // 5. manifest digest mirror.
  manifest.fileDigests.forEach((k, v) {
    final key = k.replaceAll('\\', '/');
    final s = expected[key];
    if (s == null) {
      throw BundleException('manifest lists $key but SHA256SUMS does not');
    }
    if (s.toLowerCase() != v.toLowerCase()) {
      throw BundleException('manifest and SHA256SUMS disagree on $key');
    }
  });

  await File('${dir.path}${sep}verified.json').writeAsString(
    jsonEncode({
      'signature': 'ed25519',
      'verified_utc': DateTime.now().toUtc().toIso8601String(),
      'bundle_version': manifest.bundleVersion,
    }),
  );
  return manifest;
}

Map<String, String> _parseSums(String text) {
  final out = <String, String>{};
  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final ws = line.indexOf(RegExp(r'\s'));
    if (ws <= 0) continue;
    final hex = line.substring(0, ws).toLowerCase();
    var name = line.substring(ws).trim();
    if (name.startsWith('*')) name = name.substring(1);
    out[name.replaceAll('\\', '/')] = hex;
  }
  return out;
}

/// Isolate entrypoint: hash each `[relpath, expectedHex]` streamed. Returns an
/// error string, or `null` when every file matches.
Future<String?> _hashCheck(Map<String, dynamic> args) async {
  final dirPath = args['dir'] as String;
  final entries = (args['entries'] as List).cast<List>();
  final sep = Platform.pathSeparator;
  for (final e in entries) {
    final rel = (e[0] as String).replaceAll('/', sep);
    final want = (e[1] as String).toLowerCase();
    final file = File('$dirPath$sep$rel');
    if (!file.existsSync()) return 'bundle is missing ${e[0]}';
    final digest = (await sha256.bind(file.openRead()).first).toString();
    if (digest != want) return 'sha256 mismatch on ${e[0]}';
  }
  return null;
}
