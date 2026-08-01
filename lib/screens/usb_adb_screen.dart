import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/services.dart';
import '../providers/usb_mode.dart';
import '../services/usb_mode.dart';
import '../theme/app_theme.dart';

/// Dedicated USB / ADB mode screen (Block 0023 — moved from Diagnostics QA2-2).
///
/// Provides a 3-state SegmentedButton (Peripheral / Host / Auto) for choosing
/// the USB role.  When [UsbModePort.writable] is false (emulator / unsigned
/// build) the controls are disabled and a localized hint is shown.
class UsbAdbScreen extends ConsumerStatefulWidget {
  const UsbAdbScreen({super.key});

  @override
  ConsumerState<UsbAdbScreen> createState() => _UsbAdbScreenState();
}

class _UsbAdbScreenState extends ConsumerState<UsbAdbScreen> {
  String? _errorText;

  Future<void> _setUsbMode(UsbMode mode) async {
    // Persist the "auto" preference to ConfigStore *first* and unconditionally
    // — this is the one part of "auto" that actually works off-car (the boot
    // shim's ConfigShim.readAutoUsbPeripheral reads this exact top-level key).
    // Do this regardless of whether the native setUsbMode() write below
    // succeeds, so the app's own honesty about "auto" never depends on a
    // privileged write that this build cannot make (Task 2).
    final store = ref.read(configStoreProvider);
    await store.setConfig(
      store.value.copyWith(autoUsbPeripheral: mode == UsbMode.auto),
    );

    final port = ref.read(usbModeProvider);
    final result = await port.setUsbMode(mode);
    if (mounted) {
      setState(() {
        _errorText = result.ok ? null : result.reason;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final usbPort = ref.watch(usbModeProvider);
    final theme = Theme.of(context);
    final currentLabel = _modeLabel(usbPort.currentMode, l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.usbAdbTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      Insets.sm,
                      Insets.lg,
                      Insets.sm,
                    ),
                    child: Text(
                      l10n.usbAdbTitle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      Insets.sm,
                      Insets.lg,
                      Insets.xs,
                    ),
                    child: Text(
                      '${l10n.usbCurrentMode}: $currentLabel',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  // Always shown (not gated on a failed write attempt first):
                  // this build's lack of platform signing is a known, static
                  // fact — no sharedUserId in the manifest, release signs with
                  // the debug key — so the screen says so plainly up front
                  // rather than only after the user discovers it the hard way
                  // (Task 2 — "auto" honesty).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      0,
                      Insets.lg,
                      Insets.sm,
                    ),
                    child: Text(
                      l10n.usbPlatformSigningRequired,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      Insets.xs,
                      Insets.lg,
                      Insets.sm,
                    ),
                    child: SegmentedButton<UsbMode>(
                      key: const ValueKey('usb-mode-selector'),
                      segments: <ButtonSegment<UsbMode>>[
                        ButtonSegment<UsbMode>(
                          value: UsbMode.peripheral,
                          label: Text(
                            l10n.usbModePeripheral,
                            key: const ValueKey('usb-peripheral'),
                          ),
                        ),
                        ButtonSegment<UsbMode>(
                          value: UsbMode.host,
                          label: Text(
                            l10n.usbModeHost,
                            key: const ValueKey('usb-host'),
                          ),
                        ),
                        ButtonSegment<UsbMode>(
                          value: UsbMode.auto,
                          label: Text(
                            l10n.usbModeAuto,
                            key: const ValueKey('usb-auto'),
                          ),
                        ),
                      ],
                      selected: {usbPort.currentMode},
                      onSelectionChanged: usbPort.writable
                          ? (Set<UsbMode> selection) {
                              if (selection.isNotEmpty) {
                                _setUsbMode(selection.first);
                              }
                            }
                          : null,
                    ),
                  ),
                  if (_errorText != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.lg,
                        0,
                        Insets.lg,
                        Insets.sm,
                      ),
                      child: Text(
                        _errorText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _modeLabel(UsbMode mode, AppLocalizations l10n) =>
      switch (mode) {
        UsbMode.peripheral => l10n.usbModePeripheral,
        UsbMode.host => l10n.usbModeHost,
        UsbMode.auto => l10n.usbModeAuto,
      };
}
