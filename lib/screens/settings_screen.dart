import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dimens.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../services/merchant_memory_service.dart';
import '../services/notion_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _tokenController;
  late TextEditingController _dbIdController;
  // Colonnes Notion
  late TextEditingController _colNameController;
  late TextEditingController _colDateController;
  late TextEditingController _colAmountController;
  late TextEditingController _colCategoryController;
  late TextEditingController _colPaymentController;

  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;
  bool _tokenObscured = true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _tokenController = TextEditingController(text: settings.notionToken);
    _dbIdController = TextEditingController(text: settings.notionDatabaseId);
    _colNameController = TextEditingController(text: settings.notionColumns.name);
    _colDateController = TextEditingController(text: settings.notionColumns.date);
    _colAmountController = TextEditingController(text: settings.notionColumns.amount);
    _colCategoryController = TextEditingController(text: settings.notionColumns.category);
    _colPaymentController = TextEditingController(text: settings.notionColumns.paymentMethod);
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _dbIdController.dispose();
    _colNameController.dispose();
    _colDateController.dispose();
    _colAmountController.dispose();
    _colCategoryController.dispose();
    _colPaymentController.dispose();
    super.dispose();
  }

  Future<void> _saveNotionConfig() async {
    final token = _tokenController.text.trim();
    final databaseId = _dbIdController.text.trim();
    await context.read<SettingsProvider>().updateNotionConfig(token: token, databaseId: databaseId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Configuration sauvegardée')));
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });
    try {
      final service = NotionService(token: _tokenController.text.trim(), databaseId: _dbIdController.text.trim());
      await service.testConnection();
      setState(() {
        _testSuccess = true;
        _testResult = '✅ Connexion réussie !';
      });
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = '❌ ${e.toString().replaceFirst('Exception: ', '')}';
      });
    } finally {
      setState(() => _isTesting = false);
    }
  }

  void _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nom de la catégorie'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Ajouter')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      await context.read<SettingsProvider>().addCategory(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>().settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(Dimens.spaceXxl),
        children: [
          _sectionHeader(context, 'Notion API', Icons.cloud),
          const SizedBox(height: Dimens.spaceM),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Dimens.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configure ton intégration Notion pour envoyer les dépenses directement.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: Dimens.spaceXl),
                  TextField(
                    controller: _tokenController,
                    obscureText: _tokenObscured,
                    decoration: InputDecoration(
                      labelText: 'Token d\'intégration Notion',
                      hintText: 'secret_xxxxxxxxxxxx',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.vpn_key),
                      suffixIcon: IconButton(
                        icon: Icon(_tokenObscured ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _tokenObscured = !_tokenObscured),
                      ),
                      helperText: 'Créer sur notion.so/my-integrations',
                    ),
                  ),
                  const SizedBox(height: Dimens.spaceXl),
                  TextField(
                    controller: _dbIdController,
                    decoration: const InputDecoration(
                      labelText: 'ID de la base de données',
                      hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.table_chart),
                      helperText: 'Dans l\'URL Notion de ta base',
                    ),
                  ),
                  const SizedBox(height: Dimens.spaceXl),
                  if (_testResult != null)
                    Container(
                      padding: const EdgeInsets.all(Dimens.spaceL),
                      margin: const EdgeInsets.only(bottom: Dimens.spaceL),
                      decoration: BoxDecoration(
                        color: _testSuccess ? Colors.green.shade50 : colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(Dimens.radiusM),
                      ),
                      child: Text(
                        _testResult!,
                        style: TextStyle(color: _testSuccess ? Colors.green.shade800 : colorScheme.onErrorContainer),
                      ),
                    ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isTesting ? null : _testConnection,
                        icon: _isTesting
                            ? const SizedBox(
                                width: Dimens.spaceXl,
                                height: Dimens.spaceXl,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering),
                        label: const Text('Tester la connexion'),
                      ),
                      const SizedBox(width: Dimens.spaceL),
                      FilledButton.icon(
                        onPressed: _saveNotionConfig,
                        icon: const Icon(Icons.save),
                        label: const Text('Sauvegarder'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Dimens.space24),

          _sectionHeader(context, 'Colonnes Notion', Icons.view_column),
          const SizedBox(height: Dimens.spaceM),
          _buildColumnsSection(context),
          const SizedBox(height: Dimens.space24),

          _sectionHeader(context, 'Catégories', Icons.label),
          const SizedBox(height: Dimens.spaceM),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Dimens.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gère les catégories disponibles pour classer tes dépenses.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: Dimens.spaceL),
                  Wrap(
                    spacing: Dimens.spaceM,
                    runSpacing: Dimens.spaceS,
                    children: [
                      ...settings.categories.map(
                        (cat) => Chip(
                          label: Text(cat),
                          deleteIcon: const Icon(Icons.close, size: Dimens.iconS),
                          onDeleted: () async {
                            final sp = context.read<SettingsProvider>();
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text('Supprimer "$cat" ?'),
                                content: const Text('Les dépenses avec cette catégorie ne seront pas modifiées.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('Annuler'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: const Text('Supprimer'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && mounted) sp.removeCategory(cat);
                          },
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: Dimens.iconS),
                        label: const Text('Nouvelle catégorie'),
                        onPressed: _showAddCategoryDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Dimens.space24),

          _sectionHeader(context, 'Mémoire marchands', Icons.psychology),
          const SizedBox(height: Dimens.spaceM),
          _buildMemorySection(context),
          const SizedBox(height: Dimens.space24),

          _sectionHeader(context, 'À propos', Icons.info_outline),
          const SizedBox(height: Dimens.spaceM),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Dimens.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(context, 'Application', 'SG → Notion'),
                  _infoRow(context, 'Version', '1.0.0'),
                  _infoRow(context, 'Format Notion', 'Date, Nom, Montant, Catégorie, Moyen de paiement'),
                  _infoRow(context, 'Format SG', 'CSV avec colonnes Date, Libellé, Débit, Crédit'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Renseigne les noms exacts de tes colonnes dans la base Notion\n(respecte les majuscules et accents).',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: Dimens.spaceXl),
            _colField('Nom / Titre de la dépense', _colNameController, Icons.title),
            const SizedBox(height: Dimens.spaceL),
            _colField('Date', _colDateController, Icons.calendar_today),
            const SizedBox(height: Dimens.spaceL),
            _colField('Montant', _colAmountController, Icons.euro),
            const SizedBox(height: Dimens.spaceL),
            _colField('Catégorie', _colCategoryController, Icons.label),
            const SizedBox(height: Dimens.spaceL),
            _colField('Moyen de paiement', _colPaymentController, Icons.credit_card),
            const SizedBox(height: Dimens.spaceXl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saveColumns,
                icon: const Icon(Icons.save),
                label: const Text('Sauvegarder les noms de colonnes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
      ),
    );
  }

  Future<void> _saveColumns() async {
    final columns = NotionColumns(
      name: _colNameController.text.trim(),
      date: _colDateController.text.trim(),
      amount: _colAmountController.text.trim(),
      category: _colCategoryController.text.trim(),
      paymentMethod: _colPaymentController.text.trim(),
    );
    await context.read<SettingsProvider>().updateNotionColumns(columns);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Noms de colonnes sauvegardés')));
    }
  }

  Widget _buildMemorySection(BuildContext context) {
    final memory = context.watch<MerchantMemoryService>();
    final mappings = memory.allMappings;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'L\'app mémorise tes choix de catégories par marchand pour les prochains imports.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: Dimens.spaceM),
            Row(
              children: [
                Icon(Icons.storage, size: Dimens.iconXs, color: colorScheme.outline),
                const SizedBox(width: Dimens.spaceS),
                Text(
                  '${memory.count} marchand${memory.count > 1 ? 's' : ''} mémorisé${memory.count > 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                ),
                const Spacer(),
                if (mappings.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _confirmClearMemory(context, memory),
                    icon: const Icon(Icons.delete_sweep, size: Dimens.iconS),
                    label: const Text('Tout effacer'),
                    style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                  ),
              ],
            ),
            if (mappings.isNotEmpty) ...[
              const Divider(height: 20),
              ...mappings.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: Dimens.spaceXxs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: Dimens.spaceM, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(Dimens.radiusL),
                        ),
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: Dimens.spaceXs),
                      IconButton(
                        icon: const Icon(Icons.close, size: Dimens.iconXs),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        onPressed: () => memory.removeEntry(entry.key),
                        tooltip: 'Supprimer cette association',
                      ),
                    ],
                  ),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: Dimens.spaceM),
                child: Text(
                  'Aucune association mémorisée pour l\'instant.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.outline, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmClearMemory(BuildContext context, MerchantMemoryService memory) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer la mémoire ?'),
        content: const Text(
          'Toutes les associations marchand → catégorie seront supprimées.\n'
          'Les prochains imports n\'auront plus de suggestions apprises.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              for (final key in memory.allMappings.keys.toList()) {
                memory.removeEntry(key);
              }
            },
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: Dimens.iconL, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: Dimens.spaceM),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
        ),
      ],
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimens.spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: Dimens.infoLabelWidthSettings,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
