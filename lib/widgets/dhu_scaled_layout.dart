import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';

/// Zeekr DHU design framebuffer (reported metrics).
const double kDhuDesignLogicalWidth = 2560.0;
const double kDhuDesignLogicalHeight = 1600.0;
const double kDhuReportedDevicePixelRatio = 1.0;

/// Computes the smart UI scale factor for the DHU's low-DPI high-resolution
/// display (2560×1600 @ 160 dpi, devicePixelRatio ≈ 1.0).
///
/// Heuristic: dpr < 2.0 AND logicalWidth >= 1600 → automotive / IVI.
/// (Phones are high-DPI so never match; tablets with dpr < 2 typically have
/// narrower logical widths.)
///
/// For the Zeekr DHU (2560 logical px, dpr 1.0):
///   target = 800 dp → scale = (2560 / 800).clamp(1.0, 2.19) = **2.19** (~10% smaller than the prior 2.43 cap; ~27% smaller than original 3.0).
double dhuSmartScale(double logicalWidth, double devicePixelRatio) {
  if (logicalWidth <= 0 || !logicalWidth.isFinite) return 1.0;
  final bool automotive = devicePixelRatio < 2.0 && logicalWidth >= 1600;
  if (!automotive) return 1.0;
  return (logicalWidth / 800.0).clamp(1.0, 2.19);
}

/// True when [devicePixelRatio] + [logicalWidth] match the DHU / IVI gate.
bool dhuIsAutomotiveSurface({
  required double devicePixelRatio,
  required double logicalWidth,
}) {
  return devicePixelRatio < 2.0 && logicalWidth >= 1600;
}

/// Design framebuffer metrics for Alien DPI bridge + friends.
///
/// [DhuScaledLayout] publishes this so painters can use the **pre-scale**
/// DHU width / reported dpr even after the smart-scale MediaQuery shrinks
/// [MediaQuery.size]. HUD isolate does not publish this → bridge identity.
class DhuSurfaceMetrics extends InheritedWidget {
  const DhuSurfaceMetrics({
    super.key,
    required this.designLogicalWidth,
    required this.reportedDevicePixelRatio,
    required super.child,
  });

  /// Full DHU logical width (e.g. 2560), not the post-smart-scale canvas.
  final double designLogicalWidth;

  /// Android-reported dpr on the car (~1.0), or the T1-emulated value.
  final double reportedDevicePixelRatio;

  static DhuSurfaceMetrics? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DhuSurfaceMetrics>();
  }

  @override
  bool updateShouldNotify(DhuSurfaceMetrics oldWidget) {
    return oldWidget.designLogicalWidth != designLogicalWidth ||
        oldWidget.reportedDevicePixelRatio != reportedDevicePixelRatio;
  }
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
/// **T1 Mac honesty (0080):** host dpr ≥ 2 (Retina desktop) never matches the
/// automotive gate, so without emulation both Mac windows stayed at
/// `alienDhuDpiBridge = 1.0`. On that host we letterbox the design
/// framebuffer (2560×1600 @ reported dpr 1.0) into the window, then apply the
/// same smart scale as the car — so DHU Alien sees bridge ≈ 1.254 while the
/// HUD isolate (no [DhuScaledLayout]) stays gold identity.
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

        final mq = MediaQuery.of(context);
        final hostDpr = mq.devicePixelRatio;
        final view = View.of(context);
        final viewLogicalW = view.physicalSize.width / view.devicePixelRatio;

        // Real car / Tablet_12L: wide + low reported dpr.
        if (dhuIsAutomotiveSurface(
          devicePixelRatio: hostDpr,
          logicalWidth: viewLogicalW.isFinite ? viewLogicalW : w,
        )) {
          return _automotiveScaled(
            context: context,
            canvasW: w,
            canvasH: h,
            designW: viewLogicalW.isFinite && viewLogicalW >= 1600
                ? viewLogicalW
                : w,
            reportedDpr: hostDpr,
            mq: mq,
            child: child,
          );
        }

        // T1 Mac / Retina desktop ONLY: emulate DHU reported metrics in-window.
        // Never on Android — Tablet_12L is dens 320 (dpr 2) × 2560×1600 physical
        // → logical ~1280×800 landscape, which falsely matched this gate and
        // letterboxed the DHU design (0082 black side bars + status chrome).
        final viewLogicalH = view.physicalSize.height / view.devicePixelRatio;
        final bool isDesktopHost = !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.linux ||
                defaultTargetPlatform == TargetPlatform.windows);
        final bool retinaDesktopHost = isDesktopHost &&
            hostDpr >= 2.0 &&
            viewLogicalW.isFinite &&
            viewLogicalW >= 900 &&
            viewLogicalH.isFinite &&
            viewLogicalW >= viewLogicalH * 0.9; // landscape-ish desktop window
        if (retinaDesktopHost) {
          return _macEmulatedDhu(
            context: context,
            windowW: w,
            windowH: h,
            mq: mq,
            child: child,
          );
        }

        return child;
      },
    );
  }

  /// Letterbox 2560×1600 @ dpr 1.0 into the Mac window, then smart-scale.
  static Widget _macEmulatedDhu({
    required BuildContext context,
    required double windowW,
    required double windowH,
    required MediaQueryData mq,
    required Widget child,
  }) {
    const designW = kDhuDesignLogicalWidth;
    const designH = kDhuDesignLogicalHeight;
    const reportedDpr = kDhuReportedDevicePixelRatio;
    final fit = math.min(windowW / designW, windowH / designH);
    return SizedBox(
      width: windowW,
      height: windowH,
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: SizedBox(
            width: designW * fit,
            height: designH * fit,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: designW,
                height: designH,
                child: MediaQuery(
                  data: mq.copyWith(
                    size: const Size(designW, designH),
                    devicePixelRatio: reportedDpr,
                  ),
                  child: _automotiveScaled(
                    context: context,
                    canvasW: designW,
                    canvasH: designH,
                    designW: designW,
                    reportedDpr: reportedDpr,
                    mq: mq.copyWith(
                      size: const Size(designW, designH),
                      devicePixelRatio: reportedDpr,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _automotiveScaled({
    required BuildContext context,
    required double canvasW,
    required double canvasH,
    required double designW,
    required double reportedDpr,
    required MediaQueryData mq,
    required Widget child,
  }) {
    final scale = dhuSmartScale(designW, reportedDpr);

    final wrapped = DhuSurfaceMetrics(
      designLogicalWidth: designW,
      reportedDevicePixelRatio: reportedDpr,
      child: child,
    );

    // Near-1.0 → metrics only (bridge still sees design width).
    if ((scale - 1.0).abs() < 0.01) {
      return MediaQuery(
        data: mq.copyWith(
          size: Size(canvasW, canvasH),
          devicePixelRatio: reportedDpr,
        ),
        child: wrapped,
      );
    }

    final logicalW = canvasW / scale;
    final logicalH = canvasH / scale;

    return SizedBox(
      width: canvasW,
      height: canvasH,
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
                  devicePixelRatio: reportedDpr,
                  padding: mq.padding / scale,
                  viewInsets: mq.viewInsets / scale,
                  viewPadding: mq.viewPadding / scale,
                ),
                child: wrapped,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
