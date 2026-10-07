import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The on-device model-bundle store:
///
/// ```
/// <appSupport>/models/
///   ACTIVE          text: the active bundle_version
///   PREVIOUS        text: the rollback target
///   incoming/       in-flight download + staging (wiped on startup)
///   <version>/      a fully-verified staged bundle
/// ```
///
/// Bundles are downloaded, signature-verified and staged by
/// `lib/data/models_ota/model_update_pipeline.dart`; this type only manages the
/// on-disk layout. Stateless: every method reads/writes the filesystem.
class ModelStore {
  static const _dirName = 'models';
  static const _incoming = 'incoming';

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
    final v = await activeVersion();
    if (v == null) return null;
    final d = await versionDir(v);
    final manifest = File('${d.path}${Platform.pathSeparator}manifest.json');
    if (!await d.exists() || !await manifest.exists()) return null;
    return d;
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
