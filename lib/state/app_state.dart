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

/// Single source of truth for the UI. All data access goes through the
/// service interfaces, so mock services can later be swapped for real ones.
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

  /// The device service in use (the live sensor screen needs it).
  DeviceService get deviceService => _deviceService;

  Patient? _patient;
  List<FogEpisode> _episodes = [];
  List<Reminder> _reminders = [];
  List<EmergencyContact> _contacts = [];
  List<ReStepDevice> _devices = [];
  CueSettings _cueSettings = CueSettings.defaults;
  EscalationSettings _escalation = const EscalationSettings(waitSeconds: 30);
  ReminderPreference _reminderPreference = ReminderPreference.both;
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

  ReStepDevice? get sensor => _deviceOfKind(DeviceKind.shimmerImu);
  ReStepDevice? get watch => _deviceOfKind(DeviceKind.smartwatch);
  bool get isMonitoring => sensor?.connected ?? false;

  EmergencyContact? get designatedContact {
    for (final c in _contacts) {
      if (c.isDesignated) return c;
    }
    return null;
  }

  ReStepDevice? _deviceOfKind(DeviceKind kind) {
    for (final d in _devices) {
      if (d.kind == kind) return d;
    }
    return null;
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
        fullName: fullName, email: email, password: password);
    await _loadFor(patient, isNewAccount: true);
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordReset(email);

  Future<void> _loadFor(Patient patient, {required bool isNewAccount}) async {
    final data = await _repository.loadUserData(
      patient,
      isNewAccount: isNewAccount,
      now: _clock(),
    );
    _applyUserData(patient, data);
    notifyListeners();
    // Reconnect to the sensor used last time, without blocking the login.
    unawaited(_autoConnectSensor());
  }

  /// Connects automatically to the sensor the patient used last time.
  /// If the sensor is off, the device service keeps retrying in the background.
  Future<void> _autoConnectSensor() async {
    final saved = await _deviceService.lastConnectedDevice();
    if (saved == null || _patient == null) return;
    if (sensor != null && sensor!.connected) return;

    // Show the sensor on Home as "Disconnected" while we try to connect.
    if (!_devices.any((d) => d.id == saved.id)) {
      _devices = [
        ..._devices.where((d) => d.kind != saved.kind),
        saved,
      ]..sort((a, b) => a.kind.index.compareTo(b.kind.index));
      notifyListeners();
    }
    await connectDevice(saved);
  }

  /// Disconnects the sensor and stops automatic reconnection
  /// (used when the patient signs out or deletes the account).
  Future<void> _releaseSensor() async {
    final s = sensor;
    if (s == null) return;
    try {
      await _deviceService.disconnect(s);
    } catch (_) {
      // The sensor may already be off; nothing else to do.
    }
  }

  void _applyUserData(Patient patient, UserData data) {
    _patient = patient;
    _episodes = [...data.episodes]
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    _contacts = [...data.contacts];
    _reminders = [...data.reminders];
    _devices = [...data.devices];
    _cueSettings = data.cueSettings;
    _escalation = data.escalation;
    _reminderPreference = data.reminderPreference;
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

  /// Pass [password] after a [ReauthenticationRequiredException].
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
    for (final e in _episodes) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// The range covered by a period choice (null = all recorded episodes).
  DateRange? rangeFor(PeriodOption option, {DateRange? custom}) {
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
    return _episodes.where((e) => range.contains(e.startTime)).toList();
  }

  void _insertEpisode(FogEpisode episode) {
    _episodes = [..._episodes, episode]
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    unawaited(_repository.saveEpisode(episode));
  }

  void _replaceEpisode(String id, FogEpisode Function(FogEpisode) update) {
    final index = _episodes.indexWhere((e) => e.id == id);
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
    _replaceEpisode(episodeId, (e) => e.copyWith(context: context));
  }

  // --------------------------------------------------------------- cues

  Future<void> updateCueSettings(CueSettings settings) async {
    _cueSettings = settings;
    notifyListeners();
    await _repository.saveCueSettings(settings);
  }

  Future<void> testCue(CueSettings settings) => _cueService.testCue(settings);

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
    _escalation = EscalationSettings(
      waitSeconds: waitSeconds,
    );

    final current = _patient;

    if (current != null) {
      final updated = current.copyWith(
        waitingTime: waitSeconds,
      );

      _patient = await _auth.updateProfile(updated);
    }

    notifyListeners();
  }

  /// Records an episode that met the escalation conditions.
  /// When [alertedContact] is given, an alert record is attached.
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

  /// The patient responded within the grace period: a cancellation message is sent.
  void markAlertCancelled(String episodeId) {
    _replaceEpisode(episodeId, (e) => e.copyWith(alertCancelled: true));
  }

  // ----------------------------------------------------------- contacts

  void saveContact(EmergencyContact contact) {
    var saved = contact;
    if (_contacts.isEmpty) {
      saved = saved.copyWith(isDesignated: true);
    }
    final list = [..._contacts];
    final index = list.indexWhere((c) => c.id == saved.id);
    if (index >= 0) {
      list[index] = saved;
    } else {
      list.add(saved);
    }
    _contacts = _normaliseDesignated(list, preferredId: saved.id);
    for (final c in _contacts) {
      unawaited(_repository.saveContact(c));
    }
    notifyListeners();
  }

  void removeContact(String id) {
    final list = _contacts.where((c) => c.id != id).toList();
    _contacts = _normaliseDesignated(list);
    unawaited(_repository.deleteContact(id));
    notifyListeners();
  }

  /// Exactly one contact is designated (when any contact exists).
  List<EmergencyContact> _normaliseDesignated(
      List<EmergencyContact> list, {
        String? preferredId,
      }) {
    if (list.isEmpty) return list;
    String? designatedId;
    if (preferredId != null) {
      for (final c in list) {
        if (c.id == preferredId && c.isDesignated) designatedId = c.id;
      }
    }
    if (designatedId == null) {
      for (final c in list) {
        if (c.isDesignated) {
          designatedId = c.id;
          break;
        }
      }
    }
    designatedId ??= list.first.id;
    return [
      for (final c in list) c.copyWith(isDesignated: c.id == designatedId),
    ];
  }

  String newContactId() => _newId('contact');

  // ------------------------------------------------------------ reminders

  String newReminderId() => _newId('reminder');

  Future<void> saveReminder(Reminder reminder) async {
    final list = [..._reminders];

    final index = list.indexWhere(
          (r) => r.id == reminder.id,
    );

    if (index >= 0) {
      list[index] = reminder;
    } else {
      list.add(reminder);
    }

    list.sort((a, b) {
      final aDateTime = DateTime(
        a.date.year,
        a.date.month,
        a.date.day,
        a.time.hour,
        a.time.minute,
      );

      final bDateTime = DateTime(
        b.date.year,
        b.date.month,
        b.date.day,
        b.time.hour,
        b.time.minute,
      );

      return aDateTime.compareTo(bDateTime);
    });

    _reminders = list;

    await _repository.saveReminder(reminder);

    notifyListeners();
  }

  Future<void> deleteReminder(String id) async {
    _reminders =
        _reminders.where((r) => r.id != id).toList();

    await _repository.deleteReminder(id);

    notifyListeners();
  }

  Future<void> setReminderPreference(
      ReminderPreference preference,
      ) async {
    _reminderPreference = preference;
    notifyListeners();

    await _repository.saveReminderPreference(
      preference,
    );
  }
  List<UpcomingReminder> get upcomingReminders {
    final items = <UpcomingReminder>[];

    for (final reminder in _reminders) {
      final when = DateTime(
        reminder.date.year,
        reminder.date.month,
        reminder.date.day,
        reminder.time.hour,
        reminder.time.minute,
      );

      final key = '${reminder.id}@${when.toIso8601String()}';

      if (_dismissedReminders.contains(key)) {
        continue;
      }

      items.add(
        UpcomingReminder(
          key: key,
          title: reminder.title,
          detail: reminder.location.isEmpty
              ? reminder.context
              : reminder.location,
          when: when,
          isMedication: false,
        ),
      );
    }

    items.sort(
          (a, b) => a.when.compareTo(b.when),
    );

    return items;
  }

  void dismissReminder(String key) {
    _dismissedReminders.add(key);
    notifyListeners();
  }
  // ------------------------------------------------------------ devices

  Future<List<ReStepDevice>> scanNearby() => _deviceService.scanNearby();

  Future<bool> connectDevice(ReStepDevice device) async {
    final ok = await _deviceService.connect(device);
    if (ok) {
      final connected = device.copyWith(
        connected: true,
        batteryPercent: device.batteryPercent,
      );
      _devices = [
        ..._devices.where((d) => d.kind != device.kind),
        connected,
      ]..sort((a, b) => a.kind.index.compareTo(b.kind.index));
      notifyListeners();
    }
    return ok;
  }

  Future<void> disconnectDevice(String id) async {
    final index = _devices.indexWhere((d) => d.id == id);
    if (index < 0) return;
    await _deviceService.disconnect(_devices[index]);
    final copy = [..._devices];
    copy[index] = copy[index].copyWith(connected: false);
    _devices = copy;
    notifyListeners();
  }

  /// Applies live connection / battery changes reported by the hardware.
  void _onDeviceUpdate(DeviceUpdate update) {
    final index = _devices.indexWhere((d) => d.id == update.id);
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

  /// Prototype helper: the sensor drops its connection, the patient is
  /// notified, and ReStep reconnects automatically after a few seconds.
  void simulateSensorDisconnect() {
    final s = sensor;
    if (s == null || !s.connected) return;
    final index = _devices.indexWhere((d) => d.id == s.id);
    final copy = [..._devices];
    copy[index] = copy[index].copyWith(connected: false);
    _devices = copy;
    notifyListeners();

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 6), () {
      final i = _devices.indexWhere((d) => d.id == s.id);
      if (i < 0) return;
      final again = [..._devices];
      again[i] = again[i].copyWith(connected: true);
      _devices = again;
      notifyListeners();
    });
  }

  // ------------------------------------------------------------ reports

  Future<ReportResult> generateReport(DateRange? range) {
    final patient = _patient;
    if (patient == null) {
      throw StateError('No signed-in patient');
    }
    return _reportService.generate(
      patient: patient,
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