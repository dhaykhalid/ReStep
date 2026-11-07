import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/routine.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';
import 'reminder_form_screen.dart';

enum _ReminderAction { edit, delete }

/// Compact reminder card: icon, title, schedule, enable switch and a menu.
/// A paused reminder is shown muted. Used by the Reminders tab and by Home's
/// "Next reminder".
class ReminderTile extends StatelessWidget {
  const ReminderTile({
    super.key,
    required this.reminder,
    this.showLocation = false,
  });

  final Reminder reminder;

  /// Adds the reminder's location, if it has one, under the schedule.
  final bool showLocation;

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
    final location = showLocation ? reminder.location.trim() : '';

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
                if (location.isNotEmpty)
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
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
