# Speedcam pack map clustering (0101)

## Verdict
**GO** — custom zoom-grid clusters in `lib/widgets/speedcam_pack_map_preview.dart`. No `flutter_map_marker_cluster` (or other) dependency.

## Mechanism
1. After map ready, keep cams in `visibleBounds` (+ 20% pad).
2. Bucket by cell size `clusterCellDegrees(zoom)` (~52 px screen radius in degrees).
3. Bucket size 1 → 0100 cam dot + 0093 sheet tap; size >1 → count bubble; tap fits member bounds.
4. If node count would exceed `kMaxMarkers`, widen radius (do not silently drop cams).

## Do not
- Regress 0100 zoom-aware dot / hit sizing.
- Open the metadata sheet on multi-cam cluster taps (zoom/expand only).
- Add a cluster plugin unless animations / spiderfy become a product ask.
