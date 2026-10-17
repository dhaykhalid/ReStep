import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';
import '../home/home_screen.dart' show ReminderCard;
import 'reminder_form_screen.dart';

/// The "Routine" tab: lists upcoming reminders and lets the patient add one.
/// Where reminders are delivered is chosen in Profile > Reminder delivery.
class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key});

  void _addReminder(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ReminderFormScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final now = app.now;
    final reminders = app.upcomingReminders;

    return TabPage(
      title: 'Reminders',
      subtitle: 'Manage your reminders and stay on schedule.',
      children: [
        PrimaryButton(
          label: 'Add Reminder',
          icon: Icons.add_rounded,
          onPressed: () => _addReminder(context),
        ),
        // Cross-fades between the empty state and the list.
        AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.medium),
          switchInCurve: AppMotion.curve,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: reminders.isEmpty
              ? const Padding(
                  key: ValueKey('empty'),
                  padding: EdgeInsets.only(top: 20),
                  child: _EmptyReminders(),
                )
              : Column(
                  key: const ValueKey('list'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(title: 'Next reminder', topPadding: 24),
                    ReminderCard(reminder: reminders.first, now: now),
                    if (reminders.length > 1) ...[
                      SectionHeader(title: 'Later (${reminders.length - 1})'),
                      for (final reminder in reminders.skip(1))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ReminderCard(reminder: reminder, now: now),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// Compact empty state: a subtle icon beside a short, helpful message.
class _EmptyReminders extends StatelessWidget {
  const _EmptyReminders();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
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
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.navy,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No reminders yet', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Tap Add Reminder to plan your next medication or '
                  'appointment.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
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
