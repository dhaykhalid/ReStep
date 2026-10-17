import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'status_chip.dart';

/// Tinted inline message box. Uses the shared tone palette: info (blue),
/// success (green), warning (amber) and danger (red).
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

  @override
  Widget build(BuildContext context) {
    final foreground = tone.foreground;
    return Semantics(
      container: true,
      liveRegion: tone == ChipTone.danger,
      label: tone.semanticLabel,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: foreground.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? tone.icon, color: foreground, size: 24),
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
                          color: foreground,
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
      ),
    );
  }
}
