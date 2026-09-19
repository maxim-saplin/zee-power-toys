import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../hud/hud_root.dart';
import '../l10n/app_localizations.dart';
import '../providers/car_signals.dart';
import '../providers/config.dart';
import '../services/car_signals.dart';

/// The physical HUD backing display's pixel size at Zeekr S2 nominal geometry
/// — 1024×576 @ 213dpi (CONTEXT.md's Minimap glossary entry, and the basis of
/// [HudSafeArea]'s default fractions). The HUD's Presentation renders at
/// devicePixelRatio 1.0, so these are also the LOGICAL pixel dimensions
/// [HudRoot] lays out against on the real HUD.
///
/// [HudPreview] renders [HudRoot] at exactly this size before scaling the
/// result down to fit the on-screen preview box (see [HudPreview.build]).
/// That is what fixes the ~2.9x mark-size exaggeration bug: [BlinkerWidget]
/// and [BatteryWidget] size their marks from ABSOLUTE logical-px constants
/// (`kBlinkerBaseDiameter = 18.0`, `20.0 * sizeScale`), so those marks only
/// read at their true relative size when HudRoot is actually laid out at the
/// real HUD's pixel dimensions — laying it out at some other size (e.g. the
/// small preview box directly) makes the same absolute-px marks cover a much
/// bigger fraction of the (smaller) canvas.
const double kHudDisplayWidthPx = 1024.0;
const double kHudDisplayHeightPx = 576.0;

/// Which sub-rectangle of the backing display [HudPreview] shows.
enum HudPreviewMode {
  /// The Safe Area letterbox — the sub-rectangle actually visible through the
  /// projector optics, i.e. what the driver sees. This is the primary,
  /// default view: most of the full backing display is optically invisible,
  /// so showing it wastes preview space and crams the content the user cares
  /// about into a thin band.
  letterbox,

  /// The full backing display (Safe Area outlined). A secondary debug view —
  /// still useful for checking that content stays inside the Safe Area
  /// bounds as sliders are adjusted.
  fullDisplay,
}

/// Which mode badge [HudPreview] renders in its corner (see [HudPreviewBadge]
/// docs on each value for what drives the choice).
enum HudPreviewBadge {
  /// No badge — e.g. explicitly suppressed. Never used on the real HUD
  /// surface itself; [HudPreview] (and this badge) only ever appear in DHU
  /// preview contexts, never in the Presentation painted onto the windshield.
  none,

  /// "PREVIEW · DEMO" — [HudPreview]'s own Config Preview context: the
  /// CarSignal-driven providers are forced to a fixed demo scenario (see
  /// [_demoSignalOverrides]) so the preview is usable without a live/injected
  /// signal. This is the default.
  previewDemo,

  /// "LIVE · SIMULATED" — for the Developer Simulate screen's own live
  /// preview box (`simulate_screen.dart`'s `_LiveHudPreviewBox`), which reads
  /// the real, unforced CarSignal chain instead of overriding it. Wiring
  /// `_LiveHudPreviewBox` to pass this is a follow-up — that file is out of
  /// scope here; this enum value exists so the badge concept already covers
  /// both contexts.
  liveSimulated,
}

/// DHU preview of the HUD content.
///
/// Renders the SAME [HudRoot] widget subtree (ADR 0001 — the preview cannot
/// drift from the real HUD) at the real HUD's pixel dimensions
/// ([kHudDisplayWidthPx] × [kHudDisplayHeightPx]), then scales the result
/// down uniformly to fit the preview box. Background is grey to simulate the
/// heads-up display glass: on the real HUD, black = no light; here the grey
/// ground plane makes the black areas visible as an approximate
/// glass-on-glass simulation.
///
/// [mode] selects which sub-rectangle of that fixed canvas is shown:
/// [HudPreviewMode.letterbox] (default) crops to the Safe Area — the
/// ~3.52:1 (616:175dp) rectangle actually visible through the projector
/// optics — and fills the preview box with it. [HudPreviewMode.fullDisplay]
/// shows the whole canvas with the Safe Area outlined, a secondary debug view
/// for checking that content stays inside bounds.
///
/// The Safe Area rectangle is always outlined so layout calibration is
/// obvious in either mode.
///
/// CarSignal-driven content (blinker, charging) is forced to a fixed demo
/// scenario here — see [_demoSignalOverrides] — so this Config Preview is
/// usable without a live/injected car signal (Block 0026: split from the
/// Developer Simulate screen, which drives the real unforced signal chain).
/// This only overrides the signal providers for this subtree; config
/// providers (shape, size, Safe Area) fall through to the real root
/// container via Riverpod provider scoping, so edits made on the same
/// screen still update this preview live.
class HudPreview extends ConsumerWidget {
  const HudPreview({
    super.key,
    this.mode = HudPreviewMode.letterbox,
    this.badge = HudPreviewBadge.previewDemo,
    this.forceDemoSignals = true,
  });

  final HudPreviewMode mode;
  final HudPreviewBadge badge;

  /// Whether CarSignal-driven content is pinned to the fixed demo scenario.
  ///
  /// `true` (default) is the **Config Preview** behaviour: the preview always
  /// shows the configured look, with no live or injected signal needed.
  ///
  /// `false` reads the real, unforced signal chain — the **Developer Simulate**
  /// behaviour, where the point is to watch genuine live transitions (blink
  /// cadence, the charging panel appearing) as signals are injected. Pair it
  /// with [HudPreviewBadge.liveSimulated] so the surface says which it is.
  final bool forceDemoSignals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safeArea = ref.watch(safeAreaProvider);
    final l10n = AppLocalizations.of(context);

    final letterbox = mode == HudPreviewMode.letterbox;

    // The "raw" rect — in the fixed real-HUD canvas's own logical pixels —
    // that this preview shows. Letterbox: just the Safe Area sub-rectangle
    // (what the driver optically sees). Full display: the whole canvas.
    final double rawLeft = letterbox ? safeArea.left * kHudDisplayWidthPx : 0.0;
    final double rawTop = letterbox ? safeArea.top * kHudDisplayHeightPx : 0.0;
    final double rawWidth = letterbox
        ? (safeArea.right - safeArea.left) * kHudDisplayWidthPx
        : kHudDisplayWidthPx;
    final double rawHeight = letterbox
        ? (safeArea.bottom - safeArea.top) * kHudDisplayHeightPx
        : kHudDisplayHeightPx;

    return AspectRatio(
      aspectRatio: rawWidth / rawHeight,
      // The AspectRatio above always hands its child (this Stack) TIGHT
      // constraints equal to the fitted on-screen box, so the Stack itself is
      // exactly that box size regardless of what its children want.
      child: Stack(
        children: <Widget>[
          ClipRect(
            // FittedBox lays out its child at the child's OWN natural size
            // (rawWidth × rawHeight, from the SizedBox below — FittedBox gives
            // its child unbounded/loose constraints) and then scales the
            // whole painted result uniformly to fill FittedBox's own size
            // (the on-screen box, from the tight constraints above).
            // BoxFit.fill is safe here specifically because rawWidth/rawHeight
            // was chosen to already match the box's aspect ratio exactly (see
            // the AspectRatio above), so fill and contain are equivalent —
            // there's no distortion.
            //
            // This uniform scale-after-layout (not scale-then-clip) is what
            // fixes the ~2.9x mark-size exaggeration bug: laying HudRoot out
            // at the real HUD's pixel size first, then scaling the finished
            // painted result down, shrinks the absolute-dp blinker/battery
            // marks by the same factor as everything else (see
            // [kHudDisplayWidthPx] doc comment).
            //
            // NOTE: an earlier version of this widget used a hand-rolled
            // `Transform.scale` wrapped in `ClipRect` here instead of
            // `FittedBox`. That was a real bug: `Transform` only affects
            // painting, not layout size, so the surrounding `ClipRect` sized
            // itself to the UNSCALED child and clipped away most of the
            // scaled-up content. `FittedBox` does not have this problem — it
            // is designed exactly for "lay out at natural size, then scale to
            // fit," and was caught by rendering an actual PNG and looking at
            // it, not just by widget tests (which never assert on scale).
            child: FittedBox(
              fit: BoxFit.fill,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: rawWidth,
                height: rawHeight,
                child: ClipRect(
                  // Without this OverflowBox, the ClipRect above hands its OWN
                  // (small, rawWidth × rawHeight) size down as a TIGHT
                  // constraint through Transform.translate to the big
                  // kHudDisplayWidthPx × kHudDisplayHeightPx SizedBox below —
                  // which, given tight constraints smaller than its requested
                  // size, is FORCED to shrink to rawWidth × rawHeight instead
                  // of laying out at the real HUD's true pixel size. That
                  // squashed HudRoot into a tiny fraction of its real size, so
                  // its LayoutBuilder-driven Safe Area geometry was reduced to
                  // almost nothing — this was caught by an actual rendered
                  // PNG showing an empty letterbox (only the badge painted;
                  // every real widget test still passed, because none of them
                  // asserted that rendered content actually falls inside the
                  // clipped/visible region). OverflowBox forces its child to
                  // lay out at its own explicit (real, unshrunk) size
                  // regardless of the ClipRect's smaller reported size, while
                  // the ClipRect above still only PAINTS the rawWidth ×
                  // rawHeight window of it — exactly the crop this needs.
                  child: OverflowBox(
                    minWidth: kHudDisplayWidthPx,
                    maxWidth: kHudDisplayWidthPx,
                    minHeight: kHudDisplayHeightPx,
                    maxHeight: kHudDisplayHeightPx,
                    alignment: Alignment.topLeft,
                    child: Transform.translate(
                      offset: Offset(-rawLeft, -rawTop),
                      child: SizedBox(
                        width: kHudDisplayWidthPx,
                        height: kHudDisplayHeightPx,
                        child: Stack(
                          children: <Widget>[
                            // Grey ground — simulates the windshield glass. Because
                            // HudRoot is backdrop-agnostic (transparent except for
                            // emissive marks), this grey shows through wherever the
                            // real HUD would be black/transparent.
                            const ColoredBox(
                              color: Color(0xFF888888),
                              child: SizedBox.expand(),
                            ),

                            // The real HudRoot, laid out at the real HUD's pixel
                            // dimensions — so absolute-dp content (blinker/battery
                            // marks) reads at true relative scale once the whole
                            // subtree is scaled down to fit the preview box above.
                            // showSafeAreaBorder=true enables the MINIMAP slot
                            // glyph so it is visible in the preview; it is
                            // suppressed in production (showSafeAreaBorder=false,
                            // the default) to keep the windshield clean.
                            //
                            // Scoped override: only the live CarSignal providers
                            // are replaced with fixed demo values
                            // (_demoSignalOverrides) so the preview always shows
                            // the configured look. Everything else HudRoot reads
                            // (blinkerConfigProvider, batteryConfigProvider,
                            // safeAreaProvider, ...) is not overridden here, so
                            // Riverpod falls through to the real root container.
                            // When forceDemoSignals is false the ProviderScope
                            // is omitted entirely (not given an empty override
                            // list) so HudRoot reads the real signal chain
                            // directly — the Developer Simulate case.
                            if (forceDemoSignals)
                              ProviderScope(
                                overrides: _demoSignalOverrides,
                                // forceBlinkOn: demo hazard must stay lit —
                                // BlinkerWidget still runs the 450ms on/off
                                // cadence even when state is forced, so without
                                // this the Config Preview goes fully dark on
                                // the off half-cycle (keys remain; amber ink
                                // does not).
                                // forceDemoSpeedcam: Alien/CRT radar demo blip
                                // without FL inject (0033).
                                child: const HudRoot(
                                  showSafeAreaBorder: true,
                                  forceBlinkOn: true,
                                  forceDemoSpeedcam: true,
                                ),
                              )
                            else
                              // LIVE · SIMULATED (Developer Simulate): still
                              // forceBlinkOn so the in-DHU preview stays
                              // readable across the blink off-half. Real HUD
                              // isolate (HudRoot default, no forceBlinkOn)
                              // keeps genuine cadence. forceDemoSignals stays
                              // false — live CarSignals, not demo overrides.
                              const HudRoot(
                                showSafeAreaBorder: true,
                                forceBlinkOn: true,
                              ),

                            // Safe Area outline — always drawn (over HudRoot) so
                            // it is visible even when HudRoot's own internal
                            // border is transparent-enough to miss at a glance.
                            // In letterbox mode this hugs the preview's own
                            // edges; in full-display mode it marks the Safe Area
                            // within the wider canvas.
                            Positioned(
                              left: safeArea.left * kHudDisplayWidthPx,
                              top: safeArea.top * kHudDisplayHeightPx,
                              width:
                                  (safeArea.right - safeArea.left) *
                                  kHudDisplayWidthPx,
                              height:
                                  (safeArea.bottom - safeArea.top) *
                                  kHudDisplayHeightPx,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(
                                        0xFF00FFFF,
                                      ).withValues(alpha: 0.6),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ), // closes FittedBox
          ), // closes the outer ClipRect (safety clip around FittedBox's output)
          // Mode badge — drawn OUTSIDE the scaled/clipped HUD subtree so its
          // own text stays a fixed, readable on-screen size regardless of
          // preview zoom. Never rendered on the real HUD surface: this whole
          // widget only appears in DHU preview contexts.
          if (badge != HudPreviewBadge.none)
            Positioned(
              left: 6,
              top: 6,
              child: _PreviewBadge(
                key: const ValueKey('hud-preview-badge'),
                text: badge == HudPreviewBadge.previewDemo
                    ? l10n.hudPreviewBadgeDemo
                    : l10n.hudPreviewBadgeLive,
              ),
            ),
        ],
      ),
    );
  }
}

/// A small readable chip identifying what data the preview is showing —
/// demo, injected simulation, or (eventually) a real car — so the preview
/// never silently misleads about its own data source.
class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFEEEEEE),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

/// Fixed demo values for CarSignal-driven providers, scoped to [HudPreview]'s
/// nested [ProviderScope]. Untyped list literal: the `Override` return type of
/// `overrideWithValue` is not part of Riverpod's public export surface, so it
/// cannot be named directly (see `main.dart`'s root overrides for the same
/// pattern) — the list's element type is inferred instead.
///
/// hazard shows both left and right marks simultaneously so shape/size/side-
/// padding edits are checkable on both sides at once. Charging is forced on
/// with a plausible reading so the charging-stats panel (only ever shown
/// while charging, ADR 0003) is checkable here too.
final _demoSignalOverrides = [
  blinkerProvider.overrideWithValue(BlinkerState.hazard),
  chargingProvider.overrideWithValue(true),
  chargeKwProvider.overrideWithValue(7.4),
  batteryPctProvider.overrideWithValue(72),
  batteryTempCProvider.overrideWithValue(24.0),
];
