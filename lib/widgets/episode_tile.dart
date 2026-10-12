import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/fog_episode.dart';
import 'app_card.dart';
import 'status_chip.dart';

/// One row in the FoG history: time, duration, cue delivered and tags.
class EpisodeTile extends StatelessWidget {
  const EpisodeTile({
    super.key,
    required this.episode,
    required this.onTap,
    this.showDate = false,
  });

  final FogEpisode episode;
  final VoidCallback onTap;

  /// Show the date next to the time (used outside the day-grouped list).
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final timeText = showDate
        ? '${Fmt.dayMonth(episode.startTime)} · ${Fmt.time(episode.startTime)}'
        : Fmt.time(episode.startTime);
    final cue = episode.cueDelivered;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: const BoxDecoration(
                color: AppColors.skyTint,
                shape: BoxShape.circle,
              ),
              child: Icon(episode.source.icon, color: AppColors.navy, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Duration: ${Fmt.duration(episode.duration)}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (cue != null)
                        StatusChip(
                            label: cue.label,
                            tone: ChipTone.info,
                            icon: cue.icon)
                      else
                        const StatusChip(label: 'No cue recorded'),
                      StatusChip(label: episode.source.label),
                      if (episode.hasContext)
                        const StatusChip(
                          label: 'Context added',
                          tone: ChipTone.success,
                          icon: Icons.notes_rounded,
                        ),
                      if (episode.alertSent)
                        StatusChip(
                          label: episode.alertCancelled
                              ? 'Alert cancelled'
                              : 'Alert sent',
                          tone: ChipTone.warning,
                          icon: Icons.sms_outlined,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Icon(Icons.chevron_right_rounded,
                  color: AppColors.muted, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}
