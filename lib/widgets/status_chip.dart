import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Shared tone palette for chips, banners and feedback messages:
/// success = green, danger = red, warning = amber, info / neutral = blue.
enum ChipTone { neutral, info, success, warning, danger }

extension ChipToneStyle on ChipTone {
  Color get background {
    switch (this) {
      case ChipTone.neutral:
        return AppColors.navyTint;
      case ChipTone.info:
        return AppColors.infoTint;
      case ChipTone.success:
        return AppColors.successTint;
      case ChipTone.warning:
        return AppColors.warningTint;
      case ChipTone.danger:
        return AppColors.dangerTint;
    }
  }

  Color get foreground {
    switch (this) {
      case ChipTone.neutral:
      case ChipTone.info:
        return AppColors.info;
      case ChipTone.success:
        return AppColors.success;
      case ChipTone.warning:
        return AppColors.warning;
      case ChipTone.danger:
        return AppColors.danger;
    }
  }

  /// Distinct icon per tone so meaning never depends on color alone.
  IconData get icon {
    switch (this) {
      case ChipTone.success:
        return Icons.check_circle_rounded;
      case ChipTone.warning:
        return Icons.warning_amber_rounded;
      case ChipTone.danger:
        return Icons.error_rounded;
      case ChipTone.neutral:
      case ChipTone.info:
        return Icons.info_rounded;
    }
  }

  /// Spoken by screen readers before the message.
  String get semanticLabel {
    switch (this) {
      case ChipTone.success:
        return 'Success';
      case ChipTone.warning:
        return 'Warning';
      case ChipTone.danger:
        return 'Error';
      case ChipTone.neutral:
      case ChipTone.info:
        return 'Information';
    }
  }
}

/// Small rounded label (status, cue type, source...).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = ChipTone.neutral,
    this.icon,
  });

  final String label;
  final ChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = tone.foreground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
