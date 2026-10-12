import 'cue_settings.dart';
import 'device.dart';
import 'emergency.dart';
import 'fog_episode.dart';
import 'routine.dart';

/// Everything that is loaded for a signed-in patient.
/// A real backend (Firebase) would fill this from the database.
class UserData {
  const UserData({
    required this.episodes,
    required this.medications,
    required this.appointments,
    required this.contacts,
    required this.devices,
    required this.cueSettings,
    required this.escalation,
    required this.reminderPreference,
  });

  /// A brand-new account: no records yet (shows the empty states).
  factory UserData.empty() {
    return const UserData(
      episodes: [],
      medications: [],
      appointments: [],
      contacts: [],
      devices: [],
      cueSettings: CueSettings.defaults,
      escalation: EscalationSettings(waitSeconds: 30),
      reminderPreference: ReminderPreference.both,
    );
  }

  final List<FogEpisode> episodes;
  final List<Medication> medications;
  final List<Appointment> appointments;
  final List<EmergencyContact> contacts;
  final List<ReStepDevice> devices;
  final CueSettings cueSettings;
  final EscalationSettings escalation;
  final ReminderPreference reminderPreference;
}
