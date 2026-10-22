import 'package:flutter/material.dart';

import '../../models/cue_settings.dart';
import '../../models/device.dart';
import '../../models/emergency.dart';
import '../../models/fog_episode.dart';
import '../../models/patient.dart';
import '../../models/routine.dart';
import '../../models/user_data.dart';

/// All sample data used to demonstrate the prototype.
/// Replace by loading real records from the backend (see DataRepository).
class MockData {
  MockData._();

  static final Patient demoPatient = Patient(
    id: 'patient-demo',
    fullName: 'Sara Alharbi',
    email: 'demo@restep.app',
    dateOfBirth: DateTime(1962, 4, 12),
  );

  static UserData userData(DateTime now) {
    return UserData(
      episodes: episodes(now),
      contacts: contacts,
      reminders: const [],
      devices: pairedDevices,
      cueSettings: CueSettings.defaults,
      escalation: const EscalationSettings(
        waitSeconds: 30,
      ),
      reminderPreference: ReminderPreference.both,
    );
  }

  // ---------------------------------------------------------------- devices

  static const List<ReStepDevice> pairedDevices = [
    ReStepDevice(
      id: 'shimmer-a1b2',
      name: 'Shimmer3 IMU (A1B2)',
      kind: DeviceKind.shimmerImu,
      connected: true,
      batteryPercent: 82,
    ),
    ReStepDevice(
      id: 'watch-fe-01',
      name: 'Galaxy Watch FE',
      kind: DeviceKind.smartwatch,
      connected: true,
      batteryPercent: 64,
    ),
  ];

  /// Devices a Bluetooth scan could find.
  /// Used by MockDeviceService.
  static const List<ReStepDevice> nearbyDevices = [
    ReStepDevice(
      id: 'shimmer-a1b2',
      name: 'Shimmer3 IMU (A1B2)',
      kind: DeviceKind.shimmerImu,
      batteryPercent: 82,
    ),
    ReStepDevice(
      id: 'shimmer-7f3c',
      name: 'Shimmer3 IMU (7F3C)',
      kind: DeviceKind.shimmerImu,
      batteryPercent: 91,
    ),
    ReStepDevice(
      id: 'watch-fe-01',
      name: 'Galaxy Watch FE',
      kind: DeviceKind.smartwatch,
      batteryPercent: 64,
    ),
  ];

  // --------------------------------------------------------------- contacts

  static const List<EmergencyContact> contacts = [
    EmergencyContact(
      id: 'contact-1',
      name: 'Nora Alharbi',
      phone: '+966507654321',
      isDesignated: true,
    ),
    EmergencyContact(
      id: 'contact-2',
      name: 'Faisal Alharbi',
      phone: '+966559876543',
    ),
  ];

  // -------------------------------------------------------------- episodes

  static DateTime _at(
      DateTime now,
      int daysAgo,
      int hour,
      int minute,
      ) =>
      DateTime(
        now.year,
        now.month,
        now.day - daysAgo,
        hour,
        minute,
      );

  static FogEpisode _ep(
      String id,
      DateTime start,
      int seconds, {
        CueType? cue = CueType.vibration,
        EpisodeSource source = EpisodeSource.detected,
        List<String> activities = const [],
        String? note,
        String? alertContact,
        bool alertCancelled = false,
      }) {
    return FogEpisode(
      id: id,
      startTime: start,
      duration: Duration(seconds: seconds),
      source: source,
      cueDelivered: cue,
      context: (activities.isEmpty && note == null)
          ? null
          : EpisodeContext(
        activities: activities,
        note: note,
      ),
      alertContactName: alertContact,
      alertSentAt: alertContact == null
          ? null
          : start.add(
        const Duration(seconds: 30),
      ),
      alertCancelled: alertCancelled,
    );
  }

  /// About four weeks of realistic sample episodes.
  /// Newest first is handled by AppState.
  static List<FogEpisode> episodes(DateTime now) {
    return [
      _ep(
        'e01',
        now.subtract(
          const Duration(minutes: 135),
        ),
        9,
        activities: ['Turning'],
      ),
      _ep(
        'e02',
        now.subtract(
          const Duration(minutes: 300),
        ),
        6,
      ),
      _ep(
        'e03',
        _at(now, 1, 18, 20),
        12,
        activities: ['Passing a doorway'],
      ),
      _ep(
        'e04',
        _at(now, 1, 10, 5),
        8,
      ),
      _ep(
        'e05',
        _at(now, 2, 21, 10),
        15,
        activities: [
          'Turning',
          'Feeling tired',
        ],
      ),
      _ep(
        'e06',
        _at(now, 2, 8, 40),
        7,
      ),
      _ep(
        'e07',
        _at(now, 3, 14, 30),
        22,
        activities: [
          'Narrow or crowded space',
        ],
      ),
      _ep(
        'e08',
        _at(now, 4, 11, 15),
        9,
        source: EpisodeSource.quickAssistance,
      ),
      _ep(
        'e09',
        _at(now, 4, 19, 45),
        10,
        activities: [
          'Starting to walk',
        ],
      ),
      _ep(
        'e10',
        _at(now, 5, 9, 0),
        12,
        cue: null,
        source: EpisodeSource.manual,
        activities: [
          'Turning',
        ],
        note:
        'Did not feel the watch, added it myself.',
      ),
      _ep(
        'e11',
        _at(now, 6, 16, 25),
        8,
      ),
      _ep(
        'e12',
        _at(now, 7, 13, 50),
        47,
        activities: [
          'Narrow or crowded space',
          'Feeling stressed or in a hurry',
        ],
        alertContact: 'Nora Alharbi',
        alertCancelled: true,
      ),
      _ep(
        'e13',
        _at(now, 9, 10, 30),
        9,
      ),
      _ep(
        'e14',
        _at(now, 9, 20, 15),
        11,
        cue: CueType.auditory,
      ),
      _ep(
        'e15',
        _at(now, 10, 8, 10),
        6,
      ),
      _ep(
        'e16',
        _at(now, 12, 15, 0),
        14,
        cue: null,
        source: EpisodeSource.manual,
      ),
      _ep(
        'e17',
        _at(now, 13, 12, 40),
        8,
        cue: CueType.auditory,
      ),
      _ep(
        'e18',
        _at(now, 15, 18, 55),
        19,
        cue: CueType.auditory,
        activities: [
          'Carrying something',
        ],
      ),
      _ep(
        'e19',
        _at(now, 16, 9, 25),
        7,
        cue: CueType.auditory,
      ),
      _ep(
        'e20',
        _at(now, 18, 11, 50),
        10,
        cue: CueType.auditory,
      ),
      _ep(
        'e21',
        _at(now, 20, 17, 30),
        13,
        cue: CueType.auditory,
      ),
      _ep(
        'e22',
        _at(now, 22, 8, 55),
        9,
        cue: CueType.auditory,
      ),
      _ep(
        'e23',
        _at(now, 24, 14, 15),
        16,
        cue: CueType.auditory,
      ),
      _ep(
        'e24',
        _at(now, 26, 10, 40),
        8,
        cue: CueType.auditory,
      ),
      _ep(
        'e25',
        _at(now, 28, 19, 5),
        12,
        cue: CueType.auditory,
      ),
    ];
  }
}
