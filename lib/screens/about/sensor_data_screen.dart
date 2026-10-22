import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../services/shimmer_device_service.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Development tool (this phase only): shows live Shimmer3 readings and
/// exports a recording as CSV. Delete this file and its button in
/// demo_tools_screen.dart when it is no longer needed.
class SensorDataScreen extends StatefulWidget {
  const SensorDataScreen({super.key});

  @override
  State<SensorDataScreen> createState() => _SensorDataScreenState();
}

class _SensorDataScreenState extends State<SensorDataScreen> {
  ShimmerDeviceService? _service;
  StreamSubscription<ShimmerSample>? _sub;
  Timer? _uiTimer;

  ShimmerSample? _latest;
  int _samplesThisSecond = 0;
  int _rateHz = 0;
  DateTime _rateWindowStart = DateTime.now();

  bool _recording = false;
  final List<ShimmerSample> _recorded = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;

    final deviceService = AppScope.read(context).deviceService;
    if (deviceService is! ShimmerDeviceService) return;
    _service = deviceService;

    _sub = deviceService.samples.listen(_onSample);

    // Refresh the numbers on screen 5 times per second (not 60).
    _uiTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onSample(ShimmerSample sample) {
    _latest = sample;
    if (_recording) _recorded.add(sample);

    // Count how many samples arrive per second.
    _samplesThisSecond++;
    final now = DateTime.now();
    if (now.difference(_rateWindowStart) >= const Duration(seconds: 1)) {
      _rateHz = _samplesThisSecond;
      _samplesThisSecond = 0;
      _rateWindowStart = now;
    }
  }

  void _startRecording() {
    setState(() {
      _recorded.clear();
      _recording = true;
    });
  }

  Future<void> _stopAndExport() async {
    setState(() => _recording = false);
    if (_recorded.isEmpty) {
      _showMessage('No data recorded. Is the sensor connected?');
      return;
    }

    final buffer = StringBuffer(
      'shimmer_timestamp_ms,mac,accel_x,accel_y,accel_z,gyro_x,gyro_y,gyro_z\n',
    );
    for (final s in _recorded) {
      final values = [s.timestampMs, s.mac, s.ax, s.ay, s.az, s.gx, s.gy, s.gz];
      buffer.writeln(values.map((v) => v ?? '').join(','));
    }

    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File('${dir.path}/shimmer_$stamp.csv');
    await file.writeAsString(buffer.toString());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Shimmer recording (${_recorded.length} samples)',
      ),
    );
  }

  void _showMessage(String text) {
    if (!mounted) return;
    showAppMessage(context, text, tone: ChipTone.warning);
  }

  String _fmt(double? v) => v == null ? '--' : v.toStringAsFixed(2);

  @override
  void dispose() {
    _sub?.cancel();
    _uiTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sensor = app.sensor;
    final connected = sensor != null && sensor.connected;
    final s = _latest;

    return AppScaffold(
      title: 'Live sensor data',
      children: [
        if (_service == null)
          const InfoBanner(
            tone: ChipTone.warning,
            message: 'The real sensor service is not active.',
          )
        else if (!connected)
          const InfoBanner(
            tone: ChipTone.warning,
            message:
                'No sensor connected. Connect one from the Devices screen.',
          ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('Sensor', sensor?.name ?? '--'),
              _row('Sampling rate', '$_rateHz Hz'),
              const Divider(height: 24),
              const Text('Accelerometer (m/s²)', style: _headerStyle),
              _row('X', _fmt(s?.ax)),
              _row('Y', _fmt(s?.ay)),
              _row('Z', _fmt(s?.az)),
              const Divider(height: 24),
              const Text('Gyroscope (deg/s)', style: _headerStyle),
              _row('X', _fmt(s?.gx)),
              _row('Y', _fmt(s?.gy)),
              _row('Z', _fmt(s?.gz)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _recording
              ? 'Recording… ${_recorded.length} samples'
              : 'Not recording',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _recording ? Colors.red : AppColors.muted,
          ),
        ),
        const SizedBox(height: 12),
        if (_recording)
          PrimaryButton(
            label: 'Stop & Export CSV',
            icon: Icons.ios_share_rounded,
            onPressed: _stopAndExport,
          )
        else
          PrimaryButton(
            label: 'Start Recording',
            icon: Icons.fiber_manual_record_rounded,
            onPressed: connected ? _startRecording : null,
          ),
      ],
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppColors.navy,
  );

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, color: AppColors.muted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
