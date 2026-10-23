import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/device.dart';
import 'device_service.dart';

/// One IMU reading from the Shimmer3.
/// Acceleration in m/s^2, angular velocity in deg/s, timestamp in ms.
class ShimmerSample {
  const ShimmerSample({
    required this.mac,
    this.timestampMs,
    this.ax,
    this.ay,
    this.az,
    this.gx,
    this.gy,
    this.gz,
  });

  final String mac;
  final double? timestampMs;
  final double? ax, ay, az;
  final double? gx, gy, gz;

  static double? _num(Object? v) => (v as num?)?.toDouble();

  factory ShimmerSample.fromMap(Map<String, dynamic> e) {
    return ShimmerSample(
      mac: (e['mac'] as String).toUpperCase(),
      timestampMs: _num(e['t']),
      ax: _num(e['ax']),
      ay: _num(e['ay']),
      az: _num(e['az']),
      gx: _num(e['gx']),
      gy: _num(e['gy']),
      gz: _num(e['gz']),
    );
  }
}

/// Real Shimmer3 connection through the Kotlin ShimmerBridge
/// (Bluetooth Classic, SPP).
///
/// Automatic reconnection:
/// - The last connected sensor is saved on the phone.
/// - When the app opens, AppState asks for it and connects again.
/// - If the connection drops (sensor off, out of range), we retry every
///   10 seconds until it reconnects or the patient presses Disconnect.
class ShimmerDeviceService implements DeviceService {
  ShimmerDeviceService() {
    _events.receiveBroadcastStream().listen(_onEvent, onError: (_) {});
  }

  static const _method = MethodChannel('com.restep/shimmer');
  static const _events = EventChannel('com.restep/shimmer_stream');

  // Keys used to remember the last sensor on the phone.
  static const _savedMacKey = 'restep_last_sensor_mac';
  static const _savedNameKey = 'restep_last_sensor_name';

  static const Duration _connectTimeout = Duration(seconds: 20);
  static const Duration _retryEvery = Duration(seconds: 10);

  final _updates = StreamController<DeviceUpdate>.broadcast();
  final _samples = StreamController<ShimmerSample>.broadcast();
  final Map<String, Completer<bool>> _pendingConnects = {};

  // Sensors that are connected right now (Ready or Streaming).
  final Set<String> _connected = {};

  // Automatic reconnection state
  String? _autoMac; // sensor we should keep connected, or null
  Timer? _retryTimer;
  bool _retrying = false;

  // Battery smoothing state (per sensor)
  final Map<String, int> _lastBattery = {};
  final Map<String, double> _batteryAverage = {};
  final Map<String, DateTime> _batteryLastSent = {};
  final Map<String, int> _batteryCount = {};
  static const int _batteryWarmup = 120; // about 2 seconds at 60 Hz

  @override
  Stream<DeviceUpdate> get updates => _updates.stream;

  /// Live IMU readings (used later for the FoG detection model).
  Stream<ShimmerSample> get samples => _samples.stream;

  // ---------------------------------------------------------------- scan

  /// Lists the Shimmer sensors already paired in the phone's Bluetooth settings.
  @override
  Future<List<ReStepDevice>> scanNearby() async {
    List<Map> list;
    try {
      list = await _method.invokeListMethod<Map>('getPairedDevices') ?? [];
    } on PlatformException {
      // Bluetooth is off: show "No devices found" instead of crashing
      return [];
    }
    return [
      for (final d in list)
        ReStepDevice(
          id: (d['mac'] as String).toUpperCase(),
          name: d['name'] as String? ?? 'Shimmer3 IMU',
          kind: DeviceKind.shimmerImu,
        ),
    ];
  }

  // ------------------------------------------------------------- connect

  /// Connects, waits until the sensor is ready, then starts streaming.
  @override
  Future<bool> connect(ReStepDevice device) async {
    // The smartwatch is not implemented yet.
    if (device.kind != DeviceKind.shimmerImu) return false;

    final mac = device.id.toUpperCase();
    final ok = await _connectAndStream(mac);

    if (ok) {
      // Remember this sensor and keep it connected from now on.
      _autoMac = mac;
      _stopRetrying();
      await _saveDevice(mac, device.name);
    } else if (mac == _autoMac) {
      // Auto-reconnect target is not reachable yet: keep trying.
      _startRetrying(mac);
    }
    return ok;
  }

  /// The shared connect steps, used by connect() and by the retry timer.
  Future<bool> _connectAndStream(String mac) async {
    // Already connected: just make sure it is streaming.
    // (Calling connect again on a connected Shimmer makes the library drop
    // the connection and start over, which caused a reconnect loop.)
    if (_connected.contains(mac)) {
      return _startStreaming(mac);
    }

    // A connection attempt is already running (for example the automatic
    // one at app start): wait for it instead of starting a second one.
    final running = _pendingConnects[mac];
    if (running != null) {
      final ok = await running.future;
      return ok && await _startStreaming(mac);
    }

    // Start the battery estimate fresh for this connection.
    _resetBattery(mac);

    final completer = Completer<bool>();
    _pendingConnects[mac] = completer;

    try {
      await _method.invokeMethod('connect', {'mac': mac});
    } on PlatformException {
      _pendingConnects.remove(mac);
      if (!completer.isCompleted) completer.complete(false);
      return false;
    }

    // Wait for "Ready". A short "Disconnected" while the library opens the
    // socket is normal, so only a timeout counts as a failure.
    final ok = await completer.future.timeout(_connectTimeout, onTimeout: () {
      if (!completer.isCompleted) completer.complete(false);
      return false;
    });
    _pendingConnects.remove(mac);
    if (!ok) return false;

    return _startStreaming(mac);
  }

  Future<bool> _startStreaming(String mac) async {
    try {
      await _method.invokeMethod('startStreaming', {'mac': mac});
      return true;
    } on PlatformException {
      return false;
    }
  }

  // ---------------------------------------------------------- disconnect

  /// Called when the patient presses Disconnect (or signs out).
  /// This also stops automatic reconnection.
  @override
  Future<void> disconnect(ReStepDevice device) async {
    final mac = device.id.toUpperCase();

    _autoMac = null;
    _stopRetrying();
    await _forgetDevice();

    try {
      await _method.invokeMethod('stopStreaming', {'mac': mac});
    } on PlatformException {
      // Not streaming, ignore.
    }

    // Give the Shimmer library time to send "stop streaming" before closing
    // the connection. Without this pause the library crashes the app
    // (NullPointerException in its IO thread).
    await Future<void>.delayed(const Duration(seconds: 1));

    try {
      await _method.invokeMethod('disconnect', {'mac': mac});
    } on PlatformException {
      // Already disconnected, ignore.
    }
  }

  // ------------------------------------------------- automatic reconnect

  void _startRetrying(String mac) {
    if (_retryTimer != null) return; // already retrying
    _retryTimer = Timer.periodic(_retryEvery, (_) async {
      if (_autoMac != mac) {
        _stopRetrying();
        return;
      }
      if (_connected.contains(mac)) {
        _stopRetrying(); // reconnected already
        return;
      }
      // Skip this tick if an attempt is still running.
      if (_retrying || _pendingConnects.containsKey(mac)) return;
      _retrying = true;
      final ok = await _connectAndStream(mac);
      _retrying = false;
      if (ok) _stopRetrying();
    });
  }

  void _stopRetrying() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  // ---------------------------------------------- remember the last sensor

  @override
  Future<ReStepDevice?> lastConnectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(_savedMacKey);
    if (mac == null) return null;

    // Arm automatic reconnection for this sensor.
    _autoMac = mac;
    return ReStepDevice(
      id: mac,
      name: prefs.getString(_savedNameKey) ?? 'Shimmer3 IMU',
      kind: DeviceKind.shimmerImu,
    );
  }

  @override
  Future<void> forgetDevice(ReStepDevice device) async {
    final mac = device.id.toUpperCase();
    if (_autoMac == mac) {
      _autoMac = null;
      _stopRetrying();
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_savedMacKey) == mac) await _forgetDevice();
  }

  Future<void> _saveDevice(String mac, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedMacKey, mac);
    await prefs.setString(_savedNameKey, name);
  }

  Future<void> _forgetDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedMacKey);
    await prefs.remove(_savedNameKey);
  }

  // -------------------------------------------------------------- events

  void _onEvent(dynamic event) {
    final e = Map<String, dynamic>.from(event as Map);
    final mac = (e['mac'] as String?)?.toUpperCase();
    if (mac == null) return;

    if (e['type'] == 'state') {
      _onState(mac, (e['state'] as String? ?? '').toUpperCase());
    } else if (e['type'] == 'data') {
      _samples.add(ShimmerSample.fromMap(e));

      final battery = (e['battery'] as num?)?.toDouble();

      if (battery != null) _onBattery(mac, battery);
    }
  }

  void _onState(String mac, String state) {
    // Note: "DISCONNECTED" also contains "CONNECTED", so check it first.
    final isDown = state.contains('DISCONNECT') || state.contains('FAIL');
    final isUp = !isDown &&
        (state.contains('READY') ||
            state.contains('CONNECTED') ||
            state.contains('STREAMING'));

    if (isUp) {
      _connected.add(mac);
      final pending = _pendingConnects[mac];
      if (pending != null && !pending.isCompleted) pending.complete(true);
      _updates.add(DeviceUpdate(id: mac, connected: true));
    }

    if (isDown) {
      _connected.remove(mac);
      _resetBattery(mac);
      _updates.add(DeviceUpdate(id: mac, connected: false));

      // A drop while we were not trying to connect means the sensor was
      // switched off or went out of range: start automatic reconnection.
      // (During a connection attempt a short "Disconnected" is normal.)
      if (mac == _autoMac && !_pendingConnects.containsKey(mac)) {
        _startRetrying(mac);
      }
    }
  }

  // ------------------------------------------------------------- battery

  void _resetBattery(String mac) {
    _batteryAverage.remove(mac);
    _batteryCount.remove(mac);
    _batteryLastSent.remove(mac);
    _lastBattery.remove(mac);
  }

  /// The battery reading is noisy (it is estimated from voltage on every
  /// sample), and the first packets after connecting are often 0.
  /// So we ignore invalid values, wait for 2 seconds of valid readings,
  /// average them, and update the UI at most every 30 seconds.
  void _onBattery(String mac, double raw) {
    // Ignore invalid readings (0 right after connecting, or out of range)
    if (raw.isNaN || raw <= 0 || raw > 100) return;

    final count = (_batteryCount[mac] ?? 0) + 1;
    _batteryCount[mac] = count;

    final previous = _batteryAverage[mac];
    final double average;
    if (previous == null) {
      average = raw;
    } else if (count <= _batteryWarmup) {
      // Simple mean of the first readings
      average = previous + (raw - previous) / count;
    } else {
      // Moving average over roughly the last 10 seconds (60 samples/s)
      average = previous + (raw - previous) / 600;
    }
    _batteryAverage[mac] = average;

    // Wait until we have enough readings for a reliable first value
    if (count < _batteryWarmup) return;

    final percent = average.round().clamp(1, 100);
    final now = DateTime.now();
    final lastSent = _batteryLastSent[mac];
    final isFirst = lastSent == null;
    final changed = percent != _lastBattery[mac];
    final waitedEnough = lastSent == null ||
        now.difference(lastSent) >= const Duration(seconds: 30);

    if (isFirst || (changed && waitedEnough)) {
      _lastBattery[mac] = percent;
      _batteryLastSent[mac] = now;
      _updates.add(DeviceUpdate(id: mac, batteryPercent: percent));
    }
  }
}