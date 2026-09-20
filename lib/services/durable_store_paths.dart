import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// On-device root that **survives `adb uninstall`** (not under the app data tree).
///
/// Android: `/sdcard/zee-power-toys` (primary shared storage).
/// Desktop/tests: application-support `durable/` subfolder (still convenient).
const String kDurableAndroidRelative = 'zee-power-toys';

Future<Directory> durableZeeRoot() async {
  if (!kIsWeb && Platform.isAndroid) {
    // Prefer public shared storage — wiped only by user/media wipe, not uninstall.
    for (final candidate in const [
      '/sdcard/zee-power-toys',
      '/storage/emulated/0/zee-power-toys',
    ]) {
      final dir = Directory(candidate);
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        // Prove writable.
        final probe = File('${dir.path}/.write_probe');
        await probe.writeAsString('ok', flush: true);
        await probe.delete();
        return dir;
      } catch (_) {
        continue;
      }
    }
  }
  final support = await getApplicationSupportDirectory();
  final dir = Directory('${support.path}/durable');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<File> durableConfigFile() async {
  final root = await durableZeeRoot();
  return File('${root.path}/config.json');
}

Future<Directory> durableSpeedcamPacksDir() async {
  final root = await durableZeeRoot();
  final dir = Directory('${root.path}/speedcam_packs');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}
