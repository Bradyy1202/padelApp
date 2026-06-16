import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/auth_controller.dart';
import '../../state/me_controller.dart';

/// Home: resumen del perfil y rating del jugador (Sprint 1).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pádel CR'),
        actions: [
          IconButton(
            tooltip: 'Mi perfil',
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: me.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final player = data?.player;
          if (player == null) {
            return const Center(child: Text('Completa tu perfil'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage:
                        player.photoUrl != null ? NetworkImage(player.photoUrl!) : null,
                    child: player.photoUrl == null ? const Icon(Icons.person, size: 32) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(player.fullName,
                            style: Theme.of(context).textTheme.headlineSmall),
                        if (player.city != null) Text(player.city!),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rating', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (player.rating == null)
                        Text(
                          'Aún sin rating. Juega tus primeros partidos para calcularlo.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else ...[
                        Text(player.rating!.rating.toStringAsFixed(2),
                            style: Theme.of(context).textTheme.displaySmall),
                        Text('Confianza: ${player.rating!.confidence}% · ${player.rating!.state}'),
                      ],
                      if (player.estLevel != null) ...[
                        const SizedBox(height: 8),
                        Text('Nivel estimado: ${player.estLevel!.toStringAsFixed(1)}'),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
