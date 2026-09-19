import 'package:flutter/material.dart';

/// Premium dark automotive theme + spacing/size tokens for the DHU.
///
/// The DHU is a *large, low-DPI* automotive touchscreen (~160dpi): one logical
/// pixel ≈ one physical pixel, so sizes must NOT be inflated the way a small
/// high-DPI phone tolerates.  The goal is crisp, modern, premium — legible at a
/// glance while driving — never an oversized "accessibility" look (P1: defaults
/// must be excellent).
///
/// Usage:
/// - DHU app: `theme: AppTheme.dhu`.
/// - Shared spacing/size constants: [Insets], [Radii], [Sizes].
/// - Brand colours other surfaces may reference: [AppColors].
///
/// The HUD is an emissive projector (black = transparent); it keeps a black
/// scaffold and does not use this ThemeData beyond inherited defaults.
abstract final class AppTheme {
  /// The DHU's ThemeData — a refined dark Material 3 theme.
  static final ThemeData dhu = _build();

  static ThemeData _build() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      // Hand-tuned neutrals for a deep, premium near-black instead of M3's
      // default purple-tinted darks — reads as glass/graphite on the DHU.
      surface: AppColors.surface,
      surfaceContainerLowest: AppColors.bg,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHigh,
      primary: AppColors.accent,
      onPrimary: AppColors.bg,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bg,
      // Compact density: at 160dpi the default 48dp tap targets feel bloated on
      // a wide display.  -1/-1 tightens vertical rhythm without harming touch.
      visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
      textTheme: _textTheme,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _textTheme.titleLarge,
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: const BorderSide(color: AppColors.outlineVariant),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.accent,
        contentPadding: EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.xs,
        ),
        minVerticalPadding: Insets.sm,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.bg
              : AppColors.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.surfaceContainerHigh,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.transparent
              : AppColors.outline,
        ),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.surfaceContainerHigh,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.12),
        // The value is already shown inline by [SettingsSlider] above the
        // track (always visible, never clipped) — the M3 value-indicator
        // bubble is pure redundancy and, at the DHU's 2.43x scale, overflows
        // the screen near the track ends. Suppress it here so no future
        // slider (discrete or continuous) can reintroduce the balloon.
        showValueIndicator: ShowValueIndicator.never,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.bg,
          elevation: 0,
          textStyle: _textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: Insets.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button),
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: _textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: Insets.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.outline),
          textStyle: _textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: Insets.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: _textTheme.labelLarge,
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(_textTheme.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.accent
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.bg
                : AppColors.onSurface,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.outline),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.button),
            ),
          ),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.surfaceContainerHigh,
        linearMinHeight: 4,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceContainerHigh,
        contentTextStyle: _textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
        ),
      ),
    );
  }

  /// Type scale tuned for a large 160dpi automotive screen: confident but
  /// restrained.  Sizes sit close to Material defaults (NOT inflated); the
  /// premium feel comes from weight, spacing and colour, not bulk.
  static const TextTheme _textTheme = TextTheme(
    titleLarge: TextStyle(
      fontSize: 20,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: AppColors.onSurface,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.25,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: AppColors.onSurface,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: AppColors.onSurface,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      height: 1.35,
      fontWeight: FontWeight.w400,
      color: AppColors.onSurface,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w400,
      color: AppColors.onSurface,
    ),
    bodySmall: TextStyle(
      fontSize: 12.5,
      height: 1.3,
      fontWeight: FontWeight.w400,
      color: AppColors.onSurfaceVariant,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: AppColors.onSurface,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
      color: AppColors.onSurfaceVariant,
    ),
  );
}

/// Brand + surface palette.  A deep graphite near-black with a cool premium
/// accent — Zeekr-flavoured, automotive, not stock-Material purple.
abstract final class AppColors {
  /// App background — deep near-black graphite (emissive-friendly neighbour).
  static const Color bg = Color(0xFF0C0E12);

  /// Base surface, one step up from [bg].
  static const Color surface = Color(0xFF14171D);

  /// Card / container fill.
  static const Color surfaceContainer = Color(0xFF181C23);

  /// Raised container (track backgrounds, pressed states).
  static const Color surfaceContainerHigh = Color(0xFF232831);

  /// Cool premium accent — Zeekr electric cyan-blue.
  static const Color accent = Color(0xFF35C2E8);

  /// Primary text on dark surfaces.
  static const Color onSurface = Color(0xFFECEFF3);

  /// Secondary / muted text and icons.
  static const Color onSurfaceVariant = Color(0xFF9AA3AF);

  /// Hairline borders on interactive elements.
  static const Color outline = Color(0xFF39414C);

  /// Subtle separators / card edges.
  static const Color outlineVariant = Color(0xFF262C34);
}

/// Spacing tokens (logical px ≈ physical px at 160dpi).  Use these instead of
/// ad-hoc EdgeInsets/SizedBox values so the DHU keeps a consistent rhythm.
abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner-radius tokens.
abstract final class Radii {
  static const double button = 10;
  static const double card = 14;
}

/// Common component sizes (icons, etc.) — shared so screens stay consistent.
abstract final class Sizes {
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;
}
