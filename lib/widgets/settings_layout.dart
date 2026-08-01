import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared layout primitives for the DHU settings screens.
///
/// These give every feature screen the same premium rhythm: a labelled
/// section header, content grouped in a hairline-outlined [Card], and slider
/// rows with min/max captions and a live value readout — instead of each
/// screen re-inventing bold-text headings and ad-hoc spacing.  All sizing
/// comes from the theme tokens ([Insets], [Sizes]) so nothing is inflated.

/// A small all-caps accent label that introduces a section.
///
/// Optional [trailing] sits on the same baseline (e.g. a current-value chip).
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.xs, 0, Insets.xs, Insets.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 0.6,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A grouped settings section: an optional [SettingsSectionHeader] above a
/// single hairline-outlined card that holds [children].
///
/// Pass [padded] = false when the children manage their own padding (e.g. a
/// list of [ListTile]s); the default wraps them in comfortable card padding.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    this.title,
    required this.children,
    this.padded = true,
  });

  final String? title;
  final List<Widget> children;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: padded
          ? Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
    );

    if (title == null) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[SettingsSectionHeader(title!), card],
    );
  }
}

/// A labelled slider with min/max edge captions and a right-aligned live value.
///
/// Keeps the [Slider]'s [ValueKey] (passed via [sliderKey]) so agent-driven
/// taps and tests keep working, while giving every slider a consistent,
/// legible layout instead of an unlabelled bare track.
class SettingsSlider extends StatelessWidget {
  const SettingsSlider({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.minLabel,
    required this.maxLabel,
    required this.sliderKey,
    required this.min,
    required this.max,
    required this.divisions,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final String minLabel;
  final String maxLabel;
  final Key sliderKey;
  final double min;
  final double max;
  final int divisions;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(
              valueLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                minLabel,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            Expanded(
              child: Slider(
                key: sliderKey,
                min: min,
                max: max,
                divisions: divisions,
                value: value,
                onChanged: onChanged,
              ),
            ),
            Flexible(
              child: Text(
                maxLabel,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A label + trailing control row (e.g. a [Switch]), with an optional muted
/// [subtitle] under the label.  Vertically padded for a comfortable touch row.
class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.label,
    required this.control,
    this.subtitle,
  });

  final String label;
  final Widget control;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: theme.textTheme.bodyLarge),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: Insets.xs),
                  subtitle!,
                ],
              ],
            ),
          ),
          const SizedBox(width: Insets.md),
          control,
        ],
      ),
    );
  }
}
