import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/episode_analytics.dart';
import '../../core/utils/formatters.dart';
import '../../models/device.dart';
import '../../models/episode_stats.dart';
import '../../models/fog_episode.dart';
import '../../models/period.dart';
import '../../models/routine.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../widgets/widgets.dart';

/// Home / dashboard: device status, Quick Assistance, a short summary,
/// the next reminder and the most recent episodes.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _startQuickAssistance(BuildContext context) {
    final app = AppScope.read(context);
    final watch = app.watch;
    if (watch == null || !watch.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Your smartwatch is not connected.'),
          action: SnackBarAction(
            label: 'Pair',
            textColor: AppColors.sky,
            onPressed: () => Navigator.of(context).pushNamed(Routes.devices),
          ),
        ),
      );
      return;
    }
    app.startCue(EpisodeSource.quickAssistance);
    Navigator.of(context).pushNamed(Routes.activeCue);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final patient = app.patient;
    final now = app.now;

    final week = app.rangeFor(PeriodOption.last7Days)!;
    final weekEpisodes = app.episodesIn(week);
    final stats = EpisodeStats.from(weekEpisodes, days: week.days);
    final reminders = app.upcomingReminders;
    final recent = app.episodes.take(3).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          // Header: logo + avatar
          Row(
            children: [
              const ReStepLogo(size: LogoSize.small),
              const Spacer(),
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => app.goToTab(3),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: UserAvatar(
                      initials: patient?.initials ?? '?', size: 48),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('${_greeting(now)},',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: AppColors.muted)),
          Text(patient?.firstName ?? '',
              style: theme.textTheme.headlineMedium),
          const SizedBox(height: 20),

          // Sensor / watch status
          _DevicesCard(app: app),
          const SizedBox(height: 16),

          // Quick Assistance
          _QuickAssistanceCard(
            app: app,
            onStart: () => _startQuickAssistance(context),
          ),

          // Summary
          SectionHeader(
            title: 'Last 7 days',
            actionLabel: 'View history',
            onAction: () => app.goToTab(1),
          ),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${stats.count}',
                  label: 'Episodes',
                  icon: Icons.bolt_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  value: stats.count == 0 ? '–' : Fmt.duration(stats.average),
                  label: 'Average duration',
                  icon: Icons.timer_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(EpisodeAnalytics.chartUnit(week),
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 16),
                MiniBarChart(
                  data: EpisodeAnalytics.chartData(weekEpisodes, week),
                ),
              ],
            ),
          ),

          // Reminder
          const SectionHeader(title: 'Next reminder'),
          if (reminders.isEmpty)
            AppCard(
              onTap: () => app.goToTab(2),
              child: Row(
                children: [
                  const Icon(Icons.notifications_none_rounded,
                      color: AppColors.navy, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'No upcoming reminders. Add medications and '
                      'appointments in Routine.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            )
          else
            ReminderCard(reminder: reminders.first, now: now),

          // Recent episodes
          SectionHeader(
            title: 'Recent episodes',
            actionLabel: recent.isEmpty ? null : 'See all',
            onAction: () => app.goToTab(1),
          ),
          if (recent.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.event_available_rounded,
                title: 'No episodes yet',
                message:
                    'When ReStep detects a FoG episode, it will appear here.',
              ),
            )
          else
            for (final episode in recent)
              EpisodeTile(
                episode: episode,
                showDate: true,
                onTap: () => Navigator.of(context)
                    .pushNamed(Routes.episodeDetail, arguments: episode.id),
              ),
        ],
      ),
    );
  }
}

/// A medication / appointment reminder with a Dismiss button.
class ReminderCard extends StatelessWidget {
  const ReminderCard({super.key, required this.reminder, required this.now});

  final UpcomingReminder reminder;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.read(context);
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: const BoxDecoration(
                  color: AppColors.skyTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  reminder.isMedication
                      ? Icons.medication_outlined
                      : Icons.event_outlined,
                  color: AppColors.navy,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reminder.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${Fmt.relativeDay(reminder.when, now)} · '
                      '${Fmt.time(reminder.when)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(reminder.detail,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => app.dismissReminder(reminder.key),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Dismiss'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (app.pairedDevices.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.bluetooth_searching_rounded,
          title: 'Pair your devices',
          message: 'Connect your Shimmer3 IMU sensor and smartwatch so '
              'ReStep can monitor and assist you.',
          actionLabel: 'Pair Devices',
          onAction: () => Navigator.of(context).pushNamed(Routes.devices),
        ),
      );
    }

    final monitoring = app.isMonitoring;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Your devices', style: theme.textTheme.titleMedium),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.devices),
                child: const Text('Manage'),
              ),
            ],
          ),
          StatusChip(
            label: monitoring
                ? 'Monitoring is active'
                : 'Monitoring paused: sensor not connected',
            tone: monitoring ? ChipTone.success : ChipTone.warning,
            icon: monitoring
                ? Icons.check_circle_outline_rounded
                : Icons.pause_circle_outline_rounded,
          ),
          const SizedBox(height: 14),
          for (final device in app.pairedDevices) ...[
            _DeviceRow(device: device),
            const SizedBox(height: 12),
          ],
          if (app.sensor != null && !app.sensor!.connected)
            InfoBanner(
              tone: ChipTone.warning,
              title: 'Sensor disconnected',
              message: 'ReStep is trying to reconnect automatically. '
                  'Make sure the sensor is turned on and close to your phone.',
            ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device});

  final ReStepDevice device;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: const BoxDecoration(
            color: AppColors.skyTint,
            shape: BoxShape.circle,
          ),
          child: Icon(device.kind.icon, color: AppColors.navy, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              Text(
                device.kind.label,
                style:
                    const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusChip(
                    label: device.connected ? 'Connected' : 'Disconnected',
                    tone:
                        device.connected ? ChipTone.success : ChipTone.warning,
                  ),
                  if (device.connected && device.batteryPercent != null)
                    BatteryIndicator(percent: device.batteryPercent!),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAssistanceCard extends StatelessWidget {
  const _QuickAssistanceCard({required this.app, required this.onStart});

  final AppState app;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final cue = app.cueSettings;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: const BoxDecoration(
                  color: AppColors.onNavyOverlay,
                  shape: BoxShape.circle,
                ),
                child: Icon(cue.type.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Quick Assistance',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Need help to start walking? Start your ${cue.type.label.toLowerCase()} '
            'cue yourself.',
            style: const TextStyle(
                fontSize: 16, height: 1.4, color: Colors.white),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.navy,
                minimumSize: const Size(64, 60),
              ),
              child: const Text('Start My Cue'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cue: ${cue.type.label} · ${cue.durationSeconds} s',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.skySoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.cueSettings),
                style: TextButton.styleFrom(foregroundColor: AppColors.sky),
                child: const Text('Change'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
