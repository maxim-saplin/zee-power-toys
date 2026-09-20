import 'package:flutter/material.dart';

import '../services/minimap_host.dart';

/// Flutter stand-in for YNavi's street + ETA chrome.
///
/// Root cause (0055): [MinimapHost] crops/scales the YNavi surface
/// (`minimapScale` / letterbox). Native guidance chrome (street name, ETA
/// panel) sits at the letterboxed edges and is clipped out of the HUD square.
/// Trip data still arrives via [GuidanceEvent]; this widget paints street +
/// ETA on the Flutter overlay so Zee HUD 2 parity is restored without
/// depending on uncropped native chrome.
class MinimapGuidanceOverlay extends StatelessWidget {
  const MinimapGuidanceOverlay({
    super.key,
    required this.event,
    this.compact = true,
  });

  final GuidanceEvent event;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final street = event.roadName?.trim();
    final eta = event.etaMin;
    final dist = event.distanceM;
    if ((street == null || street.isEmpty) && eta == null && dist == null) {
      return const SizedBox.shrink();
    }

    final String? etaLabel = eta == null
        ? null
        : (eta < 60 ? '$eta min' : '${eta ~/ 60} h ${eta % 60} m');
    final String? distLabel = dist == null
        ? null
        : (dist >= 1000
            ? '${(dist / 1000).toStringAsFixed(1)} km'
            : '$dist m');

    final parts = <String>[
      if (street != null && street.isNotEmpty) street,
      if (distLabel != null) distLabel,
      if (etaLabel != null) 'ETA $etaLabel',
    ];

    return Semantics(
      key: const ValueKey('hud-minimap-guidance'),
      label: parts.join(', '),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Emissive HUD: dim plate so text reads on windshield; not a light card.
          color: const Color(0xFF000000).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFF7CFF6B).withValues(alpha: 0.55),
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 10,
            vertical: compact ? 3 : 6,
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Color(0xFFE8FFE0),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.15,
              shadows: [
                Shadow(blurRadius: 4, color: Color(0xFF000000)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (street != null && street.isNotEmpty)
                  Text(
                    street,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: compact ? 11 : 14),
                  ),
                if (distLabel != null || etaLabel != null)
                  Text(
                    [
                      if (distLabel != null) distLabel,
                      if (etaLabel != null) 'ETA $etaLabel',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFB8FFA8),
                      fontSize: compact ? 10 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
