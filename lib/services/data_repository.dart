import '../data/mock/mock_data.dart';
import '../models/cue_settings.dart';
import '../models/emergency.dart';
import '../models/fog_episode.dart';
import '../models/patient.dart';
import '../models/routine.dart';
import '../models/user_data.dart';

/// Storage for the patient's records.
/// TODO(backend): implement with Firebase (patients, episodes, routine entries).
/// Continuous raw IMU data must NOT be stored permanently by default.
abstract class DataRepository {
  Future<UserData> loadUserData(
    Patient patient, {
    required bool isNewAccount,
    required DateTime now,
  });

  Future<void> saveEpisode(FogEpisode episode);
  Future<void> saveMedication(Medication medication);
  Future<void> deleteMedication(String id);
  Future<void> saveAppointment(Appointment appointment);
  Future<void> deleteAppointment(String id);
  Future<void> saveContact(EmergencyContact contact);
  Future<void> deleteContact(String id);
  Future<void> saveCueSettings(CueSettings settings);
  Future<void> saveEscalationSettings(EscalationSettings settings);
  Future<void> saveReminderPreference(ReminderPreference preference);
}

/// Prototype repository: serves sample data and ignores saves
/// (AppState keeps the live in-memory copy while the app is running).
class MockDataRepository implements DataRepository {
  @override
  Future<UserData> loadUserData(
    Patient patient, {
    required bool isNewAccount,
    required DateTime now,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (isNewAccount) return UserData.empty();
    return MockData.userData(now);
  }

  @override
  Future<void> saveEpisode(FogEpisode episode) async {}

  @override
  Future<void> saveMedication(Medication medication) async {}

  @override
  Future<void> deleteMedication(String id) async {}

  @override
  Future<void> saveAppointment(Appointment appointment) async {}

  @override
  Future<void> deleteAppointment(String id) async {}

  @override
  Future<void> saveContact(EmergencyContact contact) async {}

  @override
  Future<void> deleteContact(String id) async {}

  @override
  Future<void> saveCueSettings(CueSettings settings) async {}

  @override
  Future<void> saveEscalationSettings(EscalationSettings settings) async {}

  @override
  Future<void> saveReminderPreference(ReminderPreference preference) async {}
}
