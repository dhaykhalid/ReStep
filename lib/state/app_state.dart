
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../models/device.dart';
import '../models/emergency.dart';
import '../models/fog_episode.dart';
import '../models/patient.dart';
import '../models/period.dart';
import '../models/routine.dart';
import '../models/user_data.dart';
import '../services/auth_service.dart';
import '../services/cue_service.dart';
import '../services/data_repository.dart';
import '../services/device_service.dart';
import '../services/report_service.dart';

/// A cue that is currently running on the smartwatch.
class ActiveCue {
  const ActiveCue({
    required this.source,
    required this.startedAt,
    required this.settings,
  });

  final EpisodeSource source;
  final DateTime startedAt;
  final CueSettings settings;
}

/// Single source of truth for the UI.
class AppState extends ChangeNotifier {
  AppState({
    AuthService? authService,
    DataRepository? repository,
    DeviceService? deviceService,
    CueService? cueService,
    ReportService? reportService,
    DateTime Function()? clock,
  })  : _auth = authService ?? FirebaseAuthService(),
        _repository = repository ?? FirebaseDataRepository(),
        _deviceService = deviceService ?? MockDeviceService(),
        _cueService = cueService ?? MockCueService(),
        _reportService = reportService ?? MockReportService(),
        _clock = clock ?? DateTime.now {
    _deviceSub = _deviceService.updates.listen(_onDeviceUpdate);
  }

  final AuthService _auth;
  final DataRepository _repository;
  final DeviceService _deviceService;
  final CueService _cueService;
  final ReportService _reportService;
  final DateTime Function() _clock;

  StreamSubscription<DeviceUpdate>? _deviceSub;

  /// The device service in use.
  DeviceService get deviceService => _deviceService;

  Patient? _patient;
  List<FogEpisode> _episodes = [];
  List<Reminder> _reminders = [];
  List<EmergencyContact> _contacts = [];
  List<ReStepDevice> _devices = [];

  CueSettings _cueSettings = CueSettings.defaults;
  EscalationSettings _escalation =
  const EscalationSettings(waitSeconds: 30);
  ReminderPreference _reminderPreference = ReminderPreference.both;

  // Emergency Contacts feature state.
  bool _emergencyContactsEnabled = true;

  final Set<String> _dismissedReminders = {};

  ActiveCue? _activeCue;
  int _selectedTab = 0;
  int _idCounter = 0;
  Timer? _reconnectTimer;

  // ------------------------------------------------------------- getters

  DateTime get now => _clock();

  Patient? get patient => _patient;

  bool get isSignedIn => _patient != null;

  List<FogEpisode> get episodes => List.unmodifiable(_episodes);

  List<EmergencyContact> get contacts => List.unmodifiable(_contacts);

  List<Reminder> get reminders => List.unmodifiable(_reminders);

  List<ReStepDevice> get pairedDevices => List.unmodifiable(_devices);

  CueSettings get cueSettings => _cueSettings;

  EscalationSettings get escalation => _escalation;

  ReminderPreference get reminderPreference => _reminderPreference;

  ActiveCue? get activeCue => _activeCue;

  int get selectedTab => _selectedTab;

  bool get emergencyContactsEnabled => _emergencyContactsEnabled;

  ReStepDevice? get sensor => _deviceOfKind(DeviceKind.shimmerImu);

  ReStepDevice? get watch => _deviceOfKind(DeviceKind.smartwatch);

  bool get isMonitoring => sensor?.connected ?? false;

  EmergencyContact? get designatedContact {
    for (final contact in _contacts) {
      if (contact.isDesignated) return contact;
    }
    return null;
  }

  /// The device of this kind to show as "the" sensor/watch: the connected one
  /// if there is one, otherwise the first saved one.
  ReStepDevice? _deviceOfKind(DeviceKind kind) {
    ReStepDevice? first;
    for (final device in _devices) {
      if (device.kind != kind) continue;
      if (device.connected) return device;
      first ??= device;
    }
    return first;
  }

  String _newId(String prefix) =>
      '$prefix-${_clock().microsecondsSinceEpoch}-${_idCounter++}';

  void goToTab(int index) {
    _selectedTab = index;
    notifyListeners();
  }

  // ------------------------------------------------------------ account

  Future<void> restoreSession() async {
    final restored = await _auth.restoreSession();
    if (restored != null) {
      await _loadFor(restored, isNewAccount: false);
    }
  }

  Future<void> signIn(String email, String password) async {
    final patient = await _auth.signIn(email, password);
    await _loadFor(patient, isNewAccount: false);
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final patient = await _auth.register(
      fullName: fullName,
      email: email,
      password: password,
    );
    await _loadFor(patient, isNewAccount: true);
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordReset(email);

  Future<void> _loadFor(
      Patient patient, {
        required bool isNewAccount,
      }) async {
    final data = await _repository.loadUserData(
      patient,
      isNewAccount: isNewAccount,
      now: _clock(),
    );

    _applyUserData(patient, data);
    notifyListeners();

    // Reconnect to the sensor used last time without blocking login.
    unawaited(_autoConnectSensor());
  }

  /// Connects automatically to the sensor the patient used last time.
  Future<void> _autoConnectSensor() async {
    final saved = await _deviceService.lastConnectedDevice();

    if (saved == null || _patient == null) return;
    if (sensor != null && sensor!.connected) return;

    if (!_devices.any((device) => device.id == saved.id)) {
      // Add it without removing the other saved devices.
      _devices = [..._devices, saved]
        ..sort((a, b) => a.kind.index.compareTo(b.kind.index));

      notifyListeners();
    }

    await connectDevice(saved);
  }

  /// Disconnects the sensor when the patient signs out or deletes the account.
  Future<void> _releaseSensor() async {
    final currentSensor = sensor;
    if (currentSensor == null) return;

    try {
      await _deviceService.disconnect(currentSensor);
    } catch (_) {
      // The device may already be disconnected.
    }
  }

  void _applyUserData(Patient patient, UserData data) {
    _patient = patient;

    _episodes = [...data.episodes]
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    _contacts = _normaliseDesignated([...data.contacts]);
    _reminders = [...data.reminders];
    // Saved devices start as "Not connected"; the live state comes from the
    // sensor after it connects.
    _devices = [
      for (final d in data.devices)
        ReStepDevice(id: d.id, name: d.name, kind: d.kind),
    ];

    _cueSettings = data.cueSettings;
    _escalation = data.escalation;
    _reminderPreference = data.reminderPreference;

    // Loaded from UserData after the repository/model are updated.
    _emergencyContactsEnabled = data.emergencyContactsEnabled;

    _dismissedReminders.clear();
    _activeCue = null;
    _selectedTab = 0;
  }

  void _clear() {
    _reconnectTimer?.cancel();

    _patient = null;
    _episodes = [];
    _reminders = [];
    _contacts = [];
    _devices = [];

    _cueSettings = CueSettings.defaults;
    _escalation = const EscalationSettings(waitSeconds: 30);
    _reminderPreference = ReminderPreference.both;

    _emergencyContactsEnabled = true;

    _dismissedReminders.clear();
    _activeCue = null;
    _selectedTab = 0;
  }

  Future<void> signOut() async {
    await _releaseSensor();
    await _auth.signOut();
    _clear();
    notifyListeners();
  }

  /// Pass [password] after a ReauthenticationRequiredException.
  Future<void> deleteAccount({String? password}) async {
    await _auth.deleteAccount(password: password);
    await _releaseSensor();
    _clear();
    notifyListeners();
  }

  Future<void> updateProfile(Patient updated) async {
    _patient = await _auth.updateProfile(updated);
    notifyListeners();
  }

  // ----------------------------------------------------------- episodes

  FogEpisode? episodeById(String id) {
    for (final episode in _episodes) {
      if (episode.id == id) return episode;
    }
    return null;
  }

  /// The range covered by a period choice (null = all recorded episodes).
  DateRange? rangeFor(
      PeriodOption option, {
        DateRange? custom,
      }) {
    final today = Fmt.dayOnly(now);

    switch (option) {
      case PeriodOption.last7Days:
        return DateRange(Fmt.addDays(today, -6), today);

      case PeriodOption.last30Days:
        return DateRange(Fmt.addDays(today, -29), today);

      case PeriodOption.allTime:
        return null;

      case PeriodOption.custom:
        return custom ?? DateRange(Fmt.addDays(today, -6), today);
    }
  }

  List<FogEpisode> episodesIn(DateRange? range) {
    if (range == null) return List<FogEpisode>.of(_episodes);

    return _episodes.where((episode) {
      return range.contains(episode.startTime);
    }).toList();
  }

  void _insertEpisode(FogEpisode episode) {
    _episodes = [..._episodes, episode]
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    unawaited(_repository.saveEpisode(episode));
  }

  void _replaceEpisode(
      String id,
      FogEpisode Function(FogEpisode) update,
      ) {
    final index = _episodes.indexWhere((episode) => episode.id == id);
    if (index < 0) return;

    final updated = update(_episodes[index]);
    final copy = [..._episodes];

    copy[index] = updated;
    _episodes = copy;

    unawaited(_repository.saveEpisode(updated));
    notifyListeners();
  }

  FogEpisode addManualEpisode({
    required DateTime start,
    required Duration duration,
    EpisodeContext? context,
  }) {
    final episode = FogEpisode(
      id: _newId('ep'),
      startTime: start,
      duration: duration,
      source: EpisodeSource.manual,
      context: (context == null || context.isEmpty) ? null : context,
    );

    _insertEpisode(episode);
    notifyListeners();

    return episode;
  }

  void attachContext(String episodeId, EpisodeContext context) {
    _replaceEpisode(
      episodeId,
          (episode) => episode.copyWith(context: context),
    );
  }

  // --------------------------------------------------------------- cues

  Future<void> updateCueSettings(CueSettings settings) async {
    _cueSettings = settings;
    notifyListeners();

    await _repository.saveCueSettings(settings);
  }

  Future<void> testCue(CueSettings settings) =>
      _cueService.testCue(settings);

  /// Starts a cue (automatic detection or Quick Assistance).
  ActiveCue startCue(EpisodeSource source) {
    final cue = ActiveCue(
      source: source,
      startedAt: _clock(),
      settings: _cueSettings,
    );

    _activeCue = cue;
    unawaited(_cueService.startCue(_cueSettings));
    notifyListeners();

    return cue;
  }

  /// Stops the active cue and records the episode in the FoG history.
  Future<FogEpisode?> finishCue({int? elapsedSeconds}) async {
    final cue = _activeCue;
    if (cue == null) return null;

    _activeCue = null;
    await _cueService.stopCue();

    var seconds =
        elapsedSeconds ?? _clock().difference(cue.startedAt).inSeconds;

    if (seconds < 1) seconds = 1;

    final episode = FogEpisode(
      id: _newId('ep'),
      startTime: cue.startedAt,
      duration: Duration(seconds: seconds),
      source: cue.source,
      cueDelivered: cue.settings.type,
    );

    _insertEpisode(episode);
    notifyListeners();

    return episode;
  }

  // -------------------------------------------------------- escalation

  Future<void> updateEscalation(int waitSeconds) async {
    _escalation = EscalationSettings(waitSeconds: waitSeconds);

    final current = _patient;

    if (current != null) {
      final updated = current.copyWith(waitingTime: waitSeconds);
      _patient = await _auth.updateProfile(updated);
    }

    notifyListeners();
  }

  /// Records an episode that met the escalation conditions.
  FogEpisode recordEscalatedEpisode({
    required int durationSeconds,
    EmergencyContact? alertedContact,
  }) {
    final end = _clock();

    final episode = FogEpisode(
      id: _newId('ep'),
      startTime: end.subtract(Duration(seconds: durationSeconds)),
      duration: Duration(seconds: durationSeconds),
      source: EpisodeSource.detected,
      cueDelivered: _cueSettings.type,
      alertContactName: alertedContact?.name,
      alertSentAt: alertedContact == null ? null : end,
    );

    _insertEpisode(episode);
    notifyListeners();

    return episode;
  }

  /// The patient responded within the grace period.
  void markAlertCancelled(String episodeId) {
    _replaceEpisode(
      episodeId,
          (episode) => episode.copyWith(alertCancelled: true),
    );
  }

  // ----------------------------------------------------------- contacts

  /// Adds or updates an emergency contact.
  ///
  /// The first contact is designated automatically.
  /// When a contact is designated, other contacts are no longer designated.
  void saveContact(EmergencyContact contact) {
    var saved = contact;

    if (_contacts.isEmpty) {
      saved = saved.copyWith(isDesignated: true);
    }

    final list = [..._contacts];
    final index = list.indexWhere((item) => item.id == saved.id);

    if (index >= 0) {
      list[index] = saved;
    } else {
      list.add(saved);
    }

    _contacts = _normaliseDesignated(
      list,
      preferredId: saved.id,
    );

    for (final item in _contacts) {
      unawaited(_repository.saveContact(item));
    }

    notifyListeners();
  }

  /// Removes a contact.
  ///
  /// A designated contact cannot be removed if other contacts exist.
  /// This method never transfers designation automatically after deletion.
  void removeContact(String id) {
    final index = _contacts.indexWhere((contact) => contact.id == id);

    if (index < 0) return;

    final contact = _contacts[index];

    // Keep the designated contact while other contacts remain.
    if (contact.isDesignated && _contacts.length > 1) {
      return;
    }

    _contacts = _contacts
        .where((contact) => contact.id != id)
        .toList();

    unawaited(_repository.deleteContact(id));
    notifyListeners();
  }

  /// Enables or disables the Emergency Contacts feature.
  ///
  /// Disabling does not delete saved contacts.
  Future<void> setEmergencyContactsEnabled(bool enabled) async {
    _emergencyContactsEnabled = enabled;
    notifyListeners();

    await _repository.saveEmergencyContactsEnabled(enabled);
  }

  /// Exactly one contact is designated when at least one contact exists.
  List<EmergencyContact> _normaliseDesignated(
      List<EmergencyContact> list, {
        String? preferredId,
      }) {
    if (list.isEmpty) return list;

    String? designatedId;

    if (preferredId != null) {
      for (final contact in list) {
        if (contact.id == preferredId && contact.isDesignated) {
          designatedId = contact.id;
          break;
        }
      }
    }

    if (designatedId == null) {
      for (final contact in list) {
        if (contact.isDesignated) {
          designatedId = contact.id;
          break;
        }
      }
    }

    designatedId ??= list.first.id;

    return [
      for (final contact in list)
        contact.copyWith(isDesignated: contact.id == designatedId),
    ];
  }

  String newContactId() => _newId('contact');

  // ------------------------------------------------------------ reminders

  String newReminderId() => _newId('reminder');

  Future<void> saveReminder(Reminder reminder) async {
    final list = [..._reminders];

    final index = list.indexWhere((item) => item.id == reminder.id);

    if (index >= 0) {
      list[index] = reminder;
    } else {
      list.add(reminder);
    }

    // [upcomingReminders] orders them by their next occurrence.
    _reminders = list;

    await _repository.saveReminder(reminder);
    notifyListeners();
  }

  /// Removes the reminder from the list only once Firestore has deleted it,
  /// so a failed delete leaves it visible.
  Future<void> deleteReminder(String id) async {
    await _repository.deleteReminder(id);

    _reminders = _reminders
        .where((reminder) => reminder.id != id)
        .toList();
    notifyListeners();
  }

  /// Pauses or resumes a reminder. The switch moves straight away; if
  /// Firestore rejects the change it moves back and the error is rethrown.
  Future<void> setReminderEnabled(String id, bool enabled) async {
    final previous = reminderById(id);
    if (previous == null || previous.isEnabled == enabled) return;

    _replaceReminder(previous.copyWith(isEnabled: enabled));
    notifyListeners();

    try {
      await _repository.setReminderEnabled(id, enabled);
    } catch (_) {
      // Restore unless the reminder changed or was removed meanwhile.
      if (reminderById(id)?.isEnabled == enabled) {
        _replaceReminder(previous);
        notifyListeners();
      }
      rethrow;
    }
  }

  void _replaceReminder(Reminder reminder) {
    _reminders = [
      for (final item in _reminders)
        if (item.id == reminder.id) reminder else item,
    ];
  }

  /// Every saved reminder, enabled or not, ordered by its next occurrence.
  /// One-time reminders whose time has passed, and weekly reminders with no
  /// days, come last.
  List<Reminder> get sortedReminders {
    final now = _clock();
    DateTime? upcoming(Reminder r) {
      final next = r.nextOccurrence(now);
      return next == null || next.isBefore(now) ? null : next;
    }

    final list = [..._reminders];
    list.sort((a, b) {
      final x = upcoming(a);
      final y = upcoming(b);
      if (x != null && y != null) {
        final byTime = x.compareTo(y);
        if (byTime != 0) return byTime;
      } else if (x != null || y != null) {
        return x != null ? -1 : 1;
      } else {
        // Both past or never due: most recent first.
        final pa = a.nextOccurrence(now);
        final pb = b.nextOccurrence(now);
        if (pa != null && pb != null && pa != pb) return pb.compareTo(pa);
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return list;
  }

  Future<void> setReminderPreference(
      ReminderPreference preference,
      ) async {
    _reminderPreference = preference;
    notifyListeners();

    await _repository.saveReminderPreference(preference);
  }

  Reminder? reminderById(String id) {
    for (final reminder in _reminders) {
      if (reminder.id == id) return reminder;
    }
    return null;
  }

  /// The next occurrence of each enabled reminder (used for Home's "Next
  /// reminder"). Dismissing a daily or weekly occurrence moves that reminder
  /// on to its following occurrence.
  List<UpcomingReminder> get upcomingReminders {
    final items = <UpcomingReminder>[];
    final now = _clock();

    for (final reminder in _reminders) {
      if (!reminder.isEnabled) continue;
      var from = now;
      DateTime? when;
      String? key;
      // At most one week of daily or weekly occurrences can be dismissed.
      for (var i = 0; i < 8; i++) {
        when = reminder.nextOccurrence(from);
        if (when == null) break;
        key = '${reminder.id}@${when.toIso8601String()}';
        if (!_dismissedReminders.contains(key)) break;
        if (reminder.frequency == ReminderFrequency.once) {
          when = null;
          break;
        }
        from = when.add(const Duration(minutes: 1));
        when = null;
      }
      if (when == null || key == null) continue;

      items.add(
        UpcomingReminder(
          key: key,
          title: reminder.title,
          detail: reminder.location,
          when: when,
          isMedication: false,
          reminderId: reminder.id,
          schedule: reminder.scheduleLabel,
        ),
      );
    }

    items.sort((a, b) => a.when.compareTo(b.when));

    return items;
  }

  void dismissReminder(String key) {
    _dismissedReminders.add(key);
    notifyListeners();
  }

  // ------------------------------------------------------------ devices

  Future<List<ReStepDevice>> scanNearby() =>
      _deviceService.scanNearby();

  Future<bool> connectDevice(ReStepDevice device) async {
    final ok = await _deviceService.connect(device);

    if (ok) {
      final index = _devices.indexWhere((item) => item.id == device.id);
      final current = index >= 0 ? _devices[index] : device;
      final connected = current.copyWith(connected: true);

      // Keep every saved device; add this one if it is new.
      final copy = [..._devices];
      if (index >= 0) {
        copy[index] = connected;
      } else {
        copy.add(connected);
      }
      _devices = copy..sort((a, b) => a.kind.index.compareTo(b.kind.index));
      notifyListeners();

      // Save it so it shows under "My devices" next time.
      if (index < 0) {
        try {
          await _repository.saveDevice(
            ReStepDevice(id: device.id, name: device.name, kind: device.kind),
          );
        } catch (_) {
          // Saving failed (for example no internet); the device still works
          // in this session.
        }
      }
    }

    return ok;
  }

  /// "Remove device": disconnects it if needed and deletes it from the
  /// saved list.
  Future<void> removeDevice(String id) async {
    final index = _devices.indexWhere((device) => device.id == id);
    if (index < 0) return;
    final device = _devices[index];

    if (device.connected) {
      await _deviceService.disconnect(device);
    }
    await _deviceService.forgetDevice(device);

    _devices = [..._devices]..removeAt(index);
    notifyListeners();

    try {
      await _repository.deleteDevice(id);
    } catch (_) {
      // It is removed from the list on this phone anyway.
    }
  }

  Future<void> disconnectDevice(String id) async {
    final index = _devices.indexWhere((device) => device.id == id);
    if (index < 0) return;

    await _deviceService.disconnect(_devices[index]);

    final copy = [..._devices];
    copy[index] = copy[index].copyWith(connected: false);
    _devices = copy;

    notifyListeners();
  }

  /// Applies live connection and battery changes reported by the hardware.
  void _onDeviceUpdate(DeviceUpdate update) {
    final index = _devices.indexWhere((device) => device.id == update.id);
    if (index < 0) return;

    final current = _devices[index];

    final sameConnection =
        update.connected == null || update.connected == current.connected;

    final sameBattery = update.batteryPercent == null ||
        update.batteryPercent == current.batteryPercent;

    if (sameConnection && sameBattery) return;

    final copy = [..._devices];

    copy[index] = current.copyWith(
      connected: update.connected,
      batteryPercent: update.batteryPercent,
    );

    _devices = copy;
    notifyListeners();
  }

  /// Prototype helper: the sensor drops its connection, and ReStep reconnects.
  void simulateSensorDisconnect() {
    final currentSensor = sensor;
    if (currentSensor == null || !currentSensor.connected) return;

    final index = _devices.indexWhere(
          (device) => device.id == currentSensor.id,
    );

    final copy = [..._devices];
    copy[index] = copy[index].copyWith(connected: false);
    _devices = copy;

    notifyListeners();

    _reconnectTimer?.cancel();

    _reconnectTimer = Timer(const Duration(seconds: 6), () {
      final i = _devices.indexWhere(
            (device) => device.id == currentSensor.id,
      );

      if (i < 0) return;

      final again = [..._devices];
      again[i] = again[i].copyWith(connected: true);
      _devices = again;

      notifyListeners();
    });
  }

  // ------------------------------------------------------------ reports

  Future<ReportResult> generateReport(DateRange? range) {
    final currentPatient = _patient;

    if (currentPatient == null) {
      throw StateError('No signed-in patient');
    }

    return _reportService.generate(
      patient: currentPatient,
      range: range,
      episodes: episodesIn(range),
      now: _clock(),
    );
  }

  Future<void> shareReport(ReportResult report) =>
      _reportService.share(report);

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _deviceSub?.cancel();
    super.dispose();
  }
}
