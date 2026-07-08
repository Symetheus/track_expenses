import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../dimens.dart';
import '../models/expense.dart';
import '../providers/expenses_provider.dart';
import '../providers/settings_provider.dart';
import '../services/csv_export_service.dart';
import '../services/notion_service.dart';
import '../widgets/expense_card.dart';
import '../widgets/progress_header.dart';

enum ReviewFilter { all, toReview, reviewed, sent, ignored }

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  String? _expandedId;
  bool _isExporting = false;
  ReviewFilter _filter = ReviewFilter.all;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Expense> _applyFilter(List<Expense> all) => switch (_filter) {
        ReviewFilter.all      => all,
        ReviewFilter.toReview => all.where((e) => !e.isProcessed).toList(),
        ReviewFilter.reviewed => all.where((e) => e.isReviewed && !e.sentToNotion && !e.isIgnored).toList(),
        ReviewFilter.sent     => all.where((e) => e.sentToNotion).toList(),
        ReviewFilter.ignored  => all.where((e) => e.isIgnored).toList(),
      };

  void _toggleExpand(String id) {
    setState(() => _expandedId = _expandedId == id ? null : id);
  }

  /// Après validation → ouvre la prochaine non traitée (ignore les ignorées).
  void _onExpenseValidated() {
    final expenses = context.read<ExpensesProvider>().expenses;
    final currentIdx = expenses.indexWhere((e) => e.id == _expandedId);
    Expense? next;
    for (int i = currentIdx + 1; i < expenses.length; i++) {
      if (!expenses[i].isProcessed) { next = expenses[i]; break; }
    }
    if (next == null) {
      for (final e in expenses) {
        if (!e.isProcessed) { next = e; break; }
      }
    }
    setState(() => _expandedId = next?.id);
    if (next != null) {
      final idx = expenses.indexOf(next);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            (idx * 110.0).clamp(0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _exportCsv() async {
    final provider = context.read<ExpensesProvider>();
    final settings = context.read<SettingsProvider>().settings;
    final toExport = provider.expenses.where((e) => e.isComplete).toList();
    if (toExport.isEmpty) {
      _showSnack('Aucune dépense complète à exporter.');
      return;
    }

    final path = await FilePicker.saveFile(
      dialogTitle: 'Enregistrer le CSV Notion',
      fileName: 'depenses_notion.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return;

    setState(() => _isExporting = true);
    try {
      await CsvExportService.saveToFile(toExport, path, settings.notionColumns);
      _showSnack('✅ ${toExport.length} dépenses exportées vers $path');
    } catch (e) {
      _showSnack('Erreur : $e', isError: true);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToNotion() async {
    final settings = context.read<SettingsProvider>().settings;
    if (!settings.isNotionConfigured) {
      _showNotionConfigDialog();
      return;
    }

    final provider = context.read<ExpensesProvider>();
    final count = provider.expenses.where((e) => e.isComplete && !e.sentToNotion).length;
    if (count == 0) {
      _showSnack('Aucune nouvelle dépense à envoyer (toutes déjà envoyées ?)');
      return;
    }

    // Confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Envoyer vers Notion ?'),
        content: Text(
          '$count nouvelle${count > 1 ? 's' : ''} dépense${count > 1 ? 's' : ''} '
          'seront ajoutées à ta base Notion.\n'
          'Cette action ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.send),
            label: const Text('Envoyer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isExporting = true);

    try {
      final service = NotionService(
        token: settings.notionToken,
        databaseId: settings.notionDatabaseId,
        columns: settings.notionColumns,
      );
      await service.testConnection();

      if (!mounted) return;

      final sent = await provider.exportToNotion(service);
      _showSnack('✅ $sent dépenses envoyées vers Notion !');
    } catch (e) {
      _showSnack('Erreur Notion : $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showNotionConfigDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notion non configuré'),
        content: const Text(
          'Configure ton token Notion et l\'ID de ta base dans les paramètres.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamed('/settings');
            },
            child: const Text('Ouvrir les paramètres'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpensesProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final expenses = provider.expenses;
    final filtered = _applyFilter(expenses);
    final reviewed = provider.reviewedCount;
    final complete = provider.completeCount;
    final total = provider.totalCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.importedFileName ?? 'Révision des dépenses'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            showDialog(
              context: context,
                builder: (ctx) => AlertDialog(
                title: const Text('Quitter la révision ?'),
                content: const Text(
                  'Ta progression est sauvegardée automatiquement.\n'
                  'Tu pourras reprendre depuis l\'accueil.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Rester'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await context.read<ExpensesProvider>().reset();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Quitter'),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de progression
          ProgressHeader(reviewed: reviewed, total: total),

          // Filtres
          _FilterBar(
            filter: _filter,
            counts: {
              ReviewFilter.all:      total,
              ReviewFilter.toReview: expenses.where((e) => !e.isProcessed).length,
              ReviewFilter.reviewed: expenses.where((e) => e.isReviewed && !e.sentToNotion && !e.isIgnored).length,
              ReviewFilter.sent:     provider.sentCount,
              ReviewFilter.ignored:  provider.ignoredCount,
            },
            onChanged: (f) => setState(() {
              _filter = f;
              _expandedId = null;
            }),
          ),

          // Indicateur export en cours
          if (_isExporting)
            LinearProgressIndicator(backgroundColor: colorScheme.surfaceContainerHighest),

          // Liste filtrée
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Dimens.maxWidthReview),
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _filter == ReviewFilter.all
                              ? 'Aucune dépense à afficher.'
                              : 'Aucune dépense dans ce filtre.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final expense = filtered[i];
                          return ExpenseCard(
                            key: ValueKey(expense.id),
                            expense: expense,
                            isExpanded: _expandedId == expense.id,
                            onTap: () => _toggleExpand(expense.id),
                            onValidated: _onExpenseValidated,
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
      // Barre d'export fixe en bas
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Dimens.spaceXl, vertical: Dimens.spaceL),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: Dimens.spaceM,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Résumé
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$complete à envoyer',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${provider.sentCount} déjà envoyée${provider.sentCount > 1 ? 's' : ''} · $total au total',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                ),
              ],
            ),
            const Spacer(),
            // Export CSV
            OutlinedButton.icon(
              onPressed: _isExporting || complete == 0 ? null : _exportCsv,
              icon: const Icon(Icons.download),
              label: const Text('Export CSV'),
            ),
            const SizedBox(width: 12),
            // Export Notion
            FilledButton.icon(
              onPressed: _isExporting || complete == 0 ? null : _exportToNotion,
              icon: const Icon(Icons.send),
              label: const Text('Envoyer vers Notion'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barre de filtres ───────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final ReviewFilter filter;
  final Map<ReviewFilter, int> counts;
  final void Function(ReviewFilter) onChanged;

  const _FilterBar({
    required this.filter,
    required this.counts,
    required this.onChanged,
  });

  static const _labels = {
    ReviewFilter.all:      ('Tout',      null),
    ReviewFilter.toReview: ('À réviser', Colors.orange),
    ReviewFilter.reviewed: ('Révisés',   Colors.green),
    ReviewFilter.sent:     ('Envoyés',   Colors.blue),
    ReviewFilter.ignored:  ('Ignorés',   Colors.grey),
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(
          horizontal: Dimens.spaceXl, vertical: Dimens.spaceM),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: Dimens.spaceM,
          children: ReviewFilter.values.map((f) {
            final isSelected = f == filter;
            final (label, color) = _labels[f]!;
            final count = counts[f] ?? 0;
            if (f != ReviewFilter.all && count == 0) return const SizedBox.shrink();
            return FilterChip(
              label: Text('$label  $count'),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onChanged(f),
              selectedColor: color != null
                  ? Color.lerp(color, Colors.white, 0.7)
                  : colorScheme.primaryContainer,
              labelStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
                color: isSelected && color != null ? color.shade700 : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

