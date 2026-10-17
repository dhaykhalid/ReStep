import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import 'app_buttons.dart';

/// Shows a confirmation dialog and returns true only if the patient confirms.
/// Used for Sign Out, Delete Account and other irreversible actions.
///
/// Ordinary confirmations use the primary blue; [destructive] ones use red
/// for the icon and the confirm button so they never look harmless.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: cancelLabel,
    barrierColor: AppColors.scrim,
    transitionDuration: AppMotion.of(context, AppMotion.medium),
    // iOS alert style: fade in while settling from slightly larger.
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.curve);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.06, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (dialogContext, _, _) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      icon: icon,
    ),
  );
  return result ?? false;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? AppColors.danger : AppColors.navy;
    final navigator = Navigator.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  height: 60,
                  width: 60,
                  decoration: BoxDecoration(
                    color: destructive
                        ? AppColors.dangerTint
                        : AppColors.skyTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 30),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.45,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              // Stacked buttons stay readable with large system fonts.
              if (destructive)
                DestructiveButton(
                  label: confirmLabel,
                  onPressed: () => navigator.pop(true),
                )
              else
                PrimaryButton(
                  label: confirmLabel,
                  onPressed: () => navigator.pop(true),
                ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: cancelLabel,
                onPressed: () => navigator.pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
