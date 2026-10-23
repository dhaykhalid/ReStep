import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/device.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

/// Devices screen, similar to the phone's Bluetooth settings:
/// - "My devices": sensors connected before in ReStep. They are saved and
///   shown every time, so no scan is needed to connect again.
/// - "Other devices": scan for sensors that are not saved yet. After a
///   sensor connects, it moves to "My devices".
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

  Future<void> _remove(ReStepDevice device) async {
    final app = AppScope.read(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove ${device.name}?',
      message: 'This device will be removed from My devices. '
          'You can add it again later by scanning.',
      confirmLabel: 'Remove',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;

    await app.removeDevice(device.id);
    if (!mounted) return;
    setState(() => _failed.remove(device.id));
    showAppMessage(context, '${device.name} removed');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final saved = app.pairedDevices;

    // Scan results that are not already in "My devices".
    final savedIds = {for (final d in saved) d.id};
    final others = _nearby.where((d) => !savedIds.contains(d.id)).toList();

    return AppScaffold(
      title: 'Devices',
      children: [
        Text(
          'ReStep uses a Shimmer3 IMU sensor to monitor your movement and '
              'a Wear OS smartwatch to deliver your cue.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),

        // ------------------------------------------------ My devices
        const SectionHeader(title: 'My devices', topPadding: 24),
        if (saved.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.bluetooth_disabled_rounded,
              title: 'No saved devices',
              message: 'Scan below to find your sensor. Devices you connect '
                  'are saved here.',
            ),
          )
        else
          for (final device in saved)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SavedDeviceCard(
                device: device,
                connecting: _connecting.contains(device.id),
                failed: _failed.contains(device.id),
                onConnect: () => _connect(device),
                onDisconnect: () => app.disconnectDevice(device.id),
                onRemove: () => _remove(device),
              ),
            ),

        // --------------------------------------------- Other devices
        const SectionHeader(title: 'Other devices'),
        PrimaryButton(
          label: _scanning ? 'Scanning…' : 'Scan for New Devices',
          icon: Icons.bluetooth_searching_rounded,
          loading: _scanning,
          onPressed: _scanning ? null : _scan,
        ),
        const SizedBox(height: 16),
        if (_hasScanned && others.isEmpty)
          InfoBanner(
            tone: ChipTone.warning,
            message: _nearby.isEmpty
                ? 'No devices found. Pair the sensor in your phone\'s '
                'Bluetooth settings first (PIN 1234), make sure it is on, '
                'then scan again.'
                : 'No new devices found. All nearby sensors are already in '
                'My devices.',
          ),
        for (final device in others)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _NewDeviceCard(
              device: device,
              connecting: _connecting.contains(device.id),
              failed: _failed.contains(device.id),
              onConnect: () => _connect(device),
            ),
          ),
      ],
    );
  }
}

/// A saved device: status, Connect / Disconnect and Remove device.
class _SavedDeviceCard extends StatelessWidget {
  const _SavedDeviceCard({
    required this.device,
    required this.connecting,
    required this.failed,
    required this.onConnect,
    required this.onDisconnect,
    required this.onRemove,
  });

  final ReStepDevice device;
  final bool connecting;
  final bool failed;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: failed ? AppColors.danger : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeviceHeader(device: device),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(
                label: device.connected ? 'Connected' : 'Not connected',
                tone: device.connected ? ChipTone.success : ChipTone.neutral,
              ),
              if (device.connected && device.batteryPercent != null)
                BatteryIndicator(percent: device.batteryPercent!),
            ],
          ),
          if (failed) ...[
            const SizedBox(height: 14),
            _ConnectError(name: device.name),
          ],
          const SizedBox(height: 14),
          if (device.connected)
            SecondaryButton(label: 'Disconnect', onPressed: onDisconnect)
          else
            PrimaryButton(
              label: failed ? 'Retry' : 'Connect',
              icon: failed ? Icons.refresh_rounded : Icons.link_rounded,
              loading: connecting,
              onPressed: onConnect,
            ),
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: connecting ? null : onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Remove device'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// A device found by scanning that is not saved yet.
class _NewDeviceCard extends StatelessWidget {
  const _NewDeviceCard({
    required this.device,
    required this.connecting,
    required this.failed,
    required this.onConnect,
  });

  final ReStepDevice device;
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
          _DeviceHeader(device: device),
          if (failed) ...[
            const SizedBox(height: 14),
            _ConnectError(name: device.name),
          ],
          const SizedBox(height: 14),
          PrimaryButton(
            label: failed ? 'Retry' : 'Connect',
            icon: failed ? Icons.refresh_rounded : Icons.link_rounded,
            loading: connecting,
            onPressed: onConnect,
          ),
        ],
      ),
    );
  }
}

/// Icon, name and type of a device.
class _DeviceHeader extends StatelessWidget {
  const _DeviceHeader({required this.device});

  final ReStepDevice device;

  @override
  Widget build(BuildContext context) {
    return Row(
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
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectError extends StatelessWidget {
  const _ConnectError({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return InfoBanner(
      tone: ChipTone.danger,
      title: "Couldn't connect",
      message: 'Check that $name is turned on and close to your phone, '
          'then try again.',
    );
  }
}