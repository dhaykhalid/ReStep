import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'status_chip.dart';

/// Shows a floating, toned feedback message (toast) at the bottom of the
/// screen. Use it only AFTER an operation has finished:
/// - [ChipTone.success] (green, check) – something was saved / sent.
/// - [ChipTone.danger] (red, error) – an operation failed.
/// - [ChipTone.warning] (amber) – needs attention.
/// - [ChipTone.info] (blue) – neutral notice.
void showAppMessage(
  BuildContext context,
  String message, {
  ChipTone tone = ChipTone.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.of(context).showAppMessage(
    message,
    tone: tone,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

/// Same as [showAppMessage], for code that captured the messenger before an
/// async gap (`final messenger = ScaffoldMessenger.of(context);`).
extension AppFeedbackMessenger on ScaffoldMessengerState {
  void showAppMessage(
    String message, {
    ChipTone tone = ChipTone.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final foreground = tone.foreground;
    final important = tone == ChipTone.danger || tone == ChipTone.warning;
    hideCurrentSnackBar();
    showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tone.background,
        elevation: 3,
        duration: Duration(seconds: important || onAction != null ? 5 : 3),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: AppColors.navy,
                onPressed: onAction,
              ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: foreground.withValues(alpha: 0.25)),
        ),
        content: Row(
          children: [
            Icon(
              tone.icon,
              color: foreground,
              size: 24,
              semanticLabel: tone.semanticLabel,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
