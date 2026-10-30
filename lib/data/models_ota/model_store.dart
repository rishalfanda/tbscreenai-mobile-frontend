import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:myapp/domain/models/available_model_bundle.dart';

/// The on-device model-bundle store:
///
/// ```
/// <appSupport>/models/
///   ACTIVE          text: the active bundle_version or bundleKey
///   PREVIOUS        text: the rollback target
///   incoming/       in-flight download + staging (wiped on startup)
///   <bundleKey>/    a fully-verified staged bundle (e.g. "stable_2026.09.04")
/// ```
///
/// Bundles are downloaded, signature-verified and staged by
/// `lib/data/models_ota/model_update_pipeline.dart`; this type only manages the
/// on-disk layout. Stateless: every method reads/writes the filesystem.
class ModelStore {
  static const _dirName = 'models';
  static const _incoming = 'incoming';
  static const _metaFile = 'meta.json';

  /// Standardized unique bundle key combining channel and version.
  static String bundleKey(String channel, String version) {
    final c = channel.toLowerCase().trim();
    final v = version.trim();
    if (c.isEmpty) return v;
    return '${c}_$v';
  }

  Future<Directory> _root() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}${Platform.pathSeparator}$_dirName');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> _pointerFile(String name) async =>
      File('${(await _root()).path}${Platform.pathSeparator}$name');

  Future<String?> _readPointer(String name) async {
    final f = await _pointerFile(name);
    if (!await f.exists()) return null;
    final v = (await f.readAsString()).trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _writePointer(String name, String? value) async {
    final f = await _pointerFile(name);
    if (value == null) {
      if (await f.exists()) await f.delete();
      return;
    }
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(value, flush: true);
    if (await f.exists()) await f.delete();
    await tmp.rename(f.path);
  }

  Future<String?> activeVersion() => _readPointer('ACTIVE');
  Future<String?> previousVersion() => _readPointer('PREVIOUS');

  Future<Directory> versionDir(String version) async =>
      Directory('${(await _root()).path}${Platform.pathSeparator}$version');

  /// Directory of the active bundle, or `null` if none / its files are missing.
  Future<Directory?> activeBundleDir() async {
    var v = await activeVersion();
    if (v == null) {
      final installed = await listInstalledBundleKeys();
      if (installed.isNotEmpty) {
        v = installed.first;
        await _writePointer('ACTIVE', v);
      }
    }
    if (v == null) return null;
    final d = await versionDir(v);
    final manifest = File('${d.path}${Platform.pathSeparator}manifest.json');
    if (!await d.exists() || !await manifest.exists()) return null;
    return d;
  }

  /// Lists all valid installed bundle keys (directories containing manifest.json).
  Future<List<String>> listInstalledBundleKeys() async {
    final root = await _root();
    final installed = <String>[];
    await for (final e in root.list()) {
      if (e is! Directory) continue;
      final name = e.path.split(Platform.pathSeparator).last;
      if (name == _incoming) continue;
      final manifest = File('${e.path}${Platform.pathSeparator}manifest.json');
      if (await manifest.exists()) {
        installed.add(name);
      }
    }
    return installed;
  }

  /// Checks if a bundle is installed and has a valid manifest.json.
  Future<bool> isInstalled(String bundleKey) async {
    final d = await versionDir(bundleKey);
    if (!await d.exists()) return false;
    final manifest = File('${d.path}${Platform.pathSeparator}manifest.json');
    return manifest.exists();
  }

  /// Determines the local lifecycle status of a model bundle.
  Future<ModelBundleStatus> getBundleStatus(String bundleKey) async {
    final d = await versionDir(bundleKey);
    if (!await d.exists()) return ModelBundleStatus.notDownloaded;

    final verifiedFile = File('${d.path}${Platform.pathSeparator}verified.json');
    if (await verifiedFile.exists()) {
      return ModelBundleStatus.verified;
    }

    final meta = await readBundleMeta(bundleKey);
    if (meta != null) {
      final s = meta['status'] as String?;
      if (s == ModelBundleStatus.verified.name) {
        return ModelBundleStatus.verified;
      }
      if (s == ModelBundleStatus.verificationFailed.name) {
        return ModelBundleStatus.verificationFailed;
      }
      if (s == ModelBundleStatus.downloaded.name) {
        return ModelBundleStatus.downloaded;
      }
    }

    final manifest = File('${d.path}${Platform.pathSeparator}manifest.json');
    if (await manifest.exists()) {
      return ModelBundleStatus.downloaded;
    }
    return ModelBundleStatus.notDownloaded;
  }

  /// Updates status and optional error message in bundle metadata.
  Future<void> setBundleStatus(
    String bundleKey,
    ModelBundleStatus status, {
    String? error,
  }) async {
    final meta = await readBundleMeta(bundleKey) ?? <String, dynamic>{};
    meta['status'] = status.name;
    if (error != null) {
      meta['verification_error'] = error;
    } else {
      meta.remove('verification_error');
    }

    if (status != ModelBundleStatus.verified) {
      final d = await versionDir(bundleKey);
      final verifiedFile =
          File('${d.path}${Platform.pathSeparator}verified.json');
      if (await verifiedFile.exists()) {
        await verifiedFile.delete();
      }
    }

    await writeBundleMeta(bundleKey, meta);
  }

  /// Deletes a bundle directory completely and resets active pointer if deleted.
  Future<void> deleteBundle(String bundleKey) async {
    final d = await versionDir(bundleKey);
    if (await d.exists()) {
      await d.delete(recursive: true);
    }

    final current = await activeVersion();
    if (current == bundleKey) {
      await _writePointer('ACTIVE', null);
    }

    final prev = await previousVersion();
    if (prev == bundleKey) {
      await _writePointer('PREVIOUS', null);
    }
  }

  /// Saves local metadata alongside the bundle for offline display.
  Future<void> writeBundleMeta(
    String bundleKey,
    Map<String, dynamic> meta,
  ) async {
    final d = await versionDir(bundleKey);
    if (!await d.exists()) return;
    final f = File('${d.path}${Platform.pathSeparator}$_metaFile');
    await f.writeAsString(jsonEncode(meta), flush: true);
  }

  /// Reads cached metadata for an installed bundle.
  Future<Map<String, dynamic>?> readBundleMeta(String bundleKey) async {
    final d = await versionDir(bundleKey);
    final f = File('${d.path}${Platform.pathSeparator}$_metaFile');
    if (!await f.exists()) return null;
    try {
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  /// Run once at startup: wipe `incoming/` and drop only *broken* staged dirs
  /// (no `manifest.json`).
  Future<void> startupCleanup() async {
    await wipeIncoming();
    await _pruneBroken();
  }

  Future<Directory> _incomingRoot() async {
    final d =
        Directory('${(await _root()).path}${Platform.pathSeparator}$_incoming');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<void> wipeIncoming() async {
    final d =
        Directory('${(await _root()).path}${Platform.pathSeparator}$_incoming');
    if (await d.exists()) await d.delete(recursive: true);
  }

  /// A clean `incoming/<name>/`.
  Future<Directory> freshIncomingDir(String name) async {
    final d = Directory(
      '${(await _incomingRoot()).path}${Platform.pathSeparator}$name',
    );
    if (await d.exists()) await d.delete(recursive: true);
    await d.create(recursive: true);
    return d;
  }

  /// Move `incoming/<incomingName>/` → `models/<version>/`, replacing any
  /// existing directory for that version.
  Future<void> promoteIncoming(String incomingName, {String? asVersion}) async {
    final version = asVersion ?? incomingName;
    final src = Directory(
      '${(await _incomingRoot()).path}${Platform.pathSeparator}$incomingName',
    );
    final dest = await versionDir(version);
    if (await dest.exists()) await dest.delete(recursive: true);
    await src.rename(dest.path);
  }

  /// Make [version] active. The prior active becomes PREVIOUS (for auto-rollback
  /// after a failed smoke test). Other staged bundles are kept.
  Future<void> activate(String version) async {
    final current = await activeVersion();
    if (current != null && current != version) {
      await _writePointer('PREVIOUS', current);
    }
    await _writePointer('ACTIVE', version);
  }

  /// Swap ACTIVE ↔ PREVIOUS. Returns the new active version.
  Future<String> rollback() async {
    final prev = await previousVersion();
    if (prev == null) {
      throw StateError('no previous bundle to roll back to');
    }
    final current = await activeVersion();
    await _writePointer('ACTIVE', prev);
    await _writePointer('PREVIOUS', current);
    return prev;
  }

  Future<void> clearAll() async {
    final d = await _root();
    if (await d.exists()) await d.delete(recursive: true);
  }

  Future<void> _pruneBroken() async {
    final root = await _root();
    await for (final e in root.list()) {
      if (e is! Directory) continue;
      final name = e.path.split(Platform.pathSeparator).last;
      if (name == _incoming) continue;
      final manifest = File('${e.path}${Platform.pathSeparator}manifest.json');
      if (!await manifest.exists()) {
        try {
          await e.delete(recursive: true);
        } catch (_) {}
      }
    }
  }
}
