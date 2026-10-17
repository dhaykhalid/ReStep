import 'package:flutter/material.dart';

import 'cue_settings.dart';
import 'device.dart';
import 'emergency.dart';
import 'fog_episode.dart';
import 'routine.dart';

class UserData {
  const UserData({
    required this.episodes,
    required this.contacts,
    required this.reminders,
    required this.devices,
    required this.cueSettings,
    required this.escalation,
    required this.reminderPreference,
  });

  factory UserData.empty() {
    return const UserData(
      episodes: [],
      contacts: [],
      reminders: [],
      devices: [],
      cueSettings: CueSettings.defaults,
      escalation: EscalationSettings(
        waitSeconds: 30,
      ),
      reminderPreference: ReminderPreference.both,
    );
  }

  final List<FogEpisode> episodes;
  final List<EmergencyContact> contacts;
  final List<Reminder> reminders;
  final List<ReStepDevice> devices;
  final CueSettings cueSettings;
  final EscalationSettings escalation;
  final ReminderPreference reminderPreference;
}