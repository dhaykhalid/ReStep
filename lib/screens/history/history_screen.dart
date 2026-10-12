import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/episode_analytics.dart';
import '../../core/utils/formatters.dart';
import '../../models/episode_stats.dart';
import '../../models/fog_episode.dart';
import '../../models/period.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../widgets/widgets.dart';

/// FoG History tab: summary statistics, a simple chart, a period filter and
/// two ways to browse episodes (calendar or list), as requested in the
/// questionnaire.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  PeriodOption _period = PeriodOption.last30Days;
  DateRange? _custom;
  bool _calendarView = true;
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = AppScope.read(context).now;
    _selectedDay = Fmt.dayOnly(now);
    _visibleMonth = DateTime(now.year, now.month, 1);
  }

  Future<void> _selectPeriod(PeriodOption option) async {
    if (option != PeriodOption.custom) {
      setState(() => _period = option);
      return;
    }
    final app = AppScope.read(context);
    final today = Fmt.dayOnly(app.now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: _custom == null
          ? null
          : DateTimeRange(start: _custom!.start, end: _custom!.end),
      helpText: 'Choose dates',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _custom = DateRange(picked.start, picked.end);
      _period = PeriodOption.custom;
    });
  }

  DateRange _chartRange(AppState app, List<FogEpisode> all) {
    final selected = app.rangeFor(_period, custom: _custom);
    if (selected != null) return selected;
    final today = Fmt.dayOnly(app.now);
    if (all.isEmpty) return DateRange(Fmt.addDays(today, -6), today);
    var earliest = Fmt.dayOnly(all.first.startTime);
    for (final e in all) {
      final d = Fmt.dayOnly(e.startTime);
      if (d.isBefore(earliest)) earliest = d;
    }
    return DateRange(earliest, today);
  }

  void _openEpisode(FogEpisode episode) {
    Navigator.of(context)
        .pushNamed(Routes.episodeDetail, arguments: episode.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final now = app.now;
    final all = app.episodes;
    final selectedRange = app.rangeFor(_period, custom: _custom);
    final filtered = app.episodesIn(selectedRange);
    final chartRange = _chartRange(app, all);
    final stats = EpisodeStats.from(filtered, days: chartRange.days);

    return TabPage(
      title: 'FoG History',
      subtitle: 'Review your Freezing of Gait episodes.',
      children: [
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Log Episode',
                icon: Icons.add_rounded,
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.manualLog),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SecondaryButton(
                label: 'FoG Report',
                icon: Icons.picture_as_pdf_outlined,
                onPressed: () => Navigator.of(context).pushNamed(Routes.report),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Period filter
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final option in PeriodOption.values)
              FilterPill(
                label: option.shortLabel,
                selected: _period == option,
                icon: option == PeriodOption.custom
                    ? Icons.date_range_rounded
                    : null,
                onTap: () => _selectPeriod(option),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          selectedRange == null
              ? 'Showing all recorded episodes'
              : 'Showing ${selectedRange.label}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),

        // Summary
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatTile(value: '${stats.count}', label: 'Episodes'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                value: stats.count == 0 ? '–' : Fmt.duration(stats.average),
                label: 'Average duration',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                value: stats.count == 0 ? '–' : Fmt.oneDecimal(stats.perWeek),
                label: 'Per week',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (filtered.isNotEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(EpisodeAnalytics.chartUnit(chartRange),
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 16),
                MiniBarChart(
                  data: EpisodeAnalytics.chartData(filtered, chartRange),
                ),
              ],
            ),
          ),

        // Episodes
        SectionHeader(title: 'Episodes', topPadding: 28),
        SegmentedChoice<bool>(
          values: const [true, false],
          labelOf: (v) => v ? 'Calendar' : 'List',
          iconOf: (v) => v ? Icons.calendar_month_rounded : Icons.list_rounded,
          selected: _calendarView,
          onChanged: (v) => setState(() => _calendarView = v),
        ),
        const SizedBox(height: 16),
        if (all.isEmpty)
          AppCard(
            child: EmptyState(
              icon: Icons.event_note_rounded,
              title: 'No episodes yet',
              message: 'Detected episodes will appear here. If ReStep missed '
                  'one, you can add it yourself.',
              actionLabel: 'Log an Episode',
              onAction: () => Navigator.of(context).pushNamed(Routes.manualLog),
            ),
          )
        else if (_calendarView)
          ..._buildCalendar(context, all, now)
        else
          ..._buildList(context, filtered, now),
      ],
    );
  }

  List<Widget> _buildCalendar(
    BuildContext context,
    List<FogEpisode> all,
    DateTime now,
  ) {
    final counts = <DateTime, int>{};
    for (final e in all) {
      final day = Fmt.dayOnly(e.startTime);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    final dayEpisodes =
        all.where((e) => Fmt.sameDay(e.startTime, _selectedDay)).toList();
    final theme = Theme.of(context);

    return [
      AppCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: MonthCalendar(
          visibleMonth: _visibleMonth,
          selectedDay: _selectedDay,
          today: Fmt.dayOnly(now),
          episodeCountByDay: counts,
          onSelectDay: (day) => setState(() => _selectedDay = day),
          onMonthChanged: (month) => setState(() => _visibleMonth = month),
        ),
      ),
      const SizedBox(height: 20),
      Text(Fmt.relativeDay(_selectedDay, now),
          style: theme.textTheme.titleMedium),
      const SizedBox(height: 10),
      if (dayEpisodes.isEmpty)
        AppCard(
          color: AppColors.fieldFill,
          child: Row(
            children: [
              const Icon(Icons.event_available_rounded,
                  color: AppColors.navy, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'No episodes were recorded on this day.',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        )
      else
        for (final e in dayEpisodes)
          EpisodeTile(episode: e, onTap: () => _openEpisode(e)),
    ];
  }

  List<Widget> _buildList(
    BuildContext context,
    List<FogEpisode> episodes,
    DateTime now,
  ) {
    if (episodes.isEmpty) {
      return const [
        AppCard(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No episodes in this period',
            message: 'Try a longer period to see more of your history.',
          ),
        ),
      ];
    }
    final theme = Theme.of(context);
    final widgets = <Widget>[];
    DateTime? lastDay;
    for (final e in episodes) {
      final day = Fmt.dayOnly(e.startTime);
      if (lastDay == null || day != lastDay) {
        widgets.add(Padding(
          padding: EdgeInsets.only(top: lastDay == null ? 0 : 10, bottom: 10),
          child: Text(
            Fmt.relativeDay(day, now),
            style: theme.textTheme.titleSmall?.copyWith(color: AppColors.navy),
          ),
        ));
        lastDay = day;
      }
      widgets.add(EpisodeTile(episode: e, onTap: () => _openEpisode(e)));
    }
    return widgets;
  }
}
