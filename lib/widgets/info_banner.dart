import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'status_chip.dart';

/// Tinted message box for information, warnings and errors.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.tone = ChipTone.info,
    this.icon,
    this.title,
  });

  final String message;
  final String? title;
  final ChipTone tone;
  final IconData? icon;

  Color get _background {
    switch (tone) {
      case ChipTone.success:
        return AppColors.successTint;
      case ChipTone.warning:
        return AppColors.warningTint;
      case ChipTone.danger:
        return AppColors.dangerTint;
      case ChipTone.neutral:
        return AppColors.navyTint;
      case ChipTone.info:
        return AppColors.skyTint;
    }
  }

  Color get _foreground {
    switch (tone) {
      case ChipTone.success:
        return AppColors.success;
      case ChipTone.warning:
        return AppColors.warning;
      case ChipTone.danger:
        return AppColors.danger;
      case ChipTone.neutral:
      case ChipTone.info:
        return AppColors.navy;
    }
  }

  IconData get _defaultIcon {
    switch (tone) {
      case ChipTone.success:
        return Icons.check_circle_outline_rounded;
      case ChipTone.warning:
        return Icons.warning_amber_rounded;
      case ChipTone.danger:
        return Icons.error_outline_rounded;
      case ChipTone.neutral:
      case ChipTone.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? _defaultIcon, color: _foreground, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _foreground,
                      ),
                    ),
                  ),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
