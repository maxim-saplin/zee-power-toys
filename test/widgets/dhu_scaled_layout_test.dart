import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/widgets/dhu_scaled_layout.dart';

void main() {
  group('dhuSmartScale — automotive low-DPI heuristic', () {
    test('Zeekr DHU (2560 logical @ dpr 1.0) → clamped 3.0', () {
      expect(dhuSmartScale(2560, 1.0), 3.0); // 2560/800 = 3.2 → clamp 3.0
    });

    test('exactly at the automotive width threshold (1600 @ dpr 1.0) → 2.0', () {
      expect(dhuSmartScale(1600, 1.0), 2.0);
    });

    test('mid-range automotive width (2000 @ dpr 1.0) → 2.5', () {
      expect(dhuSmartScale(2000, 1.0), closeTo(2.5, 1e-9));
    });

    test('just below the automotive width (1599) → 1.0 (no scaling)', () {
      expect(dhuSmartScale(1599, 1.0), 1.0);
    });

    test('high-DPI phone (wide but dpr 3.0) never matches → 1.0', () {
      expect(dhuSmartScale(2560, 3.0), 1.0);
    });

    test('dpr exactly 2.0 is NOT automotive (strict <) → 1.0', () {
      expect(dhuSmartScale(2560, 2.0), 1.0);
    });

    test('scale is clamped to a 3.0 ceiling', () {
      expect(dhuSmartScale(3200, 1.0), 3.0); // 4.0 → clamp 3.0
    });

    test('non-positive / non-finite widths guard to 1.0', () {
      expect(dhuSmartScale(0, 1.0), 1.0);
      expect(dhuSmartScale(-100, 1.0), 1.0);
      expect(dhuSmartScale(double.infinity, 1.0), 1.0);
      expect(dhuSmartScale(double.nan, 1.0), 1.0);
    });
  });

  group('DhuScaledLayout — applies the scale only on the automotive target', () {
    testWidgets('automotive surface shrinks the child logical canvas', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(2560, 1600);
      addTearDown(tester.view.reset);

      double? childLogicalWidth;
      await tester.pumpWidget(
        MaterialApp(
          home: DhuScaledLayout(
            child: Builder(builder: (context) {
              childLogicalWidth = MediaQuery.of(context).size.width;
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      // 2560 logical / 3.0 scale ≈ 853 logical px presented to the child.
      expect(childLogicalWidth, isNotNull);
      expect(childLogicalWidth!, closeTo(2560 / 3.0, 1.0));
    });

    testWidgets('non-automotive surface passes the child through unscaled', (tester) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(1170, 2532); // phone
      addTearDown(tester.view.reset);

      double? childLogicalWidth;
      await tester.pumpWidget(
        MaterialApp(
          home: DhuScaledLayout(
            child: Builder(builder: (context) {
              childLogicalWidth = MediaQuery.of(context).size.width;
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      // logical width = 1170 / 3.0 = 390; passed through unchanged (scale 1.0).
      expect(childLogicalWidth, isNotNull);
      expect(childLogicalWidth!, closeTo(390, 1.0));
    });
  });
}
