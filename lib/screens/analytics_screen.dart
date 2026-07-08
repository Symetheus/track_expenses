import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../dimens.dart';
import '../providers/analytics_provider.dart';
import '../providers/settings_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _touchedPieIndex = -1;

  static const _frMonths = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];

  static const _palette = [
    Color(0xFF6C63FF),
    Color(0xFF48CAE4),
    Color(0xFF06D6A0),
    Color(0xFFFFB347),
    Color(0xFFFF6B6B),
    Color(0xFFFF9FF3),
    Color(0xFF54A0FF),
    Color(0xFFFECA57),
    Color(0xFF5F27CD),
    Color(0xFF00D2D3),
    Color(0xFFFF9F43),
    Color(0xFFEE5A24),
  ];

  @override
  Widget build(BuildContext context) {
    final analytics = context.watch<AnalyticsProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFmt = NumberFormat('#,##0.00', 'fr_FR');
    final compactFmt = NumberFormat('#,##0', 'fr_FR');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960.0),
        child: CustomScrollView(
          slivers: [
            // ── En-tête ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Dimens.homePadding, 28, Dimens.homePadding, 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(Dimens.radiusXl),
                      ),
                      child: Icon(Icons.bar_chart, size: Dimens.iconXl, color: colorScheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: Dimens.spaceM),
                    Text(
                      'Analyses',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (!settings.isNotionConfigured)
                      Tooltip(
                        message: 'Configure Notion dans les Paramètres',
                        child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                      ),
                    const SizedBox(width: Dimens.spaceM),
                    FilledButton.icon(
                      onPressed: settings.isNotionConfigured && analytics.state != AnalyticsLoadState.loading
                          ? () => context.read<AnalyticsProvider>().fetchFromNotion(settings)
                          : null,
                      icon: analytics.state == AnalyticsLoadState.loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(
                        analytics.state == AnalyticsLoadState.idle ? 'Charger depuis Notion' : 'Actualiser',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Contenu dynamique ─────────────────────────────────────
            if (!settings.isNotionConfigured)
              SliverToBoxAdapter(child: _buildNotionNotConfigured(context))
            else if (analytics.state == AnalyticsLoadState.idle)
              SliverToBoxAdapter(child: _buildIdleState(context, colorScheme))
            else if (analytics.state == AnalyticsLoadState.loading)
              SliverToBoxAdapter(child: _buildLoading())
            else if (analytics.state == AnalyticsLoadState.error)
              SliverToBoxAdapter(child: _buildError(context, analytics.errorMessage, colorScheme))
            else ...[
              // Filtre par année
              SliverToBoxAdapter(child: _buildYearFilter(context, analytics, colorScheme)),

              // Cartes stats
              SliverToBoxAdapter(child: _buildStats(context, analytics, currencyFmt, colorScheme)),

              // Graphiques (si données)
              if (analytics.filteredExpenses.isNotEmpty) ...[
                SliverToBoxAdapter(child: _buildMonthlyChart(context, analytics, compactFmt, colorScheme)),
                SliverToBoxAdapter(child: _buildCategoryChart(context, analytics, currencyFmt, colorScheme)),
              ] else
                SliverToBoxAdapter(child: _buildNoData(context, colorScheme)),

              const SliverToBoxAdapter(child: SizedBox(height: Dimens.space40)),
            ],
          ],
        ),
      ),
    );
  }

  // ── États vides / chargement / erreur ─────────────────────────────────────

  Widget _buildNotionNotConfigured(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Dimens.homePadding),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Dimens.space32),
          child: Column(
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
              const SizedBox(height: Dimens.spaceXl),
              Text('Notion non configuré', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Dimens.spaceM),
              Text(
                'Configure ton token et l\'ID de ta base dans les Paramètres\n'
                'pour accéder aux analyses.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Dimens.spaceXl),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/settings'),
                icon: const Icon(Icons.settings),
                label: const Text('Aller dans les Paramètres'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdleState(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.homePadding, vertical: Dimens.space32),
      child: Container(
        padding: const EdgeInsets.all(Dimens.space32),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Dimens.radiusXxl),
        ),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 80, color: cs.primary.withValues(alpha: 0.35)),
            const SizedBox(height: Dimens.spaceXl),
            Text(
              'Tes analyses t\'attendent !',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: Dimens.spaceM),
            Text(
              'Clique sur "Charger depuis Notion" pour récupérer\n'
              'tes dépenses et afficher les graphiques.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.all(Dimens.space40),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: Dimens.spaceXl),
          Text('Chargement des données Notion…'),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String msg, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(Dimens.homePadding),
      child: Container(
        padding: const EdgeInsets.all(Dimens.spaceXl),
        decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(Dimens.radiusXl)),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: cs.onErrorContainer),
            const SizedBox(width: Dimens.spaceM),
            Expanded(
              child: Text(msg, style: TextStyle(color: cs.onErrorContainer)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoData(BuildContext context, ColorScheme cs) {
    final analytics = context.read<AnalyticsProvider>();
    final period = analytics.selectedYear != null ? 'l\'année ${analytics.selectedYear}' : 'toutes les années';
    return Padding(
      padding: const EdgeInsets.all(Dimens.homePadding),
      child: Container(
        padding: const EdgeInsets.all(Dimens.spaceXl),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Dimens.radiusXl),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: Dimens.spaceM),
            Text(
              'Aucune dépense pour $period',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Dimens.spaceS),
            Text(
              'Essaie de sélectionner une autre période ou recharge les données.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Filtre année ──────────────────────────────────────────────────────────

  Widget _buildYearFilter(BuildContext context, AnalyticsProvider a, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimens.homePadding, 0, Dimens.homePadding, Dimens.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Période', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: Dimens.spaceS),
          Wrap(
            spacing: Dimens.spaceM,
            runSpacing: Dimens.spaceS,
            children: [
              FilterChip(
                label: const Text('Tout'),
                selected: a.selectedYear == null,
                onSelected: (_) => context.read<AnalyticsProvider>().setSelectedYear(null),
              ),
              ...a.availableYears.map(
                (y) => FilterChip(
                  label: Text('$y'),
                  selected: a.selectedYear == y,
                  onSelected: (_) => context.read<AnalyticsProvider>().setSelectedYear(y),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Cartes de statistiques ────────────────────────────────────────────────

  Widget _buildStats(BuildContext context, AnalyticsProvider a, NumberFormat fmt, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimens.homePadding, 0, Dimens.homePadding, Dimens.spaceXl),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.euro_rounded,
              label: 'Total dépensé',
              value: '${fmt.format(a.totalSpending)} €',
              color: cs.primary,
            ),
          ),
          const SizedBox(width: Dimens.spaceM),
          Expanded(
            child: _StatCard(
              icon: Icons.receipt_long,
              label: 'Transactions',
              value: '${a.transactionCount}',
              color: cs.secondary,
            ),
          ),
          const SizedBox(width: Dimens.spaceM),
          Expanded(
            child: _StatCard(
              icon: Icons.label_rounded,
              label: 'Catégorie #1',
              value: a.topCategory ?? '–',
              color: cs.tertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Graphique en barres (mensuel) ─────────────────────────────────────────

  Widget _buildMonthlyChart(BuildContext context, AnalyticsProvider a, NumberFormat compactFmt, ColorScheme cs) {
    final List<String> labels;
    final List<double> values;

    if (a.selectedYear != null) {
      // 12 mois de l'année sélectionnée
      labels = _frMonths.toList();
      values = List.generate(12, (i) {
        final key = '${a.selectedYear}-${(i + 1).toString().padLeft(2, '0')}';
        return a.monthlyTotals[key] ?? 0.0;
      });
    } else {
      // Tous les mois disponibles triés
      final sortedKeys = a.monthlyTotals.keys.toList()..sort();
      labels = sortedKeys.map((k) {
        final parts = k.split('-');
        final yr = parts[0].substring(2);
        final mo = int.parse(parts[1]);
        return "${_frMonths[mo - 1]} '$yr";
      }).toList();
      values = sortedKeys.map((k) => a.monthlyTotals[k]!).toList();
    }

    if (values.isEmpty) return const SizedBox.shrink();

    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal <= 0 ? 100.0 : maxVal * 1.25;
    final barWidth = a.selectedYear != null ? 22.0 : 14.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimens.homePadding, 0, Dimens.homePadding, Dimens.spaceXl),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Dimens.spaceXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dépenses par mois',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: Dimens.spaceXl),
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: effectiveMax,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => cs.inverseSurface,
                        getTooltipItem: (group, p1, rod, p2) => BarTooltipItem(
                          '${labels[group.x]}\n${compactFmt.format(rod.toY.toInt())} €',
                          TextStyle(color: cs.onInverseSurface, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (v, meta) {
                            final i = v.toInt();
                            if (i < 0 || i >= labels.length) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(labels[i], style: const TextStyle(fontSize: 10)),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 56,
                          getTitlesWidget: (v, meta) {
                            if (v == 0 || v == meta.max) {
                              return const SizedBox.shrink();
                            }
                            final label = maxVal >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k€' : '${v.toInt()}€';
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(label, style: const TextStyle(fontSize: 10)),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: cs.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
                    ),
                    barGroups: List.generate(values.length, (i) {
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: values[i],
                            color: values[i] > 0 ? cs.primary : cs.surfaceContainerHighest,
                            width: barWidth,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Graphique en camembert (catégories) ───────────────────────────────────

  Widget _buildCategoryChart(BuildContext context, AnalyticsProvider a, NumberFormat fmt, ColorScheme cs) {
    final catMap = a.categoryTotals;
    if (catMap.isEmpty) return const SizedBox.shrink();

    final sorted = catMap.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
    final total = a.totalSpending;

    final sections = List.generate(sorted.length, (i) {
      final entry = sorted[i];
      final color = _palette[i % _palette.length];
      final isTouched = i == _touchedPieIndex;
      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: isTouched
            ? '${fmt.format(entry.value)} €'
            : total > 0
            ? '${(entry.value / total * 100).toStringAsFixed(1)}%'
            : '',
        radius: isTouched ? 95.0 : 82.0,
        titleStyle: TextStyle(
          fontSize: isTouched ? 13.0 : 11.0,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
        ),
      );
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimens.homePadding, 0, Dimens.homePadding, Dimens.spaceXl),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Dimens.spaceXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Répartition par catégorie',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: Dimens.spaceXl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Camembert
                  SizedBox(
                    width: 230,
                    height: 230,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 48,
                        sectionsSpace: 2,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  response == null ||
                                  response.touchedSection == null) {
                                _touchedPieIndex = -1;
                                return;
                              }
                              _touchedPieIndex = response.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Dimens.space24),
                  // Légende
                  Expanded(
                    child: Wrap(
                      spacing: Dimens.spaceM,
                      runSpacing: Dimens.spaceM,
                      children: List.generate(sorted.length, (i) {
                        final entry = sorted[i];
                        final color = _palette[i % _palette.length];
                        final pct = total > 0 ? '${(entry.value / total * 100).toStringAsFixed(1)}%' : '0%';
                        return _LegendItem(
                          color: color,
                          label: entry.key,
                          amount: '${fmt.format(entry.value)} €',
                          percent: pct,
                          isSelected: i == _touchedPieIndex,
                        );
                      }),
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
}

// ── Carte statistique ─────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Dimens.spaceXl),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Dimens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: Dimens.iconL, color: color),
          const SizedBox(height: Dimens.spaceM),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: Dimens.spaceXxs),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Élément de légende ────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String amount;
  final String percent;
  final bool isSelected;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.amount,
    required this.percent,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: Dimens.spaceL, vertical: Dimens.spaceM),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.15) : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Dimens.radiusM),
        border: isSelected ? Border.all(color: color, width: 1.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: Dimens.spaceM),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              Text(
                '$amount · $percent',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
