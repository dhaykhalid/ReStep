import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'app_buttons.dart';

/// Friendly message shown when a list has nothing to display.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 76,
            width: 76,
            decoration: const BoxDecoration(
              color: AppColors.skyTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppColors.navy),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.muted)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            PrimaryButton(
                label: actionLabel!, onPressed: onAction, expand: false),
          ],
        ],
      ),
    );
  }
}
