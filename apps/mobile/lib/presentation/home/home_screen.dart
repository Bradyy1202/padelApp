import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/health_provider.dart';

/// Pantalla placeholder de Sprint 0: confirma que la app arranca y que puede
/// hablar con el backend (GET /health). Se reemplaza por el Home real en Sprint 1.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final health = ref.watch(healthProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.homeWelcome, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            Text('${l10n.backendStatus}:'),
            const SizedBox(height: 8),
            health.when(
              data: (status) => Text(
                status,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              loading: () => Text(l10n.checking),
              error: (e, _) => Text('error: $e', style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(healthProvider),
              child: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}
