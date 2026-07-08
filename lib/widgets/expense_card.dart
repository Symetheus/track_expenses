import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../dimens.dart';
import '../models/app_settings.dart';
import '../models/expense.dart';
import '../providers/expenses_provider.dart';
import '../providers/settings_provider.dart';
import '../services/category_suggestion_service.dart';
import 'category_selector.dart';

/// Carte représentant une dépense dans la liste de révision.
/// - Repliée (non étendue) : affiche le résumé
/// - Étendue : affiche le formulaire d'édition (qu'elle soit validée ou non)
class ExpenseCard extends StatefulWidget {
  final Expense expense;
  final bool isExpanded;
  final VoidCallback onTap;

  /// Appelé après validation — permet au parent d'ouvrir la prochaine dépense.
  final VoidCallback? onValidated;

  const ExpenseCard({
    super.key,
    required this.expense,
    required this.isExpanded,
    required this.onTap,
    this.onValidated,
  });

  @override
  State<ExpenseCard> createState() => _ExpenseCardState();
}

class _ExpenseCardState extends State<ExpenseCard> {
  late TextEditingController _nameController;
  String? _selectedCategory;
  late String _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    _syncFromExpense();
    if (widget.isExpanded) HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void didUpdateWidget(covariant ExpenseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resynchroniser si la dépense change (ex: après import ou reset)
    if (oldWidget.expense.id != widget.expense.id) {
      _syncFromExpense();
    }
    // Resynchroniser quand la carte est ré-ouverte (re-édition)
    if (!oldWidget.isExpanded && widget.isExpanded) {
      _syncFromExpense();
      HardwareKeyboard.instance.addHandler(_onKey);
    } else if (oldWidget.isExpanded && !widget.isExpanded) {
      HardwareKeyboard.instance.removeHandler(_onKey);
    }
  }

  void _syncFromExpense() {
    _nameController = TextEditingController(text: widget.expense.cleanName);
    _selectedCategory = widget.expense.category;
    _selectedPaymentMethod = widget.expense.paymentMethod;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _nameController.dispose();
    super.dispose();
  }

  /// Handler global clavier — actif uniquement quand la carte est ouverte.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    // Échap → ferme la carte
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onTap();
      return true;
    }
    return false;
  }

  Future<void> _validate() async {
    final provider = context.read<ExpensesProvider>();
    await provider.updateExpense(
      widget.expense.id,
      cleanName: _nameController.text.trim(),
      category: _selectedCategory,
      paymentMethod: _selectedPaymentMethod,
      isReviewed: true,
    );
    widget.onValidated?.call();
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
      setState(() => _selectedCategory = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>().settings;
    final expense = widget.expense;
    final suggested = CategorySuggestionService.suggest(expense.rawLabel);
    final isReviewed = expense.isReviewed;
    final isSent = expense.sentToNotion;

    final amountColor = expense.isDebit ? colorScheme.error : Colors.green.shade700;

    return Opacity(
      opacity: expense.isIgnored ? 0.5 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: Dimens.spaceXl, vertical: Dimens.spaceS),
        elevation: widget.isExpanded ? 3 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusXl),
          side: expense.isIgnored && !widget.isExpanded
              ? BorderSide(color: colorScheme.outline.withValues(alpha: 0.3), width: 1)
              : isSent && !widget.isExpanded
              ? BorderSide(color: Colors.blue.shade200, width: 1.5)
              : isReviewed && !widget.isExpanded
              ? BorderSide(color: Colors.green.shade300, width: 1.5)
              : widget.isExpanded
              ? BorderSide(color: colorScheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(Dimens.radiusXl),
          child: Padding(
            padding: const EdgeInsets.all(Dimens.spaceXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── En-tête ──────────────────────────────────────────────────
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: Dimens.iconXs, color: colorScheme.outline),
                    const SizedBox(width: Dimens.spaceXs),
                    Text(
                      expense.formattedDate,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                    ),
                    const Spacer(),
                    Text(
                      expense.formattedAmount,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: amountColor, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: Dimens.spaceM),
                    if (isSent && !widget.isExpanded)
                      Tooltip(
                        message: 'Envoyé vers Notion',
                        child: Icon(Icons.cloud_done, color: Colors.blue.shade400, size: Dimens.spaceXxl),
                      )
                    else if (expense.isIgnored && !widget.isExpanded)
                      Tooltip(
                        message: 'Ignorée — cliquer pour ré-ouvrir',
                        child: Icon(Icons.block, color: colorScheme.outline, size: Dimens.spaceXxl),
                      )
                    else if (isReviewed && !widget.isExpanded)
                      Tooltip(
                        message: 'Modifier',
                        child: Icon(Icons.check_circle, color: Colors.green.shade600, size: Dimens.spaceXxl),
                      )
                    else if (!isReviewed && !expense.isIgnored)
                      // Bouton ignorer rapide (sans ouvrir la carte)
                      Tooltip(
                        message: 'Ignorer cette dépense',
                        child: GestureDetector(
                          onTap: () => context.read<ExpensesProvider>().toggleIgnore(expense.id),
                          child: Icon(Icons.remove_circle_outline, color: colorScheme.outline, size: Dimens.spaceXxl),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Dimens.spaceM),
                // ── Nom résumé ────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isReviewed ? expense.cleanName : expense.rawLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isReviewed && !isSent && !widget.isExpanded) ...[
                      const SizedBox(width: Dimens.spaceM),
                      Icon(Icons.edit_outlined, size: Dimens.iconXs, color: colorScheme.outline),
                    ],
                    if (isSent && !widget.isExpanded) ...[
                      const SizedBox(width: Dimens.spaceM),
                      Icon(Icons.lock_outline, size: Dimens.iconXs, color: Colors.blue.shade300),
                    ],
                  ],
                ),
                if (isReviewed && !widget.isExpanded) ...[
                  const SizedBox(height: Dimens.spaceS),
                  Row(
                    children: [
                      if (expense.category != null)
                        _summaryChip(
                          context,
                          expense.category!,
                          colorScheme.primaryContainer,
                          colorScheme.onPrimaryContainer,
                        ),
                      const SizedBox(width: Dimens.spaceM),
                      _summaryChip(
                        context,
                        expense.paymentMethod,
                        colorScheme.surfaceContainerHighest,
                        colorScheme.onSurfaceVariant,
                      ),
                      if (isSent) ...[
                        const SizedBox(width: Dimens.spaceM),
                        _summaryChip(context, '📤 Notion', Colors.blue.shade50, Colors.blue.shade700),
                      ],
                    ],
                  ),
                ],
                if (expense.isIgnored && !widget.isExpanded) ...[
                  const SizedBox(height: Dimens.spaceS),
                  _summaryChip(context, '🚫 Ignorée', colorScheme.surfaceContainerHighest, colorScheme.outline),
                ],

                // ── Formulaire d'édition ──────────────────────────────────────
                if (widget.isExpanded) ...[
                  const SizedBox(height: Dimens.spaceL),
                  const Divider(height: 1),
                  const SizedBox(height: Dimens.spaceL),
                  _buildForm(context, colorScheme, expense, isReviewed, isSent, settings, suggested),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Formulaire d'édition d'une dépense avec raccourcis clavier.
  /// - `Escape` → ferme le formulaire
  /// - `Enter` sur le champ nom → valide si catégorie sélectionnée
  Widget _buildForm(
    BuildContext context,
    ColorScheme colorScheme,
    Expense expense,
    bool isReviewed,
    bool isSent,
    AppSettings settings,
    String? suggested,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge modification / déjà envoyé
        if (isReviewed)
          Container(
            margin: const EdgeInsets.only(bottom: Dimens.spaceL),
            padding: const EdgeInsets.symmetric(horizontal: Dimens.spaceM + 2, vertical: Dimens.spaceS),
            decoration: BoxDecoration(
              color: isSent ? Colors.blue.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(Dimens.radiusM),
              border: Border.all(color: isSent ? Colors.blue.shade200 : Colors.orange.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSent ? Icons.cloud_done : Icons.edit,
                  size: Dimens.iconXs,
                  color: isSent ? Colors.blue.shade700 : Colors.orange.shade700,
                ),
                const SizedBox(width: Dimens.spaceS),
                Text(
                  isSent ? 'Déjà envoyée vers Notion — modification possible' : 'Modification d\'une dépense validée',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSent ? Colors.blue.shade800 : Colors.orange.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // Libellé original SG
        Container(
          padding: const EdgeInsets.all(Dimens.spaceM),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Dimens.radiusS),
          ),
          child: Row(
            children: [
              Icon(Icons.receipt_long, size: Dimens.iconXs, color: colorScheme.outline),
              const SizedBox(width: Dimens.spaceS),
              Expanded(
                child: Text(
                  'SG : ${expense.rawLabel}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.outline, fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Dimens.spaceL),

        // Champ nom — Enter valide si catégorie sélectionnée
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Nom de la dépense',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.edit),
            suffixIcon: IconButton(
              icon: const Icon(Icons.restore, size: Dimens.iconM),
              tooltip: 'Remettre le libellé original',
              onPressed: () => _nameController.text = expense.rawLabel,
            ),
          ),
          onSubmitted: (_) {
            if (_selectedCategory != null) _validate();
          },
        ),
        const SizedBox(height: Dimens.spaceXl),

        // Catégorie
        Text('Catégorie', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
        if (suggested != null &&
            (_selectedCategory == null || _selectedCategory == suggested) &&
            !expense.isReviewed) ...[
          const SizedBox(height: Dimens.spaceXs),
          Row(
            children: [
              Icon(Icons.auto_awesome, size: Dimens.iconXs, color: colorScheme.primary),
              const SizedBox(width: Dimens.spaceXs),
              Text(
                'Suggestion : $suggested',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.primary),
              ),
            ],
          ),
        ],
        const SizedBox(height: Dimens.spaceM),
        CategorySelector(
          categories: settings.categories,
          selected: _selectedCategory,
          suggested: suggested,
          onSelected: (cat) => setState(() => _selectedCategory = cat),
          onAddCategory: _showAddCategoryDialog,
        ),
        const SizedBox(height: Dimens.spaceXl),

        // Moyen de paiement
        DropdownButtonFormField<String>(
          initialValue: _selectedPaymentMethod,
          decoration: const InputDecoration(
            labelText: 'Moyen de paiement',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.credit_card),
          ),
          items: settings.paymentMethods
              .map<DropdownMenuItem<String>>((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedPaymentMethod = v);
          },
        ),
        const SizedBox(height: Dimens.spaceXl),

        // Boutons d'action + hint raccourci
        Row(
          children: [
            SizedBox(
              height: Dimens.buttonHeightM,
              child: OutlinedButton.icon(
                onPressed: widget.onTap,
                icon: const Icon(Icons.close, size: Dimens.iconM),
                label: const Text('Annuler'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Dimens.spaceL)),
              ),
            ),
            const SizedBox(width: Dimens.spaceM),
            // Bouton Ignorer / Ré-activer
            SizedBox(
              height: Dimens.buttonHeightM,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.read<ExpensesProvider>().toggleIgnore(expense.id);
                  widget.onTap(); // ferme la carte
                },
                icon: Icon(expense.isIgnored ? Icons.undo : Icons.block, size: Dimens.iconM),
                label: Text(expense.isIgnored ? 'Ré-activer' : 'Ignorer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: expense.isIgnored ? Colors.green : colorScheme.outline,
                  padding: const EdgeInsets.symmetric(horizontal: Dimens.spaceL),
                ),
              ),
            ),
            const SizedBox(width: Dimens.spaceM),
            Expanded(
              child: SizedBox(
                height: Dimens.buttonHeightM,
                child: FilledButton.icon(
                  onPressed: (_selectedCategory == null || expense.isIgnored) ? null : _validate,
                  icon: Icon(isReviewed ? Icons.update : Icons.check, size: Dimens.iconM),
                  label: Text(
                    isReviewed ? 'Mettre à jour' : 'Valider',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_selectedCategory == null)
          Padding(
            padding: const EdgeInsets.only(top: Dimens.spaceS),
            child: Text(
              'Sélectionne une catégorie pour valider.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: Dimens.spaceXs),
          child: Text(
            '⌨ Enter pour valider · Echap pour fermer',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(BuildContext context, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.spaceM, vertical: Dimens.spaceXxs),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Dimens.radiusXl)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}
