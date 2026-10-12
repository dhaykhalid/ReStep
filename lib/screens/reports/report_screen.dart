import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/period.dart';
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

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final range = app.rangeFor(_period, custom: _custom);
    final count = app.episodesIn(range).length;
    final hasEpisodes = count > 0;

    return AppScaffold(
      title: 'FoG report',
      bottom: PrimaryButton(
        label: 'Generate PDF Report',
        icon: Icons.picture_as_pdf_outlined,
        loading: _generating,
        onPressed: hasEpisodes ? _generate : null,
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
          AppCard(
            color: AppColors.skyTint,
            borderColor: AppColors.skySoft,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.description_outlined,
                    color: AppColors.navy, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    count == 1
                        ? 'This report will include 1 episode.'
                        : 'This report will include $count episodes.',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
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
