import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';

class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.time,
  });

  final String id;
  final String name;
  final String dose;
  final TimeOfDay time;
}

class Appointment {
  const Appointment({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
  });

  final String id;
  final String title;
  final DateTime date;
  final TimeOfDay time;
  final String location;

  DateTime get dateTime =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Where reminders are delivered (from the questionnaire).
enum ReminderPreference { phone, watch, both }

extension ReminderPreferenceX on ReminderPreference {
  String get label {
    switch (this) {
      case ReminderPreference.phone:
        return 'Phone';
      case ReminderPreference.watch:
        return 'Smartwatch';
      case ReminderPreference.both:
        return 'Both';
    }
  }
}

/// A single upcoming occurrence of a reminder.
class UpcomingReminder {
  const UpcomingReminder({
    required this.key,
    required this.title,
    required this.detail,
    required this.when,
    required this.isMedication,
    this.reminderId,
    this.schedule,
  });

  /// Unique per occurrence, used so dismissing one occurrence does not repeat it.
  final String key;
  final String title;
  final String detail;
  final DateTime when;
  final bool isMedication;

  /// The [Reminder] this occurrence comes from, used to open it for editing.
  final String? reminderId;

  /// How the reminder repeats, see [Reminder.scheduleLabel].
  final String? schedule;
}
/// How often a reminder repeats. Stored in Firestore as "Once", "Daily" or
/// "Weekly".
enum ReminderFrequency { once, daily, weekly }

extension ReminderFrequencyX on ReminderFrequency {
  String get firestoreValue {
    switch (this) {
      case ReminderFrequency.once:
        return 'Once';
      case ReminderFrequency.daily:
        return 'Daily';
      case ReminderFrequency.weekly:
        return 'Weekly';
    }
  }

  String get label {
    switch (this) {
      case ReminderFrequency.once:
        return 'Does not repeat';
      case ReminderFrequency.daily:
        return 'Every day';
      case ReminderFrequency.weekly:
        return 'Weekly (select days)';
    }
  }

  /// Missing or unknown values are treated as a one-time reminder.
  static ReminderFrequency fromFirestore(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'daily':
        return ReminderFrequency.daily;
      case 'weekly':
        return ReminderFrequency.weekly;
      default:
        return ReminderFrequency.once;
    }
  }
}

/// Weekday names as stored in `repeat_days`, in display order.
class ReminderDays {
  ReminderDays._();

  static const List<String> all = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  /// The stored name for a [DateTime.weekday] (1 = Monday ... 7 = Sunday).
  static String ofWeekday(int weekday) => all[weekday % 7];

  /// Known day names from [values] in Sun...Sat order, without duplicates.
  /// Matching ignores case and accepts full names such as "Monday".
  static List<String> normalize(Iterable<Object?> values) {
    final wanted = {
      for (final v in values.whereType<String>())
        if (v.trim().length >= 3) v.trim().substring(0, 3).toLowerCase(),
    };
    return [
      for (final day in all)
        if (wanted.contains(day.toLowerCase())) day,
    ];
  }
}

class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.frequency,
    required this.date,
    required this.time,
    required this.location,
    this.repeatDays = const [],
    this.isEnabled = true,
  });

  final String id;
  final String title;
  final ReminderFrequency frequency;

  /// False while the reminder is paused (Firestore `is_enabled`).
  final bool isEnabled;

  Reminder copyWith({bool? isEnabled}) => Reminder(
        id: id,
        title: title,
        frequency: frequency,
        date: date,
        time: time,
        location: location,
        repeatDays: repeatDays,
        isEnabled: isEnabled ?? this.isEnabled,
      );

  /// The day of a one-time reminder; null for daily and weekly reminders.
  final DateTime? date;

  /// Days of a weekly reminder (see [ReminderDays]); empty otherwise.
  final List<String> repeatDays;
  final TimeOfDay time;
  final String location;

  /// "24 Oct 2026 · 10:00 AM", "Every day · 10:00 AM" or
  /// "Every Sun, Tue, Thu · 10:00 AM".
  String get scheduleLabel {
    final at = Fmt.timeOfDay(time);
    switch (frequency) {
      case ReminderFrequency.once:
        final day = date;
        return day == null ? at : '${Fmt.date(day)} · $at';
      case ReminderFrequency.daily:
        return 'Every day · $at';
      case ReminderFrequency.weekly:
        return repeatDays.isEmpty
            ? 'Weekly · $at'
            : 'Every ${repeatDays.join(', ')} · $at';
    }
  }

  /// The first time this reminder is due at or after [from]; for a one-time
  /// reminder, its own date and time even if that has passed. Null when it
  /// can never occur (a weekly reminder with no days).
  DateTime? nextOccurrence(DateTime from) {
    DateTime at(DateTime day) =>
        DateTime(day.year, day.month, day.day, time.hour, time.minute);

    switch (frequency) {
      case ReminderFrequency.once:
        final day = date;
        return day == null ? null : at(day);
      case ReminderFrequency.daily:
      case ReminderFrequency.weekly:
        for (var i = 0; i <= 7; i++) {
          final candidate = at(DateTime(from.year, from.month, from.day + i));
          if (candidate.isBefore(from)) continue;
          if (frequency == ReminderFrequency.daily ||
              repeatDays.contains(ReminderDays.ofWeekday(candidate.weekday))) {
            return candidate;
          }
        }
        return null;
    }
  }
}