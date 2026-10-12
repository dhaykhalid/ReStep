import 'package:flutter/material.dart';

enum DeviceKind { shimmerImu, smartwatch }

extension DeviceKindX on DeviceKind {
  String get label {
    switch (this) {
      case DeviceKind.shimmerImu:
        return 'Shimmer3 IMU sensor';
      case DeviceKind.smartwatch:
        return 'Wear OS smartwatch';
    }
  }

  IconData get icon {
    switch (this) {
      case DeviceKind.shimmerImu:
        return Icons.sensors;
      case DeviceKind.smartwatch:
        return Icons.watch_rounded;
    }
  }
}

class ReStepDevice {
  const ReStepDevice({
    required this.id,
    required this.name,
    required this.kind,
    this.connected = false,
    this.batteryPercent,
  });

  final String id;
  final String name;
  final DeviceKind kind;
  final bool connected;
  final int? batteryPercent;

  ReStepDevice copyWith({bool? connected, int? batteryPercent}) {
    return ReStepDevice(
      id: id,
      name: name,
      kind: kind,
      connected: connected ?? this.connected,
      batteryPercent: batteryPercent ?? this.batteryPercent,
    );
  }
}
