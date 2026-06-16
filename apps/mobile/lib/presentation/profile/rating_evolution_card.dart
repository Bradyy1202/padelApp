import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api_client.dart';
import '../../domain/ranking.dart';

/// Tarjeta con la evolución del rating del jugador (PRD §11.3 / US-10).
class RatingEvolutionCard extends ConsumerWidget {
  const RatingEvolutionCard({super.key, required this.playerId});
  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Evolución de rating', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            FutureBuilder<List<RatingPoint>>(
              future: ref.read(apiClientProvider).getRatingHistory(playerId),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
                }
                final pts = (snap.data ?? []).where((p) => p.ratingAfter != null).toList();
                if (pts.length < 2) {
                  return Text(
                    'Juega más partidos confirmados para ver tu evolución.',
                    style: theme.textTheme.bodySmall,
                  );
                }
                return SizedBox(height: 160, child: _chart(theme, pts));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _chart(ThemeData theme, List<RatingPoint> pts) {
    final spots = <FlSpot>[
      for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].ratingAfter!),
    ];
    final values = pts.map((p) => p.ratingAfter!).toList();
    final minY = (values.reduce((a, b) => a < b ? a : b) - 0.5).clamp(1.0, 7.0);
    final maxY = (values.reduce((a, b) => a > b ? a : b) + 0.5).clamp(1.0, 7.0);

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 1,
              getTitlesWidget: (v, _) =>
                  Text(v.toStringAsFixed(0), style: theme.textTheme.bodySmall),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.brand,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.brand.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
