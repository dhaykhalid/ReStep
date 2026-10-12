import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/routine.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';
import '../home/home_screen.dart' show ReminderCard;

enum _RoutineTab { medications, appointments }

/// Daily Routine tab: schedule medications and medical appointments and
/// choose where reminders are delivered.
class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  _RoutineTab _tab = _RoutineTab.medications;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final now = app.now;
    final reminders = app.upcomingReminders;
    final onMedications = _tab == _RoutineTab.medications;

    return TabPage(
      title: 'Daily Routine',
      subtitle: 'Your medications and medical appointments.',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active_outlined,
                      color: AppColors.navy, size: 26),
                  const SizedBox(width: 10),
                  Text('Send reminders to',
                      style: theme.textTheme.titleMedium),
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
          ReminderCard(reminder: reminders.first, now: now),
        ],
        const SizedBox(height: 24),
        SegmentedChoice<_RoutineTab>(
          values: _RoutineTab.values,
          labelOf: (t) =>
              t == _RoutineTab.medications ? 'Medications' : 'Appointments',
          selected: _tab,
          onChanged: (t) => setState(() => _tab = t),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: onMedications ? 'Add Medication' : 'Add Appointment',
          icon: Icons.add_rounded,
          onPressed: () => Navigator.of(context).pushNamed(
            onMedications ? Routes.medicationForm : Routes.appointmentForm,
          ),
        ),
        const SizedBox(height: 16),
        if (onMedications) ..._medicationList(context, app.medications),
        if (!onMedications) ..._appointmentList(context, app.appointments, now),
      ],
    );
  }

  List<Widget> _medicationList(BuildContext context, List<Medication> meds) {
    if (meds.isEmpty) {
      return const [
        AppCard(
          child: EmptyState(
            icon: Icons.medication_outlined,
            title: 'No medications yet',
            message: 'Add your medications and the times you take them to '
                'receive reminders.',
          ),
        ),
      ];
    }
    return [
      for (final med in meds)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            onTap: () => Navigator.of(context)
                .pushNamed(Routes.medicationForm, arguments: med.id),
            child: Row(
              children: [
                Container(
                  width: 92,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.skyTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      Fmt.timeOfDay(med.time),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(med.dose,
                          style: const TextStyle(
                              fontSize: 16, color: AppColors.muted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.muted, size: 28),
              ],
            ),
          ),
        ),
      const SizedBox(height: 4),
      const InfoBanner(
        message: 'ReStep saves what you enter. It does not check doses or '
            'interactions.',
      ),
    ];
  }

  List<Widget> _appointmentList(
    BuildContext context,
    List<Appointment> appointments,
    DateTime now,
  ) {
    if (appointments.isEmpty) {
      return const [
        AppCard(
          child: EmptyState(
            icon: Icons.event_outlined,
            title: 'No appointments yet',
            message: 'Add your medical appointments to receive reminders.',
          ),
        ),
      ];
    }
    return [
      for (final appt in appointments)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            onTap: () => Navigator.of(context)
                .pushNamed(Routes.appointmentForm, arguments: appt.id),
            child: Row(
              children: [
                Container(
                  width: 68,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${appt.date.day}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        Fmt.monthName(appt.date.month).substring(0, 3),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.skySoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appt.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Fmt.timeOfDay(appt.time),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(appt.location,
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.muted)),
                      if (appt.dateTime.isBefore(now)) ...[
                        const SizedBox(height: 6),
                        const StatusChip(label: 'Past'),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.muted, size: 28),
              ],
            ),
          ),
        ),
    ];
  }
}
