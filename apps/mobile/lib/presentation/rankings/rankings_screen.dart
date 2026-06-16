import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api_client.dart';
import '../../domain/ranking.dart';
import '../../state/me_controller.dart';

class RankingsScreen extends ConsumerStatefulWidget {
  const RankingsScreen({super.key});

  @override
  ConsumerState<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends ConsumerState<RankingsScreen> {
  String _scope = 'global';
  String? _value;
  String _label = 'Global';
  bool _includeProvisional = true;
  late Future<List<RankingEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<RankingEntry>> _load() => ref
      .read(apiClientProvider)
      .getRankings(scope: _scope, value: _value, includeProvisional: _includeProvisional);

  void _select(String scope, String? value, String label) {
    setState(() {
      _scope = scope;
      _value = value;
      _label = label;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;
    final myCity = me?.player?.city;

    return Scaffold(
      appBar: AppBar(title: const Text('Rankings')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _chip('Global', _scope == 'global', () => _select('global', null, 'Global')),
                if (myCity != null)
                  _chip('Mi ciudad', _scope == 'city',
                      () => _select('city', myCity, 'Ciudad: $myCity')),
                _chip('Hombres', _scope == 'gender' && _value == 'M',
                    () => _select('gender', 'M', 'Hombres')),
                _chip('Mujeres', _scope == 'gender' && _value == 'F',
                    () => _select('gender', 'F', 'Mujeres')),
              ],
            ),
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Incluir provisionales'),
            subtitle: const Text('Jugadores con pocos partidos (rating poco asentado)'),
            value: _includeProvisional,
            onChanged: (v) => setState(() {
              _includeProvisional = v;
              _future = _load();
            }),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<RankingEntry>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Sin jugadores en "$_label".\n'
                        'Los rankings oficiales muestran solo jugadores con rating asentado.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => setState(() => _future = _load()),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _row(context, list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );

  Widget _row(BuildContext context, RankingEntry e) {
    final theme = Theme.of(context);
    final medal = switch (e.rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => theme.colorScheme.surfaceContainerHighest,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: medal,
              child: Text('${e.rank}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.fullName, style: theme.textTheme.titleMedium),
                  Text(
                    '${e.city ?? ''}${e.state == 'PROVISIONAL' ? '  · provisional' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              e.rating.toStringAsFixed(2),
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.brand,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
