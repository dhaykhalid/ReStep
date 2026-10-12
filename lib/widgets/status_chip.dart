import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

enum ChipTone { neutral, info, success, warning, danger }

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

  Color get _background {
    switch (tone) {
      case ChipTone.neutral:
        return AppColors.navyTint;
      case ChipTone.info:
        return AppColors.skyTint;
      case ChipTone.success:
        return AppColors.successTint;
      case ChipTone.warning:
        return AppColors.warningTint;
      case ChipTone.danger:
        return AppColors.dangerTint;
    }
  }

  Color get _foreground {
    switch (tone) {
      case ChipTone.neutral:
        return AppColors.navy;
      case ChipTone.info:
        return AppColors.navy;
      case ChipTone.success:
        return AppColors.success;
      case ChipTone.warning:
        return AppColors.warning;
      case ChipTone.danger:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: _foreground),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
