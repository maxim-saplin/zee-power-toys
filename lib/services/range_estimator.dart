import 'dart:convert';
import 'dart:math' as math;

/// One accepted moving-driving sample in the honesty window (0108).
class DriveSegment {
  const DriveSegment({required this.distanceKm, required this.energyWh});

  final double distanceKm;
  final double energyWh; // SoC↓ → positive consume; SoC↑ regen → negative

  Map<String, Object?> toJson() => <String, Object?>{
        'd': distanceKm,
        'e': energyWh,
      };

  static DriveSegment? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final d = (raw['d'] as num?)?.toDouble();
    final e = (raw['e'] as num?)?.toDouble();
    if (d == null || e == null || d <= 0 || d.isNaN || e.isNaN) return null;
    if (d.isInfinite || e.isInfinite) return null;
    return DriveSegment(distanceKm: d, energyWh: e);
  }
}

/// 0108/0117 — Own estimated range from a weighted ~50 km moving-driving window
/// (supersedes 0105 opaque EWMA). Not the Adapt OEM range.
///
/// ```
/// usablePackWh = 100000
/// segmentWh = −ΔSoC/100 × usablePackWh
/// bands (distance from now): 0..1 → 0 (mute); 1..5 → 8×/km; 5..50 → 1×/km
/// weightedWhPerKm = Σ(w·Wh) / Σ(w·km)
/// rangeKm = (SoC/100)×usablePackWh / weightedWhPerKm
/// ```
///
/// Display publishes ~every 1 km of moving distance. Ready at ≥~5 km window.
/// Segments stay open while Wh/km exceeds [maxAbsWhPerKm] so a SoC tick on
/// a short hop cannot peak-band dominate the window (0114). Own Est. uses
/// float SoC (0118); Adapt Cons1 never seeds the own-window path — Cons Est.
/// is a separate figure (0118 dual Est.).
class RangeEstimator {
  RangeEstimator({
    this.usablePackWh = kUsablePackWh,
    this.minMovingSpeedKmh = kMinMovingSpeedKmh,
    this.minMovingKmBeforeShow = kMinMovingKmBeforeShow,
    this.minSegmentKm = kMinSegmentKm,
    this.minSocDeltaPct = kMinSocDeltaPct,
    this.maxGapSeconds = kMaxGapSeconds,
    this.windowKm = kWindowKm,
    this.displayRefreshKm = kDisplayRefreshKm,
    this.bandMuteKm = kBandMuteKm,
    this.bandPeakKm = kBandPeakKm,
    this.weightMute = kWeightMute,
    this.weightPeak = kWeightPeak,
    this.weightOlder = kWeightOlder,
    this.minWhPerKmFloor = kMinWhPerKmFloor,
    this.maxAbsWhPerKm = kMaxAbsWhPerKm,
  });

  /// Zeekr 001-class usable pack energy (Wh). One constant — not OEM range.
  static const double kUsablePackWh = 100000; // 100 kWh

  static const double kMinMovingSpeedKmh = 3.0;
  static const double kMinMovingKmBeforeShow = 5.0;
  static const double kMinSegmentKm = 0.25;
  static const double kMinSocDeltaPct = 0.4;
  static const double kMaxGapSeconds = 25.0;
  static const double kWindowKm = 50.0;
  static const double kDisplayRefreshKm = 1.0;
  /// 0117 — last 1 km from now contributes zero weight (mute short-hop noise).
  static const double kBandMuteKm = 1.0;
  /// 0117 — 1..5 km peak band at 8×.
  static const double kBandPeakKm = 5.0;
  static const double kWeightMute = 0.0;
  static const double kWeightPeak = 8.0;
  static const double kWeightOlder = 1.0;
  static const double kMinWhPerKmFloor = 20.0; // ~2 kWh/100km
  /// Hard ceiling for an accepted sample (Wh/km). A 1% SoC step is 1000 Wh
  /// on [kUsablePackWh]; with a looser cap (e.g. 2000) a 1% tick over 0.5 km
  /// was accepted at 2000 Wh/km, then peak-weighted in the recent band — the
  /// 0114 short-trip cliff (218→173 after 2.7 km). ~50 kWh/100 is above real
  /// winter/spirited driving and still dilutes a 1% step over ≥2 km.
  /// Float SoC (0118) softens quantum noise but the cap stays.
  static const double kMaxAbsWhPerKm = 500.0;

  /// Soft Cons Est. refresh — same ~1 km cadence as own (don't thrash on Cons ticks).
  static const double kConsDisplayRefreshKm = 1.0;

  /// Adapt Energy Cons 1 (`0x00103100`) kWh/100km — reject sentinels.
  static bool isValidEfficiencyKwhPer100km(double? v) {
    if (v == null || v.isNaN || v.isInfinite) return false;
    if (v <= 0 || v >= 200) return false;
    return true;
  }

  final double usablePackWh;
  final double minMovingSpeedKmh;
  final double minMovingKmBeforeShow;
  final double minSegmentKm;
  final double minSocDeltaPct;
  final double maxGapSeconds;
  final double windowKm;
  final double displayRefreshKm;
  final double bandMuteKm;
  final double bandPeakKm;
  final double weightMute;
  final double weightPeak;
  final double weightOlder;
  final double minWhPerKmFloor;
  final double maxAbsWhPerKm;

  DateTime? _lastTick;
  double? _lastSocPct;
  double _segmentKm = 0;
  double? _segmentSocStart;
  double _movingKmAccum = 0;
  final List<DriveSegment> _history = <DriveSegment>[];
  double _historyKm = 0;
  double? _weightedWhPerKm;
  int? _lastShownKm;
  double _distanceAtLastPublish = 0;
  bool _hasPublished = false;
  int? _lastShownConsKm;
  double _distanceAtLastConsPublish = 0;
  bool _hasPublishedCons = false;
  double? _lastConsUsedForDisplay;

  double get movingKmAccum => _movingKmAccum;
  double get historyKm => _historyKm;
  double? get weightedWhPerKm => _weightedWhPerKm;
  List<DriveSegment> get history => List<DriveSegment>.unmodifiable(_history);

  bool get ready =>
      _weightedWhPerKm != null &&
      _weightedWhPerKm! > 0 &&
      _historyKm >= minMovingKmBeforeShow;

  /// Last published Cons Est. km (null if Cons1 invalid/missing).
  int? get lastShownConsKm => _hasPublishedCons ? _lastShownConsKm : null;

  /// Persistable state (prefs JSON).
  Map<String, Object?> toPersistJson() => <String, Object?>{
        'v': 2,
        'movingKmAccum': _movingKmAccum,
        'history': _history.map((s) => s.toJson()).toList(),
        'lastShownKm': _lastShownKm,
        'distanceAtLastPublish': _distanceAtLastPublish,
        'hasPublished': _hasPublished,
        // Kept for diagnostics / older readers; not used as primary after 0108.
        'weightedWhPerKm': _weightedWhPerKm,
      };

  void restoreFromPersistJson(Map<String, Object?> json) {
    _movingKmAccum = (json['movingKmAccum'] as num?)?.toDouble() ?? 0;
    _lastShownKm = (json['lastShownKm'] as num?)?.toInt();
    _distanceAtLastPublish =
        (json['distanceAtLastPublish'] as num?)?.toDouble() ?? 0;
    _hasPublished = json['hasPublished'] as bool? ?? (_lastShownKm != null);

    _history.clear();
    _historyKm = 0;
    _weightedWhPerKm = null;

    final rawHist = json['history'];
    if (rawHist is List && rawHist.isNotEmpty) {
      for (final item in rawHist) {
        final seg = DriveSegment.fromJson(item);
        if (seg == null) continue;
        _history.add(seg);
        _historyKm += seg.distanceKm;
      }
      _trimToWindow();
      _recomputeWeighted();
    } else {
      // Migrate 0105 EWMA prefs → one synthetic segment so a mid-trip upgrade
      // does not wipe a ready estimate.
      final ewma = (json['ewmaWhPerKm'] as num?)?.toDouble();
      if (ewma != null && ewma > 0 && _movingKmAccum > 0) {
        final km = math.min(_movingKmAccum, windowKm);
        _history.add(DriveSegment(distanceKm: km, energyWh: ewma * km));
        _historyKm = km;
        _recomputeWeighted();
      }
    }

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

  /// 0108/0117: Adapt efficiency must not seed or replace the composite.
  /// Parameter retained so callers/tests stay source-compatible.
  void maybeSeedFromAdaptEfficiency(double? kwhPer100km) {
    // Intentionally no-op.
  }

  /// Ingest one sample. Returns own-Est rounded km, or null if not ready.
  /// Also updates Cons Est. (soft-lagged) via [lastShownConsKm].
  int? ingest({
    required DateTime now,
    double? socPct,
    int? speedKmh,
    bool charging = false,
    double? efficiencyKwhPer100km,
  }) {
    maybeSeedFromAdaptEfficiency(efficiencyKwhPer100km);

    final last = _lastTick;
    _lastTick = now;

    if (socPct != null) {
      _lastSocPct ??= socPct;
      _segmentSocStart ??= socPct;
    }

    if (last == null) {
      _updateConsEst(socPct, efficiencyKwhPer100km);
      return _displayRange(socPct);
    }

    final dtSec = now.difference(last).inMilliseconds / 1000.0;
    if (dtSec <= 0) {
      _updateConsEst(socPct, efficiencyKwhPer100km);
      return _displayRange(socPct);
    }

    // Large gap → drop interval (no distance, no sample).
    if (dtSec > maxGapSeconds) {
      _resetSegment(socPct);
      _updateConsEst(socPct, efficiencyKwhPer100km);
      return _displayRange(socPct);
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
    _updateConsEst(socPct, efficiencyKwhPer100km);
    return _displayRange(socPct);
  }

  void _resetSegment(double? socPct) {
    _segmentKm = 0;
    _segmentSocStart = socPct ?? _lastSocPct;
  }

  void _tryCloseSegment(double? socPct) {
    if (socPct == null || _segmentSocStart == null) return;
    if (_segmentKm < minSegmentKm) return;

    final socDelta = _segmentSocStart! - socPct; // + = consumed, − = regen
    // Drop near-zero SoCΔ (noise): keep segment open until |ΔSoC| clears floor.
    if (socDelta.abs() < minSocDeltaPct) {
      return;
    }

    final energyWh = socDelta / 100.0 * usablePackWh;
    final sample = energyWh / _segmentKm;
    if (sample.isNaN || sample.isInfinite) {
      _resetSegment(socPct);
      return;
    }
    // 0114: a 1% SoC step is 1000 Wh. Closing at minSegmentKm made Wh/km blow
    // up, and resetting discarded the energy forever. Keep the segment open
    // until distance dilutes under the cap. Bail only on multi-km glitches.
    if (sample.abs() > maxAbsWhPerKm) {
      if (_segmentKm >= 15.0) {
        _resetSegment(socPct);
      }
      return;
    }

    // First real samples that are regen-only leave weighted undefined until
    // there is net positive consumption in the window.
    _history.add(
      DriveSegment(distanceKm: _segmentKm, energyWh: energyWh),
    );
    _historyKm += _segmentKm;
    _trimToWindow();
    _recomputeWeighted();

    _segmentKm = 0;
    _segmentSocStart = socPct;
  }

  void _trimToWindow() {
    while (_historyKm > windowKm && _history.isNotEmpty) {
      final excess = _historyKm - windowKm;
      final oldest = _history.first;
      if (oldest.distanceKm <= excess + 1e-9) {
        _historyKm -= oldest.distanceKm;
        _history.removeAt(0);
      } else {
        final keepKm = oldest.distanceKm - excess;
        final keepWh = oldest.energyWh * (keepKm / oldest.distanceKm);
        _history[0] = DriveSegment(distanceKm: keepKm, energyWh: keepWh);
        _historyKm = windowKm;
        break;
      }
    }
  }

  double _weightAt(double distFromNow) {
    // 0117 HARD: last 1 km mute; 1..5 peak 8×; 5..50 older 1×.
    if (distFromNow < bandMuteKm) return weightMute;
    if (distFromNow < bandPeakKm) return weightPeak;
    return weightOlder;
  }

  void _recomputeWeighted() {
    if (_history.isEmpty || _historyKm <= 0) {
      _weightedWhPerKm = null;
      return;
    }

    var wWh = 0.0;
    var wKm = 0.0;
    var distFromNow = 0.0;

    for (var i = _history.length - 1; i >= 0; i--) {
      final seg = _history[i];
      if (seg.distanceKm <= 0) continue;
      final whPerKm = seg.energyWh / seg.distanceKm;
      var remaining = seg.distanceKm;
      while (remaining > 1e-9) {
        // Distance to next band boundary from [distFromNow].
        double boundary;
        if (distFromNow < bandMuteKm) {
          boundary = bandMuteKm;
        } else if (distFromNow < bandPeakKm) {
          boundary = bandPeakKm;
        } else {
          boundary = windowKm + 1; // rest of older band
        }
        final room = boundary - distFromNow;
        final chunk = math.min(remaining, room);
        final w = _weightAt(distFromNow);
        wWh += w * whPerKm * chunk;
        wKm += w * chunk;
        distFromNow += chunk;
        remaining -= chunk;
        if (distFromNow >= windowKm) {
          remaining = 0;
        }
      }
    }

    if (wKm <= 0) {
      _weightedWhPerKm = null;
      return;
    }
    final ratio = wWh / wKm;
    if (ratio.isNaN || ratio.isInfinite || ratio <= 0) {
      _weightedWhPerKm = null;
      return;
    }
    _weightedWhPerKm = math.max(minWhPerKmFloor, ratio);
  }

  int? _displayRange(double? socPct) {
    if (!ready || socPct == null) return null;
    final whPerKm = _weightedWhPerKm!;
    final raw = (socPct / 100.0) * usablePackWh / whPerKm;
    if (raw.isNaN || raw.isInfinite || raw < 1) return null;
    final candidate = raw.round().clamp(1, 999);

    if (!_hasPublished) {
      _lastShownKm = candidate;
      _distanceAtLastPublish = _movingKmAccum;
      _hasPublished = true;
      return candidate;
    }

    // Publish a new display value only after ~1 km of further moving distance.
    if (_movingKmAccum - _distanceAtLastPublish >= displayRefreshKm) {
      _lastShownKm = candidate;
      _distanceAtLastPublish = _movingKmAccum;
    }
    return _lastShownKm;
  }

  /// Cons Est. ≈ (soc/100)×packWh / (cons_kWh_per_100 × 10). Soft Cons lag.
  void _updateConsEst(double? socPct, double? consKwhPer100) {
    if (socPct == null || !isValidEfficiencyKwhPer100km(consKwhPer100)) {
      // Invalid/missing Cons1 → Cons Est. hidden/unavailable.
      if (!isValidEfficiencyKwhPer100km(consKwhPer100)) {
        _lastShownConsKm = null;
        _hasPublishedCons = false;
        _lastConsUsedForDisplay = null;
      }
      return;
    }
    final cons = consKwhPer100!;
    final raw = (socPct / 100.0) * usablePackWh / (cons * 10.0);
    if (raw.isNaN || raw.isInfinite || raw < 1) {
      _lastShownConsKm = null;
      _hasPublishedCons = false;
      _lastConsUsedForDisplay = null;
      return;
    }
    final candidate = raw.round().clamp(1, 999);
    if (!_hasPublishedCons) {
      _lastShownConsKm = candidate;
      _distanceAtLastConsPublish = _movingKmAccum;
      _lastConsUsedForDisplay = cons;
      _hasPublishedCons = true;
      return;
    }
    final consMoved = _lastConsUsedForDisplay == null ||
        (cons - _lastConsUsedForDisplay!).abs() >= 0.5;
    final distOk =
        _movingKmAccum - _distanceAtLastConsPublish >= kConsDisplayRefreshKm;
    // Soft Cons lag: don't thrash on every Cons tick. Refresh when:
    //  • ~1 km moving distance advanced, or
    //  • Cons itself jumped ≥0.5 kWh/100 (real trip-average step).
    // SoC-only drift between those gates is held (same cadence as own Est.).
    if (distOk || consMoved) {
      _lastShownConsKm = candidate;
      _distanceAtLastConsPublish = _movingKmAccum;
      _lastConsUsedForDisplay = cons;
    }
  }

  /// Pure Cons Est. math (no soft lag) — for units / settings preview.
  static int? consEstKm({
    required double socPct,
    required double consKwhPer100,
    double packWh = kUsablePackWh,
  }) {
    if (!isValidEfficiencyKwhPer100km(consKwhPer100)) return null;
    final raw = (socPct / 100.0) * packWh / (consKwhPer100 * 10.0);
    if (raw.isNaN || raw.isInfinite || raw < 1) return null;
    return raw.round().clamp(1, 999);
  }

  /// Test helper: plant a ready window without a real trip.
  void debugForceState({
    required double movingKm,
    required double whPerKm,
    int? lastShownKm,
    List<DriveSegment>? history,
  }) {
    _movingKmAccum = movingKm;
    _history.clear();
    _historyKm = 0;
    if (history != null && history.isNotEmpty) {
      _history.addAll(history);
      for (final s in _history) {
        _historyKm += s.distanceKm;
      }
      _trimToWindow();
      _recomputeWeighted();
    } else {
      final km = math.min(math.max(movingKm, minMovingKmBeforeShow), windowKm);
      _history.add(DriveSegment(distanceKm: km, energyWh: whPerKm * km));
      _historyKm = km;
      _weightedWhPerKm = math.max(minWhPerKmFloor, whPerKm);
    }
    _lastShownKm = lastShownKm;
    _hasPublished = lastShownKm != null;
    _distanceAtLastPublish = _movingKmAccum;
  }

  /// Test helper: append a closed segment without going through ingest ticks.
  void debugAddSegment({required double distanceKm, required double energyWh}) {
    if (distanceKm <= 0) return;
    _history.add(DriveSegment(distanceKm: distanceKm, energyWh: energyWh));
    _historyKm += distanceKm;
    _movingKmAccum += distanceKm;
    _trimToWindow();
    _recomputeWeighted();
  }
}
