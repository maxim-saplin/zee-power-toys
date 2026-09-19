/// Plays the approach sting (game-like).
abstract class SpeedcamAlert {
  Future<void> playSting();
  Future<void> dispose();
}

/// Edge detector: sting once on false→true [insideApproach]; re-arm on exit.
class SpeedcamApproachArm {
  SpeedcamApproachArm({required this.alert, this.enabled = true});

  final SpeedcamAlert alert;
  bool enabled;
  bool _armed = true;
  bool _wasInside = false;

  /// Feed latest [insideApproach]. Returns true if a sting was requested.
  Future<bool> onInsideApproach(bool inside) async {
    var played = false;
    if (!enabled) {
      _wasInside = inside;
      if (!inside) _armed = true;
      return false;
    }
    if (inside && !_wasInside && _armed) {
      _armed = false;
      await alert.playSting();
      played = true;
    }
    if (!inside) {
      _armed = true;
    }
    _wasInside = inside;
    return played;
  }
}
