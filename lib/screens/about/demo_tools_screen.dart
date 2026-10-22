import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/fog_episode.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';
import 'sensor_data_screen.dart';

/// Prototype-only tools. In the finished product these events come from the
/// Shimmer3 IMU, the FoG detection model and the smartwatch, so the app can be
/// demonstrated without the hardware.
class DemoToolsScreen extends StatelessWidget {
  const DemoToolsScreen({super.key});

  void _simulateEpisode(BuildContext context) {
    final app = AppScope.read(context);
    app.startCue(EpisodeSource.detected);
    Navigator.of(context).pushNamed(Routes.activeCue);
  }

  void _simulateUnresolved(BuildContext context) {
    Navigator.of(context).pushNamed(Routes.escalationPrompt);
  }

  void _simulateDisconnect(BuildContext context) {
    final app = AppScope.read(context);
    final sensor = app.sensor;
    if (sensor == null || !sensor.connected) {
      showAppMessage(context, 'No connected sensor to disconnect.');
      return;
    }
    app.simulateSensorDisconnect();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    app.goToTab(0);
    messenger.showAppMessage(
      'Sensor disconnected. ReStep is reconnecting…',
      tone: ChipTone.warning,
    );
  }

  Future<void> _simulateReminder(BuildContext context) async {
    final app = AppScope.read(context);
    final reminders = app.upcomingReminders;
    if (reminders.isEmpty) {
      showAppMessage(context, 'There are no upcoming reminders.');
      return;
    }
    final reminder = reminders.first;
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 64,
                width: 64,
                decoration: const BoxDecoration(
                  color: AppColors.skyTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.navy,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reminder',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${reminder.title}\n${Fmt.time(reminder.when)} · '
                '${reminder.detail}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.45,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Dismiss',
                onPressed: () {
                  app.dismissReminder(reminder.key);
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Prototype demo tools',
      children: [
        const InfoBanner(
          tone: ChipTone.neutral,
          icon: Icons.science_outlined,
          message:
              'These buttons stand in for the Shimmer3 IMU, the FoG '
              'detection model and the smartwatch, so you can see how ReStep '
              'responds. They are not part of the finished product.',
        ),
        const SizedBox(height: 20),
        _DemoAction(
          icon: Icons.show_chart_rounded,
          title: 'Live sensor data',
          description:
              'See live Shimmer3 readings and export a recording '
              'as CSV (development tool).',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SensorDataScreen()),
          ),
        ),
        _DemoAction(
          icon: Icons.sensors,
          title: 'Simulate a detected FoG episode',
          description:
              'Starts your cue automatically, then offers the '
              'optional context check-in.',
          onTap: () => _simulateEpisode(context),
        ),
        _DemoAction(
          icon: Icons.help_outline_rounded,
          title: 'Simulate an episode that does not resolve',
          description:
              'Shows the "Are you alright?" prompt and the '
              'emergency escalation.',
          onTap: () => _simulateUnresolved(context),
        ),
        _DemoAction(
          icon: Icons.bluetooth_disabled_rounded,
          title: 'Simulate the sensor disconnecting',
          description:
              'Shows the warning on Home. ReStep reconnects '
              'automatically after a few seconds.',
          onTap: () => _simulateDisconnect(context),
        ),
        _DemoAction(
          icon: Icons.notifications_active_outlined,
          title: 'Simulate a reminder notification',
          description:
              'Shows how a reminder appears.',
          onTap: () => _simulateReminder(context),
        ),
      ],
    );
  }
}

class _DemoAction extends StatelessWidget {
  const _DemoAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: const BoxDecoration(
                color: AppColors.skyTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.navy, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.play_circle_outline_rounded,
              color: AppColors.navy,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }
}
