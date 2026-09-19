import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/car_signals.dart';
import '../services/config_store.dart';
import '../services/hud_host.dart';
import '../services/installer.dart';
import '../services/package_status.dart';
import '../services/speedcam.dart';
import '../services/speedcam_pack_store.dart';
import '../services/minimap_host.dart';
import '../services/system_config.dart';

/// Abstract service providers — injected via ProviderScope.overrides at startup.
/// Each isolate gets its own instance; never shared across isolates (ADR 0003).

final configStoreProvider = Provider<ConfigStore>((ref) {
  throw UnimplementedError('inject via ProviderScope.overrides');
});

final carSignalsProvider = Provider<CarSignals>((ref) {
  throw UnimplementedError('inject via ProviderScope.overrides');
});

final minimapHostProvider = Provider<MinimapHost>((ref) {
  throw UnimplementedError('inject via ProviderScope.overrides');
});

final hudHostProvider = Provider<HudHost>((ref) {
  throw UnimplementedError('inject via ProviderScope.overrides');
});

final installerProvider = Provider<Installer>((ref) {
  throw UnimplementedError('inject via ProviderScope.overrides');
});

final packageStatusProvider = Provider<PackageStatus>((ref) {
  throw UnimplementedError('inject via ProviderScope.overrides');
});

final systemConfigProvider = Provider<SystemConfig>((ref) {
  throw UnimplementedError('inject via ProviderScope.overrides');
});

final speedcamServiceProvider = Provider<SpeedcamService>((ref) {
  throw UnimplementedError('inject via ProviderScope.overrides');
});

final speedcamPackStoreProvider = Provider<SpeedcamPackStore>((ref) {
  throw UnimplementedError('inject via ProviderScope.overrides');
});

