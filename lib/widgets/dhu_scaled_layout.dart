import 'package:flutter/material.dart';

/// Computes the smart UI scale factor for the DHU's low-DPI high-resolution
/// display (2560×1600 @ 160 dpi, devicePixelRatio ≈ 1.0).
///
/// Heuristic: dpr < 2.0 AND logicalWidth >= 1600 → automotive / IVI.
/// (Phones are high-DPI so never match; tablets with dpr < 2 typically have
/// narrower logical widths.)
///
/// For the Zeekr DHU (2560 logical px, dpr 1.0):
///   target = 800 dp → scale = (2560 / 800).clamp(1.0, 3.0) = **3.0**.
double dhuSmartScale(double logicalWidth, double devicePixelRatio) {
  if (logicalWidth <= 0 || !logicalWidth.isFinite) return 1.0;
  final bool automotive = devicePixelRatio < 2.0 && logicalWidth >= 1600;
  if (!automotive) return 1.0;
  return (logicalWidth / 800.0).clamp(1.0, 3.0);
}

/// Wraps its [child] in a [Transform.scale] to compensate for the DHU's
/// low-DPI high-resolution display (2560×1600 @ 160 dpi, dpr ≈ 1.0).
///
/// How it works:
///   1. Measures the available canvas via [LayoutBuilder].
///   2. Derives a scale factor from the logical width and devicePixelRatio.
///   3. Scale ≈ 1.0 → passes the child through unmodified (no overhead on
///      regular screens; widget tests at normal test-size stay green).
///   4. Otherwise: [Transform.scale] anchored top-left + a [SizedBox] sized to
///      the post-scale logical dims + a [MediaQuery] override so descendants
///      read the correct smaller logical dimensions.
///
/// Only applied to the DHU surface — the HUD uses fixed Safe-Area fractional
/// layout and must NOT be scaled (see [HudApp]).
class DhuScaledLayout extends StatelessWidget {
  const DhuScaledLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;

        // Guard: zero or infinite constraints (unbounded scrollable parent,
        // widget-test harness with no size, etc.) → pass through unchanged.
        if (!w.isFinite || !h.isFinite || w <= 0 || h <= 0) return child;

        final double dpr = MediaQuery.devicePixelRatioOf(context);
        final double scale = dhuSmartScale(w, dpr);

        // Near-1.0 → no-op: covers test sizes and non-automotive screens.
        if ((scale - 1.0).abs() < 0.01) return child;

        final double logicalW = w / scale;
        final double logicalH = h / scale;
        final MediaQueryData mq = MediaQuery.of(context);

        return SizedBox(
          width: w,
          height: h,
          child: ClipRect(
            child: Align(
              alignment: Alignment.topLeft,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: logicalW,
                  height: logicalH,
                  child: MediaQuery(
                    data: mq.copyWith(
                      size: Size(logicalW, logicalH),
                      padding: mq.padding / scale,
                      viewInsets: mq.viewInsets / scale,
                      viewPadding: mq.viewPadding / scale,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
