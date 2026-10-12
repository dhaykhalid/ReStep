import 'dart:async';

import 'package:flutter/services.dart';

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
class ShimmerDeviceService implements DeviceService {
  ShimmerDeviceService() {
    _events.receiveBroadcastStream().listen(_onEvent, onError: (_) {});
  }

  static const _method = MethodChannel('com.restep/shimmer');
  static const _events = EventChannel('com.restep/shimmer_stream');

  final _updates = StreamController<DeviceUpdate>.broadcast();
  final _samples = StreamController<ShimmerSample>.broadcast();
  final Map<String, Completer<bool>> _pendingConnects = {};
  final Map<String, int> _lastBattery = {};
  final Map<String, double> _batteryAverage = {};
  final Map<String, DateTime> _batteryLastSent = {};

  @override
  Stream<DeviceUpdate> get updates => _updates.stream;

  /// Live IMU readings (used later for the FoG detection model).
  Stream<ShimmerSample> get samples => _samples.stream;

  /// Lists the Shimmer sensors already paired in the phone's Bluetooth settings.
  @override
  Future<List<ReStepDevice>> scanNearby() async {
    final list = await _method.invokeListMethod<Map>('getPairedDevices') ?? [];
    return [
      for (final d in list)
        ReStepDevice(
          id: (d['mac'] as String).toUpperCase(),
          name: d['name'] as String? ?? 'Shimmer3 IMU',
          kind: DeviceKind.shimmerImu,
        ),
    ];
  }

  /// Connects, waits until the sensor is ready, then starts streaming.
  @override
  Future<bool> connect(ReStepDevice device) async {
    // The smartwatch is not implemented yet.
    if (device.kind != DeviceKind.shimmerImu) return false;

    final mac = device.id.toUpperCase();
    final completer = Completer<bool>();
    _pendingConnects[mac] = completer;

    try {
      await _method.invokeMethod('connect', {'mac': mac});
    } on PlatformException {
      _pendingConnects.remove(mac);
      return false;
    }

    final ok = await completer.future
        .timeout(const Duration(seconds: 20), onTimeout: () => false);
    _pendingConnects.remove(mac);
    if (!ok) return false;

    try {
      await _method.invokeMethod('startStreaming', {'mac': mac});
    } on PlatformException {
      return false;
    }
    return true;
  }

  @override
  Future<void> disconnect(ReStepDevice device) async {
    final mac = device.id.toUpperCase();
    try {
      await _method.invokeMethod('stopStreaming', {'mac': mac});
    } on PlatformException {
      // Not streaming, ignore.
    }
    try {
      await _method.invokeMethod('disconnect', {'mac': mac});
    } on PlatformException {
      // Already disconnected, ignore.
    }
  }

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

  /// The battery reading is noisy (it is estimated from voltage on every
  /// sample), so we average it and update the UI at most every 30 seconds.
  void _onBattery(String mac, double raw) {
    // Moving average over roughly the last 10 seconds (60 samples/s)
    final previous = _batteryAverage[mac];
    final average = previous == null ? raw : previous + (raw - previous) / 600;
    _batteryAverage[mac] = average;

    final percent = average.round().clamp(0, 100);
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

  void _onState(String mac, String state) {
    // Note: "DISCONNECTED" also contains "CONNECTED", so check it first.
    final isDown = state.contains('DISCONNECT') || state.contains('FAIL');
    final isUp = !isDown &&
        (state.contains('READY') ||
            state.contains('CONNECTED') ||
            state.contains('STREAMING'));

    final pending = _pendingConnects[mac];
    if (pending != null && !pending.isCompleted) {
      if (isUp) pending.complete(true);
      if (isDown) pending.complete(false);
    }

    if (isUp) _updates.add(DeviceUpdate(id: mac, connected: true));
    if (isDown) _updates.add(DeviceUpdate(id: mac, connected: false));
  }
}
