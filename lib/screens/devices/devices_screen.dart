import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/device.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Pair devices (scan, connect, retry) and see sensor / watch status.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  bool _scanning = false;
  bool _hasScanned = false;
  List<ReStepDevice> _nearby = [];
  final Set<String> _connecting = {};
  final Set<String> _failed = {};

  Future<void> _scan() async {
    final app = AppScope.read(context);
    setState(() {
      _scanning = true;
      _failed.clear();
    });
    final results = await app.scanNearby();
    if (!mounted) return;
    setState(() {
      _nearby = results;
      _scanning = false;
      _hasScanned = true;
    });
  }

  Future<void> _connect(ReStepDevice device) async {
    final app = AppScope.read(context);
    setState(() {
      _connecting.add(device.id);
      _failed.remove(device.id);
    });
    final ok = await app.connectDevice(device);
    if (!mounted) return;
    setState(() {
      _connecting.remove(device.id);
      if (!ok) _failed.add(device.id);
    });
    if (ok) {
      showAppMessage(
        context,
        '${device.name} connected',
        tone: ChipTone.success,
      );
    }
  }

  bool _isConnected(ReStepDevice device) {
    final app = AppScope.read(context);
    for (final d in app.pairedDevices) {
      if (d.id == device.id && d.connected) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final paired = app.pairedDevices;

    return AppScaffold(
      title: 'Devices',
      children: [
        Text(
          'ReStep uses a Shimmer3 IMU sensor to monitor your movement and '
          'a Wear OS smartwatch to deliver your cue.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
        const SectionHeader(title: 'Paired devices', topPadding: 24),
        if (paired.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.bluetooth_disabled_rounded,
              title: 'No devices paired',
              message: 'Scan below to find your sensor and smartwatch.',
            ),
          )
        else
          for (final device in paired)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PairedDeviceCard(
                device: device,
                busy: _connecting.contains(device.id),
                onReconnect: () => _connect(device),
                onDisconnect: () => app.disconnectDevice(device.id),
              ),
            ),
        const SizedBox(height: 4),
        const InfoBanner(
          message:
              'Devices you have paired before reconnect '
              'automatically.',
        ),
        const SectionHeader(title: 'Find devices'),
        PrimaryButton(
          label: _scanning ? 'Scanning…' : 'Scan for Nearby Devices',
          icon: Icons.bluetooth_searching_rounded,
          loading: _scanning,
          onPressed: _scanning ? null : _scan,
        ),
        const SizedBox(height: 16),
        if (_hasScanned && _nearby.isEmpty)
          const InfoBanner(
            tone: ChipTone.warning,
            message:
                'No devices found. Make sure your sensor and smartwatch '
                'are turned on and close to your phone.',
          ),
        for (final device in _nearby)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _NearbyDeviceCard(
              device: device,
              connected: _isConnected(device),
              connecting: _connecting.contains(device.id),
              failed: _failed.contains(device.id),
              onConnect: () => _connect(device),
            ),
          ),
      ],
    );
  }
}

class _PairedDeviceCard extends StatelessWidget {
  const _PairedDeviceCard({
    required this.device,
    required this.busy,
    required this.onReconnect,
    required this.onDisconnect,
  });

  final ReStepDevice device;
  final bool busy;
  final VoidCallback onReconnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: const BoxDecoration(
                  color: AppColors.skyTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(device.kind.icon, color: AppColors.navy, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      device.kind.label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(
                label: device.connected ? 'Connected' : 'Disconnected',
                tone: device.connected ? ChipTone.success : ChipTone.warning,
              ),
              if (device.connected && device.batteryPercent != null)
                BatteryIndicator(percent: device.batteryPercent!),
            ],
          ),
          const SizedBox(height: 14),
          if (device.connected)
            SecondaryButton(label: 'Disconnect', onPressed: onDisconnect)
          else
            PrimaryButton(
              label: 'Reconnect',
              icon: Icons.sync_rounded,
              loading: busy,
              onPressed: onReconnect,
            ),
        ],
      ),
    );
  }
}

class _NearbyDeviceCard extends StatelessWidget {
  const _NearbyDeviceCard({
    required this.device,
    required this.connected,
    required this.connecting,
    required this.failed,
    required this.onConnect,
  });

  final ReStepDevice device;
  final bool connected;
  final bool connecting;
  final bool failed;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: failed ? AppColors.danger : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(device.kind.icon, color: AppColors.navy, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      device.kind.label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (connected)
                const StatusChip(
                  label: 'Connected',
                  tone: ChipTone.success,
                  icon: Icons.check_rounded,
                ),
            ],
          ),
          if (failed) ...[
            const SizedBox(height: 14),
            InfoBanner(
              tone: ChipTone.danger,
              title: "Couldn't connect",
              message:
                  'Check that ${device.name} is turned on and close '
                  'to your phone, then try again.',
            ),
          ],
          if (!connected) ...[
            const SizedBox(height: 14),
            PrimaryButton(
              label: failed ? 'Retry' : 'Connect',
              icon: failed ? Icons.refresh_rounded : Icons.link_rounded,
              loading: connecting,
              onPressed: onConnect,
            ),
          ],
        ],
      ),
    );
  }
}
