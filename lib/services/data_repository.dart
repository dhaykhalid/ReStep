
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/mock/mock_data.dart';
import '../models/cue_settings.dart';
import '../models/device.dart';
import '../models/emergency.dart';
import '../models/fog_episode.dart';
import '../models/patient.dart';
import '../models/routine.dart';
import '../models/user_data.dart';

/// Storage for the patient's records.
///
/// Firebase is used for persistent patient data.
/// Continuous raw IMU data must NOT be stored permanently by default.
abstract class DataRepository {
  Future<UserData> loadUserData(
      Patient patient, {
        required bool isNewAccount,
        required DateTime now,
      });

  Future<void> saveEpisode(FogEpisode episode);

  Future<void> saveContact(EmergencyContact contact);

  Future<void> deleteContact(String id);

  Future<void> saveReminder(Reminder reminder);

  Future<void> deleteReminder(String id);

  Future<void> saveCueSettings(CueSettings settings);

  Future<void> saveEscalationSettings(
      EscalationSettings settings,
      );

  Future<void> saveReminderPreference(
      ReminderPreference preference,
      );

  Future<void> saveEmergencyContactsEnabled(bool enabled);


  /// Saves a sensor the patient has connected, so it appears under
  /// "My devices" next time.
  Future<void> saveDevice(ReStepDevice device);

  /// Removes a saved sensor ("Remove device").
  Future<void> deleteDevice(String id);
}

/// Prototype repository.
class MockDataRepository implements DataRepository {
  @override
  Future<UserData> loadUserData(
      Patient patient, {
        required bool isNewAccount,
        required DateTime now,
      }) async {
    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );

    if (isNewAccount) {
      return UserData.empty();
    }

    return MockData.userData(now);
  }

  @override
  Future<void> saveEpisode(FogEpisode episode) async {}

  @override
  Future<void> saveContact(EmergencyContact contact) async {}

  @override
  Future<void> deleteContact(String id) async {}

  @override
  Future<void> saveReminder(Reminder reminder) async {}

  @override
  Future<void> deleteReminder(String id) async {}

  @override
  Future<void> saveCueSettings(CueSettings settings) async {}

  @override
  Future<void> saveEscalationSettings(
      EscalationSettings settings,
      ) async {}

  @override
  Future<void> saveReminderPreference(
      ReminderPreference preference,
      ) async {}

  @override
  Future<void> saveEmergencyContactsEnabled(bool enabled) async {}

  @override
  Future<void> saveDevice(ReStepDevice device) async {}

  @override
  Future<void> deleteDevice(String id) async {}
}

/// Firebase repository.
///
/// Patient:
/// patients/{patientEmail}
///
/// Emergency contacts:
/// patients/{patientEmail}/emergency_contacts/{contactId}
///
/// Reminders:
/// patients/{patientEmail}/reminders/{reminderId}
///
/// FoG episodes:
/// patients/{patientEmail}/fog_episodes/{episodeId}
///
/// Devices:
/// patients/{patientEmail}/devices/{deviceId}
///
/// Settings:
/// patients/{patientEmail}/settings/preferences
class FirebaseDataRepository implements DataRepository {
  FirebaseDataRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _patientEmail {
    final email = _auth.currentUser?.email;

    if (email == null) {
      throw StateError('No signed-in patient.');
    }

    return email.trim().toLowerCase();
  }

  DocumentReference<Map<String, dynamic>> get _patientDoc {
    return _firestore
        .collection('patients')
        .doc(_patientEmail);
  }

  CollectionReference<Map<String, dynamic>> get _emergencyContacts {
    return _patientDoc.collection('emergency_contacts');
  }

  CollectionReference<Map<String, dynamic>> get _reminders {
    return _patientDoc.collection('reminders');
  }

  CollectionReference<Map<String, dynamic>> get _episodes {
    return _patientDoc.collection('fog_episodes');
  }

  CollectionReference<Map<String, dynamic>> get _devices {
    return _patientDoc.collection('devices');
  }

  DocumentReference<Map<String, dynamic>> get _preferences {
    return _patientDoc.collection('settings').doc('preferences');
  }

  // ------------------------------------------------------------
  // LOAD ALL PATIENT DATA
  // ------------------------------------------------------------

  @override
  Future<UserData> loadUserData(
      Patient patient, {
        required bool isNewAccount,
        required DateTime now,
      }) async {
    if (isNewAccount) {
      return UserData.empty();
    }

    // ----------------------------------------------------------
    // Emergency contacts
    // ----------------------------------------------------------

    final contactsSnapshot = await _emergencyContacts.get();

    final contacts = contactsSnapshot.docs.map((doc) {
      final data = doc.data();

      return EmergencyContact(
        id: doc.id,
        name: data['name'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        isDesignated: data['is_designated'] as bool? ?? false,
      );
    }).toList();


    // ----------------------------------------------------------
    // Reminders
    // ----------------------------------------------------------

    final remindersSnapshot = await _reminders.get();

    final reminders = remindersSnapshot.docs.map((doc) {
      final data = doc.data();

      final timestamp = data['date'] as Timestamp?;

      final reminderDate = timestamp?.toDate() ??
          DateTime(
            now.year,
            now.month,
            now.day,
          );

      return Reminder(
        id: doc.id,
        title: data['title'] as String? ??
            data['titel'] as String? ??
            '',
        context: data['context'] as String? ?? '',
        date: reminderDate,
        time: _parseTime(data['time'] as String?),
        location: data['location'] as String? ?? '',
        frequency: data['frequency'] as String? ?? 'Once',
      );
    }).toList();

    // ----------------------------------------------------------
    // FoG episodes
    // ----------------------------------------------------------

    final episodesSnapshot = await _episodes
        .orderBy('start_time', descending: true)
        .get();

    final episodes = episodesSnapshot.docs.map((doc) {
      return _episodeFromFirestore(
        doc.id,
        doc.data(),
      );
    }).toList();

    // ----------------------------------------------------------
    // Devices
    // ----------------------------------------------------------

    final devicesSnapshot = await _devices.get();

    final devices = devicesSnapshot.docs.map((doc) {
      return _deviceFromFirestore(
        doc.id,
        doc.data(),
      );
    }).toList();

    // ----------------------------------------------------------
    // Settings
    // ----------------------------------------------------------

    final preferencesSnapshot = await _preferences.get();
    final preferences = preferencesSnapshot.data();

    final cueSettings = preferences == null
        ? CueSettings.defaults
        : _cueSettingsFromFirestore(preferences);

    final escalation = EscalationSettings(
      waitSeconds:
      (preferences?['waiting_time'] as num?)?.toInt() ??
          patient.waitingTime ??
          30,
    );

    final reminderPreference = _reminderPreferenceFromFirestore(
      preferences?['reminder_preference'] as String?,
    );

    // Emergency Contacts enabled/disabled preference.
    // Defaults to true for existing accounts without this field.
    final emergencyContactsEnabled =
        preferences?['emergency_contacts_enabled'] as bool? ?? true;

    return UserData(
      episodes: episodes,
      contacts: contacts,
      reminders: reminders,
      devices: devices,
      cueSettings: cueSettings,
      escalation: escalation,
      reminderPreference: reminderPreference,
      emergencyContactsEnabled: emergencyContactsEnabled,
    );
  }

  // ------------------------------------------------------------
  // EMERGENCY CONTACTS
  // ------------------------------------------------------------

  @override
  Future<void> saveContact(
      EmergencyContact contact,
      ) async {
    await _emergencyContacts.doc(contact.id).set({
      'name': contact.name,
      'phone': contact.phone,
      'is_designated': contact.isDesignated,
    });
  }

  @override
  Future<void> deleteContact(String id) async {
    await _emergencyContacts.doc(id).delete();
  }

  @override
  Future<void> saveEmergencyContactsEnabled(bool enabled) async {
    await _preferences.set(
      {
        'emergency_contacts_enabled': enabled,
      },
      SetOptions(merge: true),
    );
  }



  // ------------------------------------------------------------
  // SAVED DEVICES
  // ------------------------------------------------------------

  // Only the device identity is stored. Connection state and battery level
  // are live values and are not saved.
  @override
  Future<void> saveDevice(ReStepDevice device) async {
    await _devices.doc(device.id).set({
      'name': device.name,
      'kind': device.kind.name,
    });
  }

  @override
  Future<void> deleteDevice(String id) async {
    await _devices.doc(id).delete();
  }


  // ------------------------------------------------------------
  // REMINDERS
  // ------------------------------------------------------------

  @override
  Future<void> saveReminder(
      Reminder reminder,
      ) async {
    await _reminders.doc(reminder.id).set({
      'title': reminder.title,
      'context': reminder.context,
      'date': Timestamp.fromDate(reminder.date),
      'time': _formatTime(reminder.time),
      'location': reminder.location,
      'frequency': reminder.frequency,
    });
  }

  @override
  Future<void> deleteReminder(String id) async {
    await _reminders.doc(id).delete();
  }

  // ------------------------------------------------------------
  // FoG EPISODES
  // ------------------------------------------------------------

  @override
  Future<void> saveEpisode(
      FogEpisode episode,
      ) async {
    final data = <String, dynamic>{
      'start_time': Timestamp.fromDate(episode.startTime),
      'duration_seconds': episode.duration.inSeconds,
      'source': episode.source.name,
      'cue_delivered': episode.cueDelivered?.name,
      'alert_contact_name': episode.alertContactName,
      'alert_sent_at': episode.alertSentAt == null
          ? null
          : Timestamp.fromDate(episode.alertSentAt!),
      'alert_cancelled': episode.alertCancelled,
    };

    if (episode.context != null) {
      data['context'] = {
        'activities': episode.context!.activities,
        'note': episode.context!.note,
      };
    } else {
      data['context'] = null;
    }

    await _episodes.doc(episode.id).set(data);
  }

  // ------------------------------------------------------------
  // CUE SETTINGS
  // ------------------------------------------------------------

  @override
  Future<void> saveCueSettings(
      CueSettings settings,
      ) async {
    await _preferences.set(
      {
        'cue_type': settings.type.name,
        'cue_pattern': settings.pattern.name,
        'cue_duration_seconds': settings.durationSeconds,
      },
      SetOptions(merge: true),
    );
  }

  // ------------------------------------------------------------
  // ESCALATION / WAITING TIME
  // ------------------------------------------------------------

  @override
  Future<void> saveEscalationSettings(
      EscalationSettings settings,
      ) async {
    await _preferences.set(
      {
        'waiting_time': settings.waitSeconds,
      },
      SetOptions(merge: true),
    );
  }

  // ------------------------------------------------------------
  // REMINDER PREFERENCE
  // ------------------------------------------------------------

  @override
  Future<void> saveReminderPreference(
      ReminderPreference preference,
      ) async {
    await _preferences.set(
      {
        'reminder_preference': preference.name,
      },
      SetOptions(merge: true),
    );
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  FogEpisode _episodeFromFirestore(
      String id,
      Map<String, dynamic> data,
      ) {
    final startTimestamp = data['start_time'] as Timestamp?;

    final startTime = startTimestamp?.toDate() ?? DateTime.now();

    final durationSeconds =
        (data['duration_seconds'] as num?)?.toInt() ?? 1;

    final source = _episodeSourceFromString(
      data['source'] as String?,
    );

    final cueDelivered = _cueTypeFromString(
      data['cue_delivered'] as String?,
    );

    final contextData = data['context'] as Map<String, dynamic>?;

    EpisodeContext? context;

    if (contextData != null) {
      final activities =
          (contextData['activities'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
              const <String>[];

      final note = contextData['note'] as String?;

      context = EpisodeContext(
        activities: activities,
        note: note,
      );
    }

    final alertTimestamp = data['alert_sent_at'] as Timestamp?;

    return FogEpisode(
      id: id,
      startTime: startTime,
      duration: Duration(seconds: durationSeconds),
      source: source,
      cueDelivered: cueDelivered,
      context: context,
      alertContactName: data['alert_contact_name'] as String?,
      alertSentAt: alertTimestamp?.toDate(),
      alertCancelled: data['alert_cancelled'] as bool? ?? false,
    );
  }

  ReStepDevice _deviceFromFirestore(
      String id,
      Map<String, dynamic> data,
      ) {
    final kind = _deviceKindFromString(
      data['kind'] as String?,
    );

    return ReStepDevice(
      id: id,
      name: data['name'] as String? ?? kind.label,
      kind: kind,
      connected: data['connected'] as bool? ?? false,
      batteryPercent: (data['battery_percent'] as num?)?.toInt(),
    );
  }

  CueSettings _cueSettingsFromFirestore(
      Map<String, dynamic> data,
      ) {
    return CueSettings(
      type: _cueTypeFromString(
        data['cue_type'] as String?,
      ) ??
          CueSettings.defaults.type,
      pattern: _cuePatternFromString(
        data['cue_pattern'] as String?,
      ) ??
          CueSettings.defaults.pattern,
      durationSeconds:
      (data['cue_duration_seconds'] as num?)?.toInt() ??
          CueSettings.defaults.durationSeconds,
    );
  }

  EpisodeSource _episodeSourceFromString(String? value) {
    for (final source in EpisodeSource.values) {
      if (source.name == value) {
        return source;
      }
    }

    return EpisodeSource.manual;
  }

  CueType? _cueTypeFromString(String? value) {
    if (value == null) return null;

    for (final type in CueType.values) {
      if (type.name == value) {
        return type;
      }
    }

    return null;
  }

  CuePattern? _cuePatternFromString(String? value) {
    if (value == null) return null;

    for (final pattern in CuePattern.values) {
      if (pattern.name == value) {
        return pattern;
      }
    }

    return null;
  }

  DeviceKind _deviceKindFromString(String? value) {
    for (final kind in DeviceKind.values) {
      if (kind.name == value) {
        return kind;
      }
    }

    return DeviceKind.shimmerImu;
  }

  ReminderPreference _reminderPreferenceFromFirestore(
      String? value,
      ) {
    for (final preference in ReminderPreference.values) {
      if (preference.name == value) {
        return preference;
      }
    }

    return ReminderPreference.both;
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  TimeOfDay _parseTime(String? value) {
    if (value == null || !value.contains(':')) {
      return const TimeOfDay(
        hour: 10,
        minute: 0,
      );
    }

    final parts = value.split(':');

    final hour = int.tryParse(parts[0]) ?? 10;
    final minute = int.tryParse(parts[1]) ?? 0;

    return TimeOfDay(
      hour: hour,
      minute: minute,
    );
  }
}
