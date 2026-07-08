import 'package:flutter/material.dart';
import '../dimens.dart';

/// Sélecteur de catégorie sous forme de chips cliquables.
class CategorySelector extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final String? suggested;
  final void Function(String category) onSelected;
  final VoidCallback onAddCategory;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
    required this.onAddCategory,
    this.suggested,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: Dimens.spaceM,
      runSpacing: Dimens.spaceS,
      children: [
        ...categories.map((cat) {
          final isSelected = selected == cat;
          // ✨ : c'est la suggestion si la catégorie selectionnée est la suggestion
          // (pre-remplie par le parser) OU si rien n'est encore sélectionné
          final isSuggested = suggested == cat && (selected == null || selected == suggested);
          return FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cat),
                if (isSuggested) ...[
                  const SizedBox(width: Dimens.spaceXs),
                  Icon(Icons.auto_awesome, size: Dimens.iconXs, color: colorScheme.primary),
                ],
              ],
            ),
            selected: isSelected,
            showCheckmark: isSelected,
            onSelected: (_) => onSelected(cat),
            backgroundColor: isSuggested && !isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                : null,
            selectedColor: colorScheme.primaryContainer,
            labelStyle: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? colorScheme.onPrimaryContainer : null,
            ),
          );
        }),
        ActionChip(
          avatar: const Icon(Icons.add, size: Dimens.iconS),
          label: const Text('Nouvelle'),
          onPressed: onAddCategory,
          backgroundColor: colorScheme.surfaceContainerHighest,
        ),
      ],
    );
  }
}
