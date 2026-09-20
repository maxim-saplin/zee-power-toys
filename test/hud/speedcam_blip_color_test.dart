import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/speedcam_radar_widget.dart';

void main() {
  test('0064 alien blip fill: danger white, other greenish', () {
    expect(
      alienBlipFillColor(highlight: true),
      SpeedcamRadarWidget.blipDanger,
    );
    expect(alienBlipFillColor(highlight: true), Colors.white);
    expect(
      alienBlipFillColor(highlight: false),
      SpeedcamRadarWidget.blipOther,
    );
    expect(
      alienBlipFillColor(highlight: false),
      SpeedcamRadarWidget.phosphor,
    );
    expect(
      alienBlipFillColor(highlight: true),
      isNot(alienBlipFillColor(highlight: false)),
    );
  });
}
