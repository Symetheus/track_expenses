import 'package:flutter/material.dart';
import '../dimens.dart';

class ProgressHeader extends StatelessWidget {
  final int reviewed;
  final int total;

  const ProgressHeader({super.key, required this.reviewed, required this.total});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = total == 0 ? 0.0 : reviewed / total;
    final isComplete = reviewed == total && total > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.spaceXxl, vertical: Dimens.spaceL),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isComplete ? '✅ Tout est révisé !' : '$reviewed / $total dépenses révisées',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isComplete ? Colors.green.shade700 : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Dimens.spaceS),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Dimens.radiusXs),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: Dimens.progressBarHeight,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(isComplete ? Colors.green : colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Dimens.spaceXl),
          Text(
            '${(progress * 100).toInt()}%',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isComplete ? Colors.green.shade700 : colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
