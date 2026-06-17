import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api_client.dart';
import '../../state/me_controller.dart';
import '../../state/pozos_controller.dart';

class PozosListScreen extends ConsumerWidget {
  const PozosListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pozos = ref.watch(pozosProvider);
    final isAdmin = ref.watch(meProvider).valueOrNull?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Pozos')),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _createDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo pozo'),
            )
          : null,
      body: pozos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(isAdmin
                  ? 'Crea tu primer pozo con el botón +'
                  : 'Aún no participas en ningún pozo'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pozosProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final p = list[i];
                return Card(
                  child: ListTile(
                    title: Text(p.name),
                    subtitle: Text(
                        '${p.mode == 'ROTATION' ? 'Rotación' : 'Parejas fijas'} · ${p.participants} jugadores · ${p.status}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/pozos/${p.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    String mode = 'ROTATION';
    int courts = 2;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nuevo pozo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: const InputDecoration(labelText: 'Modo'),
                items: const [
                  DropdownMenuItem(value: 'ROTATION', child: Text('Rotación')),
                  DropdownMenuItem(value: 'FIXED_PAIRS', child: Text('Parejas fijas')),
                ],
                onChanged: (v) => setState(() => mode = v!),
              ),
              DropdownButtonFormField<int>(
                initialValue: courts,
                decoration: const InputDecoration(labelText: 'Canchas'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1')),
                  DropdownMenuItem(value: 2, child: Text('2')),
                  DropdownMenuItem(value: 3, child: Text('3')),
                  DropdownMenuItem(value: 4, child: Text('4')),
                ],
                onChanged: (v) => setState(() => courts = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().length >= 2) {
      final p = await ref.read(apiClientProvider).createPozo(name: name.text.trim(), mode: mode, courts: courts);
      ref.invalidate(pozosProvider);
      if (context.mounted) context.push('/pozos/${p.id}');
    }
  }
}
