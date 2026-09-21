
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/config_store.dart';
import '../services/minimap_host.dart';
import 'config.dart';
import 'services.dart';

/// Live YNavi trip guidance (street / ETA / turn). Empty until first event.
final guidanceEventsProvider = StreamProvider<GuidanceEvent>((ref) {
  return ref.watch(minimapHostProvider).guidance;
});

/// Latest guidance snapshot for HUD overlay paint.
final latestGuidanceProvider = Provider<GuidanceEvent?>((ref) {
  return ref.watch(guidanceEventsProvider).asData?.value;
});

/// YNavi navigation-session truth (0057). Relayed DHU→HUD via zee/hub.
final navigationActiveProvider = StreamProvider<bool>((ref) {
  return ref.watch(minimapHostProvider).navigationActive;
});

/// Whether the minimap surface / HUD chrome should show (0057).
final minimapSurfaceActiveProvider = Provider<bool>((ref) {
  final mm = ref.watch(minimapConfigProvider);
  final nav = ref.watch(navigationActiveProvider).asData?.value ?? false;
  return minimapSurfaceWanted(mm, navActive: nav);
});
