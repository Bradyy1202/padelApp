import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api_client.dart';
import '../../domain/pozo.dart';
import '../../state/me_controller.dart';
import '../../state/pozos_controller.dart';

class PozoDetailScreen extends ConsumerWidget {
  const PozoDetailScreen({super.key, required this.pozoId});
  final String pozoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pozo = ref.watch(pozoProvider(pozoId));
    final isAdmin = ref.watch(meProvider).valueOrNull?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Pozo')),
      body: pozo.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (p) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
            Text('${p.mode == 'ROTATION' ? 'Rotación' : 'Parejas fijas'} · ${p.status}'),
            const SizedBox(height: 16),
            if (isAdmin) _adminActions(context, ref, p),
            if (p.standings.isNotEmpty) _standings(context, p),
            ...p.rounds.map((r) => _round(context, ref, p, r, isAdmin)),
            if (p.rounds.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Aún sin rondas. El organizador debe iniciar el pozo.')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _adminActions(BuildContext context, WidgetRef ref, PozoDetail p) {
    final api = ref.read(apiClientProvider);
    Future<void> run(Future<void> Function() f) async {
      try {
        await f();
        ref.invalidate(pozoProvider(pozoId));
        ref.invalidate(pozosProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (p.status == 'DRAFT' || p.status == 'OPEN')
              FilledButton.tonalIcon(
                icon: const Icon(Icons.person_add),
                label: const Text('Añadir invitados'),
                onPressed: () => _addGuestsDialog(context, ref),
              ),
            if (p.status == 'OPEN')
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar'),
                onPressed: () => run(() => api.startPozo(pozoId).then((_) {})),
              ),
            if (p.status == 'IN_PROGRESS')
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add),
                label: const Text('Siguiente ronda'),
                onPressed: () => run(() => api.nextRound(pozoId).then((_) {})),
              ),
            if (p.status == 'IN_PROGRESS')
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                icon: const Icon(Icons.flag),
                label: const Text('Cerrar pozo'),
                onPressed: () => run(() => api.closePozo(pozoId).then((_) {})),
              ),
          ],
        ),
      ),
    );
  }

  Widget _standings(BuildContext context, PozoDetail p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tabla de posiciones', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...p.standings.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(width: 24, child: Text('${s.rank}')),
                      Expanded(child: Text(s.fullName)),
                      Text('${s.wins}G ${s.losses}P  ·  ${s.gamesDiff >= 0 ? '+' : ''}${s.gamesDiff}'),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _round(BuildContext context, WidgetRef ref, PozoDetail p, PozoRoundView r, bool isAdmin) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ronda ${r.roundNo}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...r.matches.map((m) => _matchRow(context, ref, p, r, m, isAdmin)),
          ],
        ),
      ),
    );
  }

  Widget _matchRow(
    BuildContext context,
    WidgetRef ref,
    PozoDetail p,
    PozoRoundView r,
    PozoMatchView m,
    bool isAdmin,
  ) {
    final t1 = m.teams.isNotEmpty ? m.teams[0].join(' / ') : '';
    final t2 = m.teams.length > 1 ? m.teams[1].join(' / ') : '';
    final score = m.sets.map((s) => '${s[0]}-${s[1]}').join(', ');
    final canEnter = isAdmin && p.status == 'IN_PROGRESS' && !m.hasResult;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cancha ${m.court ?? '-'}',
                    style: Theme.of(context).textTheme.bodySmall),
                Text('$t1  vs  $t2',
                    style: TextStyle(
                        fontWeight: m.hasResult ? FontWeight.normal : FontWeight.w600)),
                if (m.hasResult) Text('Resultado: $score (ganó lado ${m.winnerSide})'),
              ],
            ),
          ),
          if (canEnter)
            TextButton(
              onPressed: () => _resultDialog(context, ref, r.roundNo, m),
              child: const Text('Registrar'),
            ),
        ],
      ),
    );
  }

  Future<void> _addGuestsDialog(BuildContext context, WidgetRef ref) async {
    final names = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Añadir invitados'),
        content: TextField(
          controller: names,
          decoration: const InputDecoration(
              labelText: 'Nombres separados por coma', hintText: 'Ana, Beto, Caro, ...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Añadir')),
        ],
      ),
    );
    if (ok == true) {
      final list = names.text.split(',').map((e) => e.trim()).where((e) => e.length >= 2).toList();
      if (list.isNotEmpty) {
        await ref.read(apiClientProvider).addPozoParticipants(pozoId, guestNames: list);
        ref.invalidate(pozoProvider(pozoId));
      }
    }
  }

  Future<void> _resultDialog(BuildContext context, WidgetRef ref, int roundNo, PozoMatchView m) async {
    final g1 = TextEditingController();
    final g2 = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resultado (1 set)'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: g1,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Lado 1'),
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('-')),
            Expanded(
              child: TextField(
                controller: g2,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Lado 2'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true) return;
    final a = int.tryParse(g1.text.trim());
    final b = int.tryParse(g2.text.trim());
    if (a == null || b == null) return;
    try {
      await ref.read(apiClientProvider).submitPozoResults(pozoId, roundNo, [
        {
          'pozoMatchId': m.pozoMatchId,
          'sets': [
            {'games1': a, 'games2': b},
          ],
        },
      ]);
      ref.invalidate(pozoProvider(pozoId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marcador inválido: $e')));
      }
    }
  }
}
