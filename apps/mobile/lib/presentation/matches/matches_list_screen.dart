import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api_client.dart';
import '../../state/matches_controller.dart';

class MatchesListScreen extends ConsumerWidget {
  const MatchesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(myMatchesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis partidos'),
        actions: [
          IconButton(
            tooltip: 'Unirse por código',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => _joinDialog(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo partido'),
      ),
      body: matches.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Aún no tienes partidos'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myMatchesProvider),
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = list[i];
                final names = m.teams
                    .map((t) => t.players.map((p) => p.fullName).join(' / '))
                    .join('  vs  ');
                return ListTile(
                  leading: _statusChip(m.status),
                  title: Text(names.isEmpty ? '(sin jugadores)' : names),
                  subtitle: Text('${m.type} · al mejor de ${m.bestOf}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/matches/${m.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'DRAFT' => Colors.grey,
      'READY' => Colors.blue,
      'PENDING_CONFIRMATION' => Colors.orange,
      'CONFIRMED' => Colors.green,
      'DISPUTED' => Colors.red,
      _ => Colors.black38,
    };
    return CircleAvatar(radius: 6, backgroundColor: color);
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    String type = 'FRIENDLY';
    int bestOf = 3;
    final create = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nuevo partido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'FRIENDLY', child: Text('Amistoso')),
                  DropdownMenuItem(value: 'COMPETITIVE', child: Text('Competitivo')),
                ],
                onChanged: (v) => setState(() => type = v!),
              ),
              DropdownButtonFormField<int>(
                initialValue: bestOf,
                decoration: const InputDecoration(labelText: 'Formato'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 set')),
                  DropdownMenuItem(value: 3, child: Text('Al mejor de 3')),
                ],
                onChanged: (v) => setState(() => bestOf = v!),
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
    if (create == true) {
      final m = await ref.read(apiClientProvider).createMatch(type: type, bestOf: bestOf);
      ref.invalidate(myMatchesProvider);
      if (context.mounted) context.push('/matches/${m.id}');
    }
  }

  Future<void> _joinDialog(BuildContext context, WidgetRef ref) async {
    final code = TextEditingController();
    int side = 2;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Unirse por código'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Código corto'),
              ),
              DropdownButtonFormField<int>(
                initialValue: side,
                decoration: const InputDecoration(labelText: 'Lado'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Lado 1')),
                  DropdownMenuItem(value: 2, child: Text('Lado 2')),
                ],
                onChanged: (v) => setState(() => side = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unirse')),
          ],
        ),
      ),
    );
    if (ok == true && code.text.trim().isNotEmpty) {
      try {
        final m = await ref
            .read(apiClientProvider)
            .joinByCode(code.text.trim().toUpperCase(), side);
        ref.invalidate(myMatchesProvider);
        if (context.mounted) context.push('/matches/${m.id}');
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
