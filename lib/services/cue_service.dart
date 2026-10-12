import 'package:flutter/services.dart';

import '../models/cue_settings.dart';

/// Sends cues to the Wear OS smartwatch.
/// TODO(hardware): implement with the Wear OS data layer / BLE (cue within 2 s, NFR1).
abstract class CueService {
  Future<void> startCue(CueSettings settings);
  Future<void> stopCue();
  Future<void> testCue(CueSettings settings);
}

/// Prototype: gives a short haptic / system-sound response on the phone so
/// the "Test cue" button feels real. Nothing is sent to a watch.
class MockCueService implements CueService {
  @override
  Future<void> startCue(CueSettings settings) async {
    await _feedback(settings.type);
  }

  @override
  Future<void> stopCue() async {}

  @override
  Future<void> testCue(CueSettings settings) async {
    await _feedback(settings.type);
  }

  Future<void> _feedback(CueType type) async {
    if (type == CueType.vibration) {
      await HapticFeedback.heavyImpact();
    } else {
      await SystemSound.play(SystemSoundType.alert);
    }
  }
}
