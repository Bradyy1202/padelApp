import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/player.dart';
import '../../state/auth_controller.dart';
import '../../state/me_controller.dart';

/// Home: hero de rating del jugador + accesos (Sprint 1, rediseñado con UI/UX Pro Max).
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
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: me.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final player = data?.player;
          if (player == null) return const Center(child: Text('Completa tu perfil'));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _ratingHero(context, player),
              const SizedBox(height: 20),
              _actionTile(
                context,
                icon: Icons.sports_tennis,
                title: 'Mis partidos',
                subtitle: 'Crea un partido o registra resultados',
                onTap: () => context.push('/matches'),
              ),
              const SizedBox(height: 12),
              _actionTile(
                context,
                icon: Icons.leaderboard,
                title: 'Rankings',
                subtitle: 'Compárate por ciudad, club o género',
                onTap: () => context.push('/rankings'),
              ),
              const SizedBox(height: 12),
              _actionTile(
                context,
                icon: Icons.person_outline,
                title: 'Mi perfil',
                subtitle: 'Edita tus datos, invitados y evolución',
                onTap: () => context.push('/profile'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ratingHero(BuildContext context, Player player) {
    final theme = Theme.of(context);
    final rating = player.rating;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                backgroundImage:
                    player.photoUrl != null ? NetworkImage(player.photoUrl!) : null,
                child: player.photoUrl == null
                    ? const Icon(Icons.person, color: Colors.white, size: 30)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.fullName,
                      style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    if (player.city != null)
                      Text(player.city!,
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (rating == null)
            _noRating(theme)
          else
            _ratingValue(theme, rating),
        ],
      ),
    );
  }

  Widget _ratingValue(ThemeData theme, RatingSummary rating) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RATING',
                style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5)),
            Text(
              rating.rating.toStringAsFixed(2),
              style: theme.textTheme.displayMedium
                  ?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800, height: 1),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${rating.confidence}% confianza',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Text(rating.state,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _noRating(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.white70),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aún sin rating. Juega tus primeros partidos para calcularlo.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
