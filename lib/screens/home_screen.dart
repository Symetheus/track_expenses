import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:intl/intl.dart';
import '../dimens.dart';
import '../models/import_record.dart';
import '../providers/expenses_provider.dart';
import '../services/import_history_service.dart';
import 'review_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDragOver = false;

  Future<void> _openRecord(ImportRecord record) async {
    final provider = context.read<ExpensesProvider>();
    await provider.restoreFromRecord(record);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReviewScreen()));
  }

  Future<void> _pickAndImport() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      dialogTitle: 'Importer le CSV Société Générale',
    );
    if (result == null || result.files.single.path == null) return;
    await _importFromPath(result.files.single.path!);
  }

  Future<void> _importFromPath(String path) async {
    if (!path.toLowerCase().endsWith('.csv')) {
      if (mounted) _showError('Le fichier doit être un CSV (.csv)');
      return;
    }
    if (!context.mounted) return;
    final provider = context.read<ExpensesProvider>();
    await provider.importFromFile(path);
    if (!context.mounted) return;
    if (provider.state == LoadingState.success) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReviewScreen()));
    } else {
      _showError(provider.errorMessage);
    }
  }

  Future<void> _confirmDelete(ImportRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 36),
        title: const Text('Supprimer cet import ?'),
        content: Text(
          '« ${record.originalFileName} »\n\n'
          'La copie du fichier CSV et toutes ses dépenses '
          'seront définitivement supprimées.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<ImportHistoryService>().deleteRecord(record.id);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 40),
        title: const Text('Erreur d\'import'),
        content: Text(message),
        actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = context.watch<ExpensesProvider>().state == LoadingState.loading;
    final history = context.watch<ImportHistoryService>().history;

    return DropTarget(
      onDragDone: (details) {
        setState(() => _isDragOver = false);
        if (details.files.isNotEmpty) _importFromPath(details.files.first.path);
      },
      onDragEntered: (_) => setState(() => _isDragOver = true),
      onDragExited: (_) => setState(() => _isDragOver = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: _isDragOver
            ? BoxDecoration(
                border: Border.all(color: colorScheme.primary, width: 3),
                borderRadius: BorderRadius.circular(Dimens.radiusXxl),
                color: colorScheme.primaryContainer.withValues(alpha: 0.15),
              )
            : null,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Dimens.maxWidthHome),
            child: CustomScrollView(
              slivers: [
                // ── En-tête + bouton import ────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Dimens.homePadding,
                      Dimens.homePadding,
                      Dimens.homePadding,
                      Dimens.space24,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: Dimens.homeIconSize,
                          height: Dimens.homeIconSize,
                          decoration: BoxDecoration(
                            color: _isDragOver ? colorScheme.primary : colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(Dimens.radiusHero),
                          ),
                          child: Icon(
                            _isDragOver ? Icons.file_download : Icons.receipt_long,
                            size: Dimens.iconHero,
                            color: _isDragOver ? colorScheme.onPrimary : colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: Dimens.space32),
                        Text(
                          _isDragOver ? 'Dépose ton CSV ici !' : 'SG vers Notion',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _isDragOver ? colorScheme.primary : null,
                          ),
                        ),
                        const SizedBox(height: Dimens.spaceL),
                        Text(
                          'Importe ton relevé CSV de la Société Générale,\n'
                          'révise les libellés et catégories, puis exporte\n'
                          'directement vers ta base Notion.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Dimens.space32),
                        SizedBox(
                          width: double.infinity,
                          height: Dimens.buttonHeightL,
                          child: FilledButton.icon(
                            onPressed: isLoading ? null : _pickAndImport,
                            icon: isLoading
                                ? const SizedBox(
                                    width: Dimens.spaceXxl,
                                    height: Dimens.spaceXxl,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.upload_file),
                            label: Text(
                              isLoading ? 'Chargement...' : 'Importer un CSV SG',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: Dimens.spaceL),
                        Text(
                          'ou glisse-dépose ton fichier CSV ici',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Historique des imports ─────────────────────────────
                if (history.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Dimens.homePadding),
                      child: Row(
                        children: [
                          Icon(Icons.history, size: Dimens.iconL, color: colorScheme.primary),
                          const SizedBox(width: Dimens.spaceM),
                          Text(
                            'Imports en cours',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
                          ),
                          const SizedBox(width: Dimens.spaceM),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: Dimens.spaceM, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(Dimens.radiusL),
                            ),
                            child: Text(
                              '${history.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: Dimens.spaceM)),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _ImportRecordCard(
                        record: history[i],
                        onOpen: () => _openRecord(history[i]),
                        onDelete: () => _confirmDelete(history[i]),
                      ),
                      childCount: history.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: Dimens.space24)),
                ],

                // ── Info format ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Dimens.homePadding, 0, Dimens.homePadding, Dimens.homePadding),
                    child: Container(
                      padding: const EdgeInsets.all(Dimens.spaceXl),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(Dimens.radiusXl),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: Dimens.iconS, color: colorScheme.primary),
                              const SizedBox(width: Dimens.spaceM),
                              Text(
                                'Format attendu (CSV Société Générale)',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Dimens.spaceM),
                          _infoRow(context, 'Colonnes', 'Date, Libellé, Détail, Montant, Devise'),
                          _infoRow(context, 'Séparateur', 'Point-virgule (;)'),
                          _infoRow(context, 'Format date', 'JJ/MM/AAAA'),
                          _infoRow(context, 'Encodage', 'Latin-1 (Windows-1252)'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: Dimens.infoLabelWidthHome,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ── Carte d'un import historisé ───────────────────────────────────────────────

class _ImportRecordCard extends StatelessWidget {
  final ImportRecord record;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _ImportRecordCard({required this.record, required this.onOpen, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isComplete = record.allReviewed;
    final dateStr = DateFormat('d MMM yyyy', 'fr_FR').format(record.importedAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.homePadding, vertical: Dimens.spaceS),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(Dimens.radiusXxl),
          border: Border.all(color: isComplete ? Colors.green.shade300 : colorScheme.outlineVariant, width: 1.5),
        ),
        padding: const EdgeInsets.all(Dimens.spaceXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                Icon(
                  isComplete ? Icons.check_circle_outline : Icons.hourglass_empty,
                  size: Dimens.iconL,
                  color: isComplete ? Colors.green.shade600 : colorScheme.primary,
                ),
                const SizedBox(width: Dimens.spaceM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.originalFileName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(dateStr, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Dimens.spaceM, vertical: Dimens.spaceXxs),
                  decoration: BoxDecoration(
                    color: isComplete ? Colors.green.shade50 : colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(Dimens.radiusL),
                  ),
                  child: Text(
                    isComplete ? '✅ Prêt' : '🟡 En cours',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isComplete ? Colors.green.shade700 : colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimens.spaceL),

            // Progression
            Row(
              children: [
                Text(
                  '${record.reviewedCount} / ${record.totalCount} révisées',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  '${(record.progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isComplete ? Colors.green.shade700 : colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimens.spaceXs),
            ClipRRect(
              borderRadius: BorderRadius.circular(Dimens.radiusXs),
              child: LinearProgressIndicator(
                value: record.progress,
                minHeight: Dimens.spaceS,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(isComplete ? Colors.green : colorScheme.primary),
              ),
            ),
            const SizedBox(height: Dimens.spaceL),

            // Actions
            Row(
              children: [
                IconButton.outlined(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  style: IconButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error.withValues(alpha: 0.4)),
                  ),
                  tooltip: 'Supprimer cet import',
                ),
                const SizedBox(width: Dimens.spaceM),
                Expanded(
                  child: SizedBox(
                    height: Dimens.buttonHeightM,
                    child: FilledButton.icon(
                      onPressed: onOpen,
                      icon: Icon(isComplete ? Icons.send : Icons.play_arrow, size: Dimens.iconM),
                      label: Text(
                        isComplete ? 'Exporter' : 'Reprendre',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
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
