import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/routine.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';
import '../home/home_screen.dart' show ReminderCard;
import 'reminder_form_screen.dart';

class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final now = app.now;
    final reminders = app.upcomingReminders;

    return TabPage(
      title: 'Reminders',
      subtitle: 'Manage your reminders and stay on schedule.',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.navy,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Send reminders to',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SegmentedChoice<ReminderPreference>(
                values: ReminderPreference.values,
                labelOf: (p) => p.label,
                selected: app.reminderPreference,
                onChanged: app.setReminderPreference,
              ),
            ],
          ),
        ),
        if (reminders.isNotEmpty) ...[
          const SectionHeader(title: 'Next reminder'),
          ReminderCard(
            reminder: reminders.first,
            now: now,
          ),
        ],
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Add Reminder',
          icon: Icons.add_rounded,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReminderFormScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        if (reminders.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No reminders yet',
              message:
              'Add your reminders to receive notifications and stay on schedule.',
            ),
          )
        else
          ..._reminderList(reminders, now),
      ],
    );
  }

  List<Widget> _reminderList(
      List<UpcomingReminder> reminders,
      DateTime now,
      ) {
    return [
      for (final reminder in reminders)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ReminderCard(
            reminder: reminder,
            now: now,
          ),
        ),
    ];
  }
}