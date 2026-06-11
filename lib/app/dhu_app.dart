import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/config.dart';
import '../providers/services.dart';

/// Shot key — exposed at library level so main.dart can pass it to extensions.
final GlobalKey dhuShotKey = GlobalKey();

/// DHU surface app — ugly on purpose; no theming yet.
class DhuApp extends StatelessWidget {
  const DhuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(key: dhuShotKey, child: const _DhuScreen()),
    );
  }
}

class _DhuScreen extends ConsumerWidget {
  const _DhuScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hudBoxOn = ref.watch(hudBoxOnProvider);
    final store = ref.read(configStoreProvider);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('DHU surface', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Text(
              'hudBoxOn: $hudBoxOn',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Switch(
              value: hudBoxOn,
              onChanged: (_) => store.setConfig(
                store.value.copyWith(hudBoxOn: !hudBoxOn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
