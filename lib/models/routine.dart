import 'package:flutter/material.dart';

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

/// A single upcoming occurrence of a medication or appointment.
class UpcomingReminder {
  const UpcomingReminder({
    required this.key,
    required this.title,
    required this.detail,
    required this.when,
    required this.isMedication,
  });

  /// Unique per occurrence, used so dismissing one occurrence does not repeat it.
  final String key;
  final String title;
  final String detail;
  final DateTime when;
  final bool isMedication;
}
