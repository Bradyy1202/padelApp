import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api_client.dart';

/// Cola de disputas para administradores (PRD §7.10/§11.6).
class AdminDisputesScreen extends ConsumerStatefulWidget {
  const AdminDisputesScreen({super.key});

  @override
  ConsumerState<AdminDisputesScreen> createState() => _AdminDisputesScreenState();
}

class _AdminDisputesScreenState extends ConsumerState<AdminDisputesScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).getDisputes();
  }

  void _reload() => setState(() => _future = ref.read(apiClientProvider).getDisputes());

  Future<void> _resolve(String matchId, String resolution) async {
    try {
      await ref.read(apiClientProvider).resolveDispute(matchId, resolution);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Disputa resuelta: $resolution')));
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Disputas (admin)')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final list = snap.data ?? [];
          if (list.isEmpty) return const Center(child: Text('No hay disputas pendientes'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _card(context, list[i]),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> d) {
    final teams = (d['teams'] as List<dynamic>? ?? []);
    final sets = (d['sets'] as List<dynamic>? ?? []);
    final matchId = d['id'] as String;
    final names = teams
        .map((t) => ((t as Map)['players'] as List<dynamic>).join(' / '))
        .join('  vs  ');
    final score = sets.map((s) => '${(s as Map)['games1']}-${s['games2']}').join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(names, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Marcador: $score'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => _resolve(matchId, 'UPHELD'),
                    child: const Text('Mantener'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _resolve(matchId, 'OVERTURNED'),
                    child: const Text('Descartar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
