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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final m = list[i];
                final names = m.teams
                    .map((t) => t.players.map((p) => p.fullName).join(' / '))
                    .join('  vs  ');
                return Card(
                  child: InkWell(
                    onTap: () => context.push('/matches/${m.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _statusPill(context, m.status),
                                const SizedBox(height: 8),
                                Text(names.isEmpty ? '(sin jugadores)' : names,
                                    style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 2),
                                Text('${_typeLabel(m.type)} · al mejor de ${m.bestOf}',
                                    style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  static (String, Color) _statusMeta(String status) => switch (status) {
        'DRAFT' => ('Borrador', Colors.blueGrey),
        'READY' => ('Listo', Colors.blue),
        'PENDING_CONFIRMATION' => ('Por confirmar', const Color(0xFFE8A317)),
        'CONFIRMED' => ('Confirmado', const Color(0xFF2BB673)),
        'DISPUTED' => ('Disputado', const Color(0xFFE5484D)),
        'DISCARDED' => ('Descartado', Colors.grey),
        _ => (status, Colors.black38),
      };

  static String _typeLabel(String type) => switch (type) {
        'FRIENDLY' => 'Amistoso',
        'COMPETITIVE' => 'Competitivo',
        'POZO' => 'Pozo',
        'TOURNAMENT' => 'Torneo',
        _ => type,
      };

  Widget _statusPill(BuildContext context, String status) {
    final (label, color) = _statusMeta(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
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
