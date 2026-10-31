import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../models/routine.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';
import 'reminder_form_screen.dart';

/// The "Routine" tab: every saved reminder in one list, each with an
/// enable switch and an Edit / Delete menu.
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
    final reminders = app.sortedReminders;

    return TabPage(
      title: 'Reminders',
      subtitle: 'Manage your reminders and daily activities.',
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
                    const SectionHeader(title: 'Your Reminders', topPadding: 24),
                    for (final reminder in reminders)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReminderTile(
                          key: ValueKey(reminder.id),
                          reminder: reminder,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

enum _ReminderAction { edit, delete }

/// Compact reminder card: icon, title, schedule, enable switch and a menu.
/// A paused reminder is shown muted.
class _ReminderTile extends StatelessWidget {
  const _ReminderTile({super.key, required this.reminder});

  final Reminder reminder;

  Future<void> _setEnabled(BuildContext context, bool enabled) async {
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await app.setReminderEnabled(reminder.id, enabled);
    } catch (_) {
      messenger.showAppMessage(
        'Could not update the reminder. Please try again.',
        tone: ChipTone.danger,
      );
    }
  }

  void _edit(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReminderFormScreen(reminderId: reminder.id),
    ));
  }

  Future<void> _delete(BuildContext context) async {
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete reminder?',
      message: 'Are you sure you want to delete this reminder? '
          'This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;
    try {
      await app.deleteReminder(reminder.id);
    } catch (_) {
      messenger.showAppMessage(
        'Could not delete the reminder. Please try again.',
        tone: ChipTone.danger,
      );
      return;
    }
    messenger.showAppMessage('Reminder deleted', tone: ChipTone.success);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = reminder.isEnabled;
    final repeats = reminder.frequency != ReminderFrequency.once;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 2, 10),
      color: enabled ? Colors.white : AppColors.fieldFill,
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: enabled ? AppColors.skyTint : AppColors.border,
              shape: BoxShape.circle,
            ),
            child: Icon(
              repeats ? Icons.repeat_rounded : Icons.event_outlined,
              color: enabled ? AppColors.navy : AppColors.muted,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: enabled ? AppColors.ink : AppColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled
                      ? reminder.scheduleLabel
                      : '${reminder.scheduleLabel} · Paused',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: enabled ? AppColors.navy : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Semantics(
            label: '${reminder.title} reminder',
            child: Switch(
              value: enabled,
              onChanged: (value) => _setEnabled(context, value),
              thumbColor: const WidgetStatePropertyAll(Colors.white),
              trackColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppColors.navy
                    : AppColors.muted,
              ),
              trackOutlineColor:
                  const WidgetStatePropertyAll(Colors.transparent),
            ),
          ),
          PopupMenuButton<_ReminderAction>(
            tooltip: 'Reminder options',
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.navy),
            onSelected: (action) {
              switch (action) {
                case _ReminderAction.edit:
                  _edit(context);
                case _ReminderAction.delete:
                  _delete(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ReminderAction.edit,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined, color: AppColors.navy),
                  title: Text('Edit reminder'),
                ),
              ),
              PopupMenuItem(
                value: _ReminderAction.delete,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                  ),
                  title: Text(
                    'Delete reminder',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
                  'Tap Add Reminder to schedule anything important to you.',
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
