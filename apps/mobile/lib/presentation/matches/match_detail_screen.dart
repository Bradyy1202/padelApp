import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/api_client.dart';
import '../../domain/match.dart';
import '../../state/matches_controller.dart';
import '../../state/me_controller.dart';

class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({super.key, required this.matchId});
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.watch(matchProvider(matchId));
    return Scaffold(
      appBar: AppBar(title: const Text('Partido')),
      body: match.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (m) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Estado: ${m.status}', style: Theme.of(context).textTheme.titleMedium),
            Text('${m.type} · al mejor de ${m.bestOf} · ${m.playerCount}/4 jugadores'),
            const SizedBox(height: 16),
            for (final team in m.teams) _teamCard(context, ref, m, team),
            const SizedBox(height: 16),
            if (m.status == 'DRAFT' || m.status == 'READY') _qrSection(context, ref, m),
            if (m.sets.isNotEmpty) _setsCard(context, m),
            if (m.status == 'PENDING_CONFIRMATION') _confirmCard(context, ref, m),
            if (m.status == 'READY')
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton.icon(
                  icon: const Icon(Icons.scoreboard),
                  label: const Text('Registrar resultado'),
                  onPressed: () => _resultDialog(context, ref, m),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _teamCard(BuildContext context, WidgetRef ref, MatchDetail m, MatchTeam team) {
    final canAdd = (m.status == 'DRAFT' || m.status == 'READY') && team.players.length < 2;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lado ${team.side}', style: Theme.of(context).textTheme.titleSmall),
            ...team.players.map((p) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.person),
                  title: Text(p.fullName),
                  subtitle: p.status == 'GUEST' ? const Text('invitado') : null,
                )),
            if (canAdd)
              TextButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('Añadir invitado'),
                onPressed: () => _addGuestDialog(context, ref, m, team.side),
              ),
          ],
        ),
      ),
    );
  }

  Widget _qrSection(BuildContext context, WidgetRef ref, MatchDetail m) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Invitar por QR', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<QrInfo>(
              future: ref.read(apiClientProvider).generateQr(m.id),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24), child: CircularProgressIndicator());
                }
                if (snap.hasError) return Text('Error: ${snap.error}');
                final qr = snap.data!;
                return Column(
                  children: [
                    QrImageView(data: qr.token, size: 180),
                    const SizedBox(height: 8),
                    SelectableText('Código: ${qr.shortCode}',
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _setsCard(BuildContext context, MatchDetail m) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Marcador', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...m.sets.map((s) => Text('Set ${s.setNo}:  ${s.games1} - ${s.games2}')),
            if (m.result != null) ...[
              const SizedBox(height: 8),
              Text('Ganador: Lado ${m.result!.winnerSide}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _confirmCard(BuildContext context, WidgetRef ref, MatchDetail m) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.how_to_vote, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Confirma el resultado', style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Cuando la mayoría de jugadores reales confirme, el rating se actualizará. '
                'Si algo no cuadra, puedes disputarlo.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmar'),
                      onPressed: () => _confirm(context, ref, m, dispute: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Disputar'),
                      onPressed: () => _confirm(context, ref, m, dispute: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    MatchDetail m, {
    required bool dispute,
  }) async {
    try {
      final api = ref.read(apiClientProvider);
      final updated = dispute ? await api.disputeMatch(m.id) : await api.confirmMatch(m.id);
      ref.invalidate(matchProvider(m.id));
      ref.invalidate(myMatchesProvider);
      ref.invalidate(meProvider); // refresca el rating del home si cambió
      if (context.mounted) {
        final msg = updated.status == 'CONFIRMED'
            ? 'Resultado confirmado — rating actualizándose'
            : updated.status == 'DISPUTED'
                ? 'Resultado disputado'
                : 'Tu confirmación quedó registrada';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _addGuestDialog(BuildContext context, WidgetRef ref, MatchDetail m, int side) async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Invitado al lado $side'),
        content: TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Nombre completo'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Añadir')),
        ],
      ),
    );
    if (ok == true && name.text.trim().length >= 2) {
      try {
        await ref.read(apiClientProvider).addGuest(m.id, side, name.text.trim());
        ref.invalidate(matchProvider(m.id));
        ref.invalidate(myMatchesProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _resultDialog(BuildContext context, WidgetRef ref, MatchDetail m) async {
    final controllers = List.generate(3, (_) => (TextEditingController(), TextEditingController()));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar resultado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Games por set (deja vacío los no jugados)'),
            const SizedBox(height: 8),
            for (var i = 0; i < (m.bestOf == 1 ? 1 : 3); i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text('Set ${i + 1}  '),
                    Expanded(child: _numField(controllers[i].$1, 'L1')),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('-')),
                    Expanded(child: _numField(controllers[i].$2, 'L2')),
                  ],
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

    final sets = <Map<String, int>>[];
    for (final c in controllers) {
      final a = int.tryParse(c.$1.text.trim());
      final b = int.tryParse(c.$2.text.trim());
      if (a != null && b != null) sets.add({'games1': a, 'games2': b});
    }
    if (sets.isEmpty) return;
    try {
      await ref.read(apiClientProvider).registerResult(m.id, sets);
      ref.invalidate(matchProvider(m.id));
      ref.invalidate(myMatchesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Resultado registrado, pendiente de confirmación')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marcador inválido: $e')));
      }
    }
  }

  Widget _numField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(labelText: label, isDense: true),
      );
}
