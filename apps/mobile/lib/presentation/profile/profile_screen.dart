import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api_client.dart';
import '../../domain/player.dart';
import '../../state/auth_controller.dart';
import '../../state/me_controller.dart';

/// Perfil: editar datos, crear invitado, reclamar perfiles sugeridos y borrar cuenta.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: me.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final player = data?.player;
          if (player == null) return const Center(child: Text('Sin perfil'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                title: Text(player.fullName),
                subtitle: Text([player.city, player.dominantHand, player.favSide]
                    .where((e) => e != null)
                    .join(' · ')),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('Crear jugador invitado'),
                onTap: () => _createGuestDialog(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.merge_type),
                title: const Text('Reclamar perfiles sugeridos'),
                onTap: () => _suggestionsDialog(context, ref),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Borrar mi cuenta', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Elimina tus datos (Ley 8968)'),
                onTap: () => _deleteAccount(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createGuestDialog(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo invitado'),
        content: TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Nombre completo'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
        ],
      ),
    );
    if (ok == true && name.text.trim().length >= 2) {
      await ref.read(apiClientProvider).createGuest({'fullName': name.text.trim()});
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invitado creado')));
      }
    }
  }

  Future<void> _suggestionsDialog(BuildContext context, WidgetRef ref) async {
    List<GuestSuggestion> suggestions;
    try {
      suggestions = await ref.read(apiClientProvider).guestSuggestions();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      return;
    }
    if (!context.mounted) return;
    if (suggestions.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No hay sugerencias de merge')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Perfiles que podrían ser tú'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: suggestions
                .map((s) => ListTile(
                      title: Text(s.fullName),
                      subtitle: Text('${s.city ?? ''} · ${(s.similarity * 100).round()}% similar'),
                      trailing: FilledButton(
                        child: const Text('Reclamar'),
                        onPressed: () async {
                          await ref.read(apiClientProvider).claimGuest(s.id);
                          ref.invalidate(meProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar tu cuenta?'),
        content: const Text('Esta acción elimina tus datos y no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(apiClientProvider).deleteAccount();
      await ref.read(authControllerProvider.notifier).signOut();
      if (context.mounted) context.go('/login');
    }
  }
}
