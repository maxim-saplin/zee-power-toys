import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/theme/app_theme.dart';
import 'package:zee_power_toys/widgets/settings_layout.dart';

import '../support/harness.dart';

/// Regression coverage for two bugs fixed together in
/// `lib/widgets/settings_layout.dart` / `lib/theme/app_theme.dart`:
///
/// 1. `SettingsSlider` used to pass `label: valueLabel` straight to the
///    Material [Slider]. Because `divisions` is always non-null, every
///    slider in the app is a *discrete* M3 slider, so that `label` popped a
///    value-indicator balloon on drag — redundant with the inline value
///    readout already shown above the track, and prone to rendering off the
///    edge of the screen (magnified by the DHU's 3.0x scale). The fix is a
///    deletion (drop `label:`) plus `sliderTheme.showValueIndicator: never`
///    in [AppTheme] as a defence-in-depth backstop.
/// 2. The min/max edge captions were bare, unconstrained `Text` inside a
///    `Row` — fine for short English strings, but Russian localisations of
///    e.g. `positionTop`/`positionBottom`/`positionEdge` are longer, and this
///    row lives inside `ExpansionTile` padding + `Card` padding + `ListView`
///    padding on a DHU viewport that is only ~853dp wide. Without
///    `Flexible`/ellipsis that overflows; on the real DHU
///    (`dhu_scaled_layout.dart` wraps content in a `ClipRect`) the overflow
///    is clipped *silently* — a widget test is the only way to catch it.
void main() {
  setUp(useMockPrefs);

  Widget buildSlider({
    String minLabel = '0%',
    String maxLabel = '100%',
    double value = 0.2,
  }) {
    return SettingsSlider(
      label: 'Test slider',
      valueLabel: '${(value * 100).toStringAsFixed(0)}%',
      minLabel: minLabel,
      maxLabel: maxLabel,
      sliderKey: const ValueKey('test-slider'),
      min: 0.0,
      max: 1.0,
      divisions: 20,
      value: value,
      onChanged: (_) {},
    );
  }

  group('SettingsSlider', () {
    testWidgets(
      'Slider never carries a label — the discrete value-indicator balloon must not come back',
      (tester) async {
        await tester.pumpWidget(
          wrapWithProviders(buildSlider(), scaffold: true, localizations: false),
        );
        await tester.pump();

        final sliders = tester.widgetList<Slider>(find.byType(Slider));
        expect(sliders, isNotEmpty);
        for (final slider in sliders) {
          expect(
            slider.label,
            isNull,
            reason:
                'divisions is always non-null here, so any non-null label would '
                'pop a discrete M3 value-indicator bubble that can overflow the '
                'screen near the track ends at the DHU\'s 3.0x scale',
          );
        }
      },
    );

    testWidgets('inline value readout is present and shows the formatted value', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithProviders(
          buildSlider(value: 0.42),
          scaffold: true,
          localizations: false,
        ),
      );
      await tester.pump();

      expect(find.text('42%'), findsOneWidget);
    });

    testWidgets(
      'AppTheme.dhu suppresses the M3 value indicator app-wide as a backstop',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.dhu, home: const SizedBox.shrink()),
        );
        await tester.pump();

        final context = tester.element(find.byType(SizedBox));
        expect(
          Theme.of(context).sliderTheme.showValueIndicator,
          ShowValueIndicator.never,
          reason:
              'so that no future slider (discrete or continuous) can '
              'reintroduce the off-screen value balloon',
        );
      },
    );

    testWidgets(
      'long min/max labels do not overflow at the real DHU viewport width (~853dp)',
      (tester) async {
        // Russian localisations of positionTop/positionBottom/positionEdge
        // run longer than their English counterparts (hud_settings_screen
        // .dart:196-197, 217), and this row is nested inside an
        // ExpansionTile's padding, inside Card padding, inside ListView
        // padding — squeeze accordingly with a deliberately long label pair.
        const longMin = 'Сверху (очень длинная подпись слева от ползунка)';
        const longMax = 'Снизу (очень длинная подпись справа от ползунка)';

        await tester.pumpWidget(
          wrapWithProviders(
            Center(
              child: SizedBox(
                width: 853,
                child: buildSlider(minLabel: longMin, maxLabel: longMax),
              ),
            ),
            scaffold: true,
            localizations: false,
          ),
        );
        await tester.pump();

        // The cheap version: no RenderFlex overflow (or any other) exception
        // was thrown during layout/paint.
        expect(tester.takeException(), isNull);

        // The stronger version: locate the min-label/slider/max-label Row
        // directly and confirm it actually laid out within the 853dp box,
        // rather than merely failing to throw.
        final rowFinder = find.descendant(
          of: find.byType(SettingsSlider),
          matching: find.byWidgetPredicate(
            (w) => w is Row && w.children.length == 3,
          ),
        );
        expect(rowFinder, findsOneWidget);
        final renderBox = tester.renderObject<RenderBox>(rowFinder);
        expect(renderBox.size.width, lessThanOrEqualTo(853));
      },
    );
  });
}
