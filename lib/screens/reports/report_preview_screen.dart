import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/fog_episode.dart';
import '../../services/report_service.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Preview of the generated FoG report (summary measures + episode log),
/// with a button to export / share it.
class ReportPreviewScreen extends StatefulWidget {
  const ReportPreviewScreen({super.key, required this.report});

  final ReportResult report;

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  bool _sharing = false;

  Future<void> _share() async {
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sharing = true);
    try {
      await app.shareReport(widget.report);
      messenger.showAppMessage(
        'Report ready: ${widget.report.fileName}',
        tone: ChipTone.success,
      );
    } catch (_) {
      messenger.showAppMessage(
        'Could not share the report. Please try again.',
        tone: ChipTone.danger,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final stats = report.stats;
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Report preview',
      bottom: PrimaryButton(
        label: 'Export / Share PDF',
        icon: Icons.ios_share_rounded,
        loading: _sharing,
        onPressed: _share,
      ),
      children: [
        const InfoBanner(
          tone: ChipTone.neutral,
          message:
              'Prototype note: this previews the report content. '
              'Creating the real PDF file and opening the share sheet will '
              'be connected later.',
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ReStepLogo(size: LogoSize.small),
                  const Spacer(),
                  Text(
                    'FoG Report',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              _InfoLine(label: 'Patient', value: report.patientName),
              _InfoLine(label: 'Period', value: report.periodLabel),
              _InfoLine(
                label: 'Generated',
                value: Fmt.date(report.generatedAt),
              ),
              const SizedBox(height: 20),
              Text('Summary measures', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: StatTile(
                      value: '${stats.count}',
                      label: 'Total episodes',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      value: Fmt.duration(stats.average),
                      label: 'Average duration',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: StatTile(
                      value: Fmt.duration(stats.longest),
                      label: 'Longest episode',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      value: Fmt.oneDecimal(stats.perWeek),
                      label: 'Episodes per week',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Episode log', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final episode in report.episodes) _LogRow(episode: episode),
              const SizedBox(height: 16),
              Text(
                'This report lists recorded information only. It does not '
                'include any diagnosis, interpretation or treatment advice.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.episode});

  final FogEpisode episode;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      Fmt.duration(episode.duration),
      episode.cueDelivered?.label ?? 'No cue',
      episode.source.label,
    ];
    final context0 = episode.context;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${Fmt.date(episode.startTime)} · ${Fmt.time(episode.startTime)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            parts.join(' · '),
            style: const TextStyle(fontSize: 15, color: AppColors.muted),
          ),
          if (context0 != null && context0.activities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Context: ${context0.activities.join(', ')}',
                style: const TextStyle(fontSize: 15, color: AppColors.muted),
              ),
            ),
          if (episode.alertSent)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                episode.alertCancelled
                    ? 'Emergency alert sent, then cancelled'
                    : 'Emergency alert sent',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
