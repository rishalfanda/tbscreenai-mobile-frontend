import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

/// Extract a bundle `.zip` into [destDir] on a background isolate.
///
/// Tolerates the archive wrapping everything in one top-level directory
/// (e.g. `bundle_v2026.09.04/manifest.json`) by stripping that prefix, and
/// refuses any entry that would escape [destDir].
Future<void> extractBundleZip(String zipPath, String destDir) =>
    compute(_extractZipSync, <String>[zipPath, destDir]);

void _extractZipSync(List<String> args) {
  final zipPath = args[0];
  final destDir = args[1];

  final bytes = File(zipPath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);

  // Find the prefix that precedes `manifest.json`, if any.
  var prefix = '';
  for (final f in archive.files) {
    final name = f.name.replaceAll('\\', '/');
    if (name == 'manifest.json') {
      prefix = '';
      break;
    }
    if (name.endsWith('/manifest.json')) {
      prefix = name.substring(0, name.length - 'manifest.json'.length);
    }
  }

  final root = Directory(destDir).absolute.path;
  for (final f in archive.files) {
    if (!f.isFile) continue;
    var name = f.name.replaceAll('\\', '/');
    if (prefix.isNotEmpty && name.startsWith(prefix)) {
      name = name.substring(prefix.length);
    } else if (prefix.isNotEmpty) {
      continue; // outside the bundle root
    }
    if (name.isEmpty || name.split('/').contains('..')) continue;

    final outFile = File('$destDir/$name');
    if (!outFile.absolute.path.startsWith(root)) continue;
    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(f.content as List<int>);
  }
}
