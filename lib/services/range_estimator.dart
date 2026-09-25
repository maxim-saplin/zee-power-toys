import 'dart:convert';
import 'dart:math' as math;

/// 0105 — Own estimated range from rolling EWMA Wh/km (not Adapt OEM range).
///
/// Formula (documented in issue Reconciliation):
///   usablePackWh = [kUsablePackWh] (single pack constant — never OEM range)
///   while moving (speed ≥ [kMinMovingSpeedKmh]) and not charging:
///     dist_km += speed_kmh × Δt_h   (Δt capped; large gaps drop the interval)
///     energy_Wh = −ΔSoC/100 × usablePackWh
///       (SoC↓ = consume; SoC↑ while moving = regen, valid drive sample)
///     when segment ≥ [kMinSegmentKm] and |ΔSoC| ≥ [kMinSocDeltaPct]:
///       sample_Wh_per_km = energy_Wh / segment_km
///       ewma = α·sample + (1−α)·ewma
///   ready when movingKmAccum ≥ [kMinMovingKmBeforeShow] and ewma set
///   range_km = (SoC/100)×usablePackWh / ewma   (floored, step-capped)
///
/// Adapt efficiency kWh/100km may **seed** ewma once; HUD primary stays ours.
class RangeEstimator {
  RangeEstimator({
    this.usablePackWh = kUsablePackWh,
    this.minMovingSpeedKmh = kMinMovingSpeedKmh,
    this.minMovingKmBeforeShow = kMinMovingKmBeforeShow,
    this.minSegmentKm = kMinSegmentKm,
    this.minSocDeltaPct = kMinSocDeltaPct,
    this.ewmaAlpha = kEwmaAlpha,
    this.maxGapSeconds = kMaxGapSeconds,
    this.maxStepKmPerMinute = kMaxStepKmPerMinute,
  });

  /// Zeekr 001-class usable pack energy (Wh). One constant — not OEM range.
  static const double kUsablePackWh = 100000; // 100 kWh

  static const double kMinMovingSpeedKmh = 3.0;
  static const double kMinMovingKmBeforeShow = 5.0;
  static const double kMinSegmentKm = 0.25;
  static const double kMinSocDeltaPct = 0.4;
  static const double kEwmaAlpha = 0.18;
  static const double kMaxGapSeconds = 25.0;
  static const double kMaxStepKmPerMinute = 12.0;

  /// Adapt Energy Cons 1 (`0x00103100`) kWh/100km — reject sentinels.
  static bool isValidEfficiencyKwhPer100km(double? v) {
    if (v == null || v.isNaN || v.isInfinite) return false;
    if (v <= 0 || v >= 200) return false; // 255-style / nonsense
    return true;
  }

  final double usablePackWh;
  final double minMovingSpeedKmh;
  final double minMovingKmBeforeShow;
  final double minSegmentKm;
  final double minSocDeltaPct;
  final double ewmaAlpha;
  final double maxGapSeconds;
  final double maxStepKmPerMinute;

  DateTime? _lastTick;
  int? _lastSocPct;
  double _segmentKm = 0;
  double? _segmentSocStart;
  double _movingKmAccum = 0;
  double? _ewmaWhPerKm;
  int? _lastShownKm;
  DateTime? _lastShownAt;
  bool _seededFromAdapt = false;

  double get movingKmAccum => _movingKmAccum;
  double? get ewmaWhPerKm => _ewmaWhPerKm;
  bool get ready =>
      _ewmaWhPerKm != null &&
      _ewmaWhPerKm! > 0 &&
      _movingKmAccum >= minMovingKmBeforeShow;

  /// Persistable state (prefs JSON).
  Map<String, Object?> toPersistJson() => <String, Object?>{
        'movingKmAccum': _movingKmAccum,
        'ewmaWhPerKm': _ewmaWhPerKm,
        'lastShownKm': _lastShownKm,
        'seededFromAdapt': _seededFromAdapt,
      };

  void restoreFromPersistJson(Map<String, Object?> json) {
    _movingKmAccum = (json['movingKmAccum'] as num?)?.toDouble() ?? 0;
    final ewma = (json['ewmaWhPerKm'] as num?)?.toDouble();
    _ewmaWhPerKm = (ewma != null && ewma > 0) ? ewma : null;
    _lastShownKm = (json['lastShownKm'] as num?)?.toInt();
    _seededFromAdapt = json['seededFromAdapt'] as bool? ?? false;
    // Live segment clocks reset — do not invent continuity across death.
    _lastTick = null;
    _lastSocPct = null;
    _segmentKm = 0;
    _segmentSocStart = null;
  }

  String encodePersist() => jsonEncode(toPersistJson());

  void decodePersist(String? raw) {
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        restoreFromPersistJson(Map<String, Object?>.from(decoded));
      }
    } catch (_) {
      // Corrupt prefs — start fresh.
    }
  }

  /// Optional Adapt seed (kWh/100km → Wh/km). Does **not** mark ready alone.
  void maybeSeedFromAdaptEfficiency(double? kwhPer100km) {
    if (_seededFromAdapt || _ewmaWhPerKm != null) return;
    if (!isValidEfficiencyKwhPer100km(kwhPer100km)) return;
    _ewmaWhPerKm = kwhPer100km! * 10.0; // kWh/100km → Wh/km
    _seededFromAdapt = true;
  }

  /// Ingest one sample. Returns rounded km to show, or null if not ready.
  int? ingest({
    required DateTime now,
    int? socPct,
    int? speedKmh,
    bool charging = false,
    double? efficiencyKwhPer100km,
  }) {
    maybeSeedFromAdaptEfficiency(efficiencyKwhPer100km);

    final last = _lastTick;
    _lastTick = now;

    if (socPct != null) {
      _lastSocPct ??= socPct;
      _segmentSocStart ??= socPct.toDouble();
    }

    if (last == null) {
      return _displayRange(socPct, now);
    }

    final dtSec = now.difference(last).inMilliseconds / 1000.0;
    if (dtSec <= 0) return _displayRange(socPct, now);

    // Large gap → drop interval (no distance, no sample).
    if (dtSec > maxGapSeconds) {
      _resetSegment(socPct);
      return _displayRange(socPct, now);
    }

    final speed = (speedKmh ?? 0).toDouble();
    final moving = !charging && speed >= minMovingSpeedKmh;

    if (moving) {
      final distKm = speed * (dtSec / 3600.0);
      _segmentKm += distKm;
      _movingKmAccum += distKm;
      _tryCloseSegment(socPct);
    } else if (charging) {
      // Plugged-in charge: ignore — reset segment clocks only.
      _resetSegment(socPct);
    } else {
      // Idle / crawling: keep last SoC anchor but do not accumulate.
      _resetSegment(socPct);
    }

    if (socPct != null) _lastSocPct = socPct;
    return _displayRange(socPct, now);
  }

  void _resetSegment(int? socPct) {
    _segmentKm = 0;
    _segmentSocStart = socPct?.toDouble() ?? _lastSocPct?.toDouble();
  }

  void _tryCloseSegment(int? socPct) {
    if (socPct == null || _segmentSocStart == null) return;
    if (_segmentKm < minSegmentKm) return;

    final socDelta = _segmentSocStart! - socPct; // + = consumed, − = regen
    // Drop near-zero SoCΔ (noise): do not close a sample yet — keep the
    // segment open so distance keeps accumulating until |ΔSoC| clears the floor.
    if (socDelta.abs() < minSocDeltaPct) {
      return;
    }

    // energy_Wh: SoC↓ → positive; SoC↑ while moving (regen) → negative (valid).
    final energyWh = socDelta / 100.0 * usablePackWh;
    final sample = energyWh / _segmentKm;
    // Reject absurd samples (sensor glitches).
    if (sample.isNaN || sample.isInfinite || sample.abs() > 2000) {
      _resetSegment(socPct);
      return;
    }

    if (_ewmaWhPerKm == null) {
      // First real sample: if regen-only (negative), wait for consume bias.
      if (sample <= 0) {
        _resetSegment(socPct);
        return;
      }
      _ewmaWhPerKm = sample;
    } else {
      // Blend; clamp EWMA to positive so range stays defined.
      final next = ewmaAlpha * sample + (1 - ewmaAlpha) * _ewmaWhPerKm!;
      _ewmaWhPerKm = math.max(20.0, next); // floor ~20 Wh/km (= 2 kWh/100km)
    }

    _segmentKm = 0;
    _segmentSocStart = socPct.toDouble();
  }

  int? _displayRange(int? socPct, DateTime now) {
    if (!ready || socPct == null) return null;
    final ewma = _ewmaWhPerKm!;
    final raw = (socPct / 100.0) * usablePackWh / ewma;
    if (raw.isNaN || raw.isInfinite || raw < 1) return null;
    var km = raw.round().clamp(1, 999);

    final prev = _lastShownKm;
    final prevAt = _lastShownAt;
    if (prev != null && prevAt != null) {
      final elapsedMin =
          now.difference(prevAt).inMilliseconds / 60000.0;
      final maxStep = math.max(1.0, maxStepKmPerMinute * math.max(elapsedMin, 1 / 60));
      final delta = km - prev;
      if (delta.abs() > maxStep) {
        km = (prev + maxStep * delta.sign).round();
      }
    }
    _lastShownKm = km;
    _lastShownAt = now;
    return km;
  }

  /// Test helper: force ready state after a synthetic trip.
  void debugForceState({
    required double movingKm,
    required double ewmaWhPerKm,
    int? lastShownKm,
  }) {
    _movingKmAccum = movingKm;
    _ewmaWhPerKm = ewmaWhPerKm;
    _lastShownKm = lastShownKm;
  }
}
