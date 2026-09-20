import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/minimap_host.dart';
import 'services.dart';

/// Live YNavi trip guidance (street / ETA / turn). Empty until first event.
final guidanceEventsProvider = StreamProvider<GuidanceEvent>((ref) {
  return ref.watch(minimapHostProvider).guidance;
});

/// Latest guidance snapshot for HUD overlay paint.
final latestGuidanceProvider = Provider<GuidanceEvent?>((ref) {
  return ref.watch(guidanceEventsProvider).asData?.value;
});
