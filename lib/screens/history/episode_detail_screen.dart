import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/fog_episode.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Details of one episode: time, duration, cue delivered, context and any
/// emergency alert that was sent.
class EpisodeDetailScreen extends StatelessWidget {
  const EpisodeDetailScreen({super.key, required this.episodeId});

  final String episodeId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final episode = app.episodeById(episodeId);
    final theme = Theme.of(context);

    if (episode == null) {
      return const AppScaffold(
        title: 'Episode',
        children: [
          EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Episode not found',
            message: 'This episode is no longer in your history.',
          ),
        ],
      );
    }

    final cue = episode.cueDelivered;
    final ctx = episode.context;

    return AppScaffold(
      title: 'Episode details',
      children: [
        Text(Fmt.dateLong(episode.startTime),
            style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          Fmt.time(episode.startTime),
          style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusChip(
              label: episode.source.label,
              icon: episode.source.icon,
            ),
            if (episode.alertSent)
              StatusChip(
                label: episode.alertCancelled ? 'Alert cancelled' : 'Alert sent',
                tone: ChipTone.warning,
                icon: Icons.sms_outlined,
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatTile(
                value: Fmt.duration(episode.duration),
                label: episode.source == EpisodeSource.manual
                    ? 'Duration (entered by you)'
                    : 'Estimated duration',
                icon: Icons.timer_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                value: cue?.label ?? 'None',
                label: cue == null ? 'No cue recorded' : 'Cue delivered',
                icon: cue?.icon ?? Icons.block_rounded,
              ),
            ),
          ],
        ),
        const SectionHeader(title: 'Patient-Reported Context'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ctx == null || ctx.isEmpty)
                Text(
                  'No context was added for this episode.',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: AppColors.muted),
                )
              else ...[
                if (ctx.activities.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in ctx.activities) StatusChip(label: a),
                    ],
                  ),
                if ((ctx.note ?? '').trim().isNotEmpty) ...[
                  if (ctx.activities.isNotEmpty) const SizedBox(height: 12),
                  Text(ctx.note!, style: theme.textTheme.bodyLarge),
                ],
              ],
              const SizedBox(height: 16),
              SecondaryButton(
                label: episode.hasContext ? 'Edit Context' : 'Add Context',
                icon: Icons.edit_note_rounded,
                onPressed: () => Navigator.of(context).pushNamed(
                    Routes.contextCheckIn,
                    arguments: episode.id),
              ),
            ],
          ),
        ),
        if (episode.alertSent) ...[
          const SectionHeader(title: 'Emergency alert'),
          InfoBanner(
            tone: ChipTone.warning,
            title: episode.alertCancelled
                ? 'Alert sent, then cancelled'
                : 'Alert sent',
            message: 'A message with the episode time was sent to '
                '${episode.alertContactName ?? 'your emergency contact'} at '
                '${Fmt.time(episode.alertSentAt!)}.'
                '${episode.alertCancelled ? ' You confirmed you were safe and a cancellation message was sent.' : ''}',
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'ReStep shows what was recorded. It does not interpret your '
          'episodes or give medical advice.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
