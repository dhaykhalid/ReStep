import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/period.dart';
import '../../models/episode_stats.dart';
import '../../models/fog_episode.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Choose a time period and generate a PDF FoG report to share with a
/// healthcare professional.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  PeriodOption _period = PeriodOption.last30Days;
  DateRange? _custom;
  bool _generating = false;

  static const List<PeriodOption> _options = [
    PeriodOption.last7Days,
    PeriodOption.last30Days,
    PeriodOption.allTime,
    PeriodOption.custom,
  ];

  String? _subtitleFor(PeriodOption option) {
    switch (option) {
      case PeriodOption.last7Days:
        return 'The past week';
      case PeriodOption.last30Days:
        return 'The past month';
      case PeriodOption.allTime:
        return 'Everything ReStep has recorded';
      case PeriodOption.custom:
        return _custom?.label ?? 'Pick a start and an end date';
    }
  }

  Future<void> _select(PeriodOption option) async {
    if (option != PeriodOption.custom) {
      setState(() => _period = option);
      return;
    }
    final today = Fmt.dayOnly(AppScope.read(context).now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: _custom == null
          ? null
          : DateTimeRange(start: _custom!.start, end: _custom!.end),
      helpText: 'Report dates',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _custom = DateRange(picked.start, picked.end);
      _period = PeriodOption.custom;
    });
  }

  Future<void> _generate() async {
    final app = AppScope.read(context);
    final range = app.rangeFor(_period, custom: _custom);
    setState(() => _generating = true);
    final navigator = Navigator.of(context);
    try {
      final report = await app.generateReport(range);
      if (!mounted) return;
      await navigator.pushNamed(Routes.reportPreview, arguments: report);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _export() async {
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final range = app.rangeFor(_period, custom: _custom);
    setState(() => _generating = true);
    try {
      final report = await app.generateReport(range);
      await app.shareReport(report);
    } catch (_) {
      messenger.showAppMessage(
        'Could not share the report. Please try again.',
        tone: ChipTone.danger,
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final range = app.rangeFor(_period, custom: _custom);
    final count = app.episodesIn(range).length;
    final hasEpisodes = count > 0;
    final shownEpisodes = app.episodesIn(range)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    final shownStats = EpisodeStats.from(
      shownEpisodes,
      days: range?.days ?? EpisodeStats.spanDays(shownEpisodes, DateTime.now()),
    );

    return AppScaffold(
      title: 'FoG report',
      bottom: PrimaryButton(
        label: 'Generate PDF Report',
        icon: Icons.download_rounded,
        loading: _generating,
        onPressed: hasEpisodes ? _export : null,
      ),
      children: [
        Text(
          'Create a summary of your FoG episodes that you can share with '
          'your healthcare professional.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
        const SectionHeader(title: 'Report period', topPadding: 24),
        for (final option in _options)
          OptionTile(
            title: option.label,
            subtitle: _subtitleFor(option),
            icon: option == PeriodOption.custom
                ? Icons.date_range_rounded
                : null,
            selected: _period == option,
            onTap: () => _select(option),
          ),
        const SizedBox(height: 8),
        if (hasEpisodes)
          _InlineReport(
            episodes: shownEpisodes,
            stats: shownStats,
            period: range?.label ?? 'All recorded episodes',
          )
        else
          const InfoBanner(
            tone: ChipTone.warning,
            title: 'No episodes in this period',
            message: 'No FoG episodes were recorded in this period, so no '
                'report was created. Choose a different period.',
          ),
        const SizedBox(height: 20),
        Text(
          'The report contains summary measures and an episode log. You '
          'choose whether to share it.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _InlineReport extends StatelessWidget {
  const _InlineReport({
    required this.episodes,
    required this.stats,
    required this.period,
  });

  final List<FogEpisode> episodes;
  final EpisodeStats stats;
  final String period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FoG Report',
            style: theme.textTheme.titleLarge?.copyWith(color: AppColors.navy),
          ),
          const SizedBox(height: 4),
          Text(
            period,
            style: const TextStyle(fontSize: 15, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatTile(value: '${stats.count}', label: 'Episodes'),
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
          for (final e in episodes) _ReportLogRow(episode: e),
        ],
      ),
    );
  }
}

class _ReportLogRow extends StatelessWidget {
  const _ReportLogRow({required this.episode});

  final FogEpisode episode;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      Fmt.duration(episode.duration),
      episode.cueDelivered?.label ?? 'No cue',
      episode.source.label,
    ];
    final ctx = episode.context;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${Fmt.date(episode.startTime)} \u00B7 ${Fmt.time(episode.startTime)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            parts.join(' \u00B7 '),
            style: const TextStyle(fontSize: 15, color: AppColors.muted),
          ),
          if (ctx != null && ctx.activities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Context: ${ctx.activities.join(', ')}',
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
