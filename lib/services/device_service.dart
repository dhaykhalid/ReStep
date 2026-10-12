import '../data/mock/mock_data.dart';
import '../models/device.dart';

/// A live status change reported by a device (connection or battery).
class DeviceUpdate {
  const DeviceUpdate({required this.id, this.connected, this.batteryPercent});

  final String id;
  final bool? connected;
  final int? batteryPercent;
}

/// Access to the Shimmer3 IMU and the Wear OS smartwatch.
/// Real implementation: ShimmerDeviceService (shimmer_device_service.dart).
abstract class DeviceService {
  Future<List<ReStepDevice>> scanNearby();

  /// Returns true when the connection succeeds.
  Future<bool> connect(ReStepDevice device);

  Future<void> disconnect(ReStepDevice device);

  /// Live connection and battery changes reported by the hardware.
  Stream<DeviceUpdate> get updates;
}

class MockDeviceService implements DeviceService {
  // The first attempt to connect to this sensor fails, to demonstrate the
  // "error with a retry option" behaviour.
  final Set<String> _failedOnce = {};

  @override
  Stream<DeviceUpdate> get updates => const Stream.empty();

  @override
  Future<List<ReStepDevice>> scanNearby() async {
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    return MockData.nearbyDevices;
  }

  @override
  Future<bool> connect(ReStepDevice device) async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (device.id == 'shimmer-7f3c' && !_failedOnce.contains(device.id)) {
      _failedOnce.add(device.id);
      return false;
    }
    return true;
  }

  @override
  Future<void> disconnect(ReStepDevice device) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}
