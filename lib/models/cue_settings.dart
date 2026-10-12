import 'package:flutter/material.dart';

/// ReStep delivers vibration and auditory cues only (visual cueing is out of scope).
enum CueType { vibration, auditory }

extension CueTypeX on CueType {
  String get label {
    switch (this) {
      case CueType.vibration:
        return 'Vibration';
      case CueType.auditory:
        return 'Auditory';
    }
  }

  IconData get icon {
    switch (this) {
      case CueType.vibration:
        return Icons.vibration;
      case CueType.auditory:
        return Icons.volume_up_rounded;
    }
  }
}

/// How the cue is played (from the questionnaire: several short cues or one long cue).
enum CuePattern { shortConsecutive, longContinuous }

extension CuePatternX on CuePattern {
  String get label {
    switch (this) {
      case CuePattern.shortConsecutive:
        return 'Several short cues';
      case CuePattern.longContinuous:
        return 'One long, continuous cue';
    }
  }
}

class CueSettings {
  const CueSettings({
    required this.type,
    required this.pattern,
    required this.durationSeconds,
  });

  static const CueSettings defaults = CueSettings(
    type: CueType.vibration,
    pattern: CuePattern.shortConsecutive,
    durationSeconds: 20,
  );

  final CueType type;
  final CuePattern pattern;
  final int durationSeconds;

  String get summary => '${type.label} · ${pattern.label.toLowerCase()} · '
      '$durationSeconds s';

  CueSettings copyWith({
    CueType? type,
    CuePattern? pattern,
    int? durationSeconds,
  }) {
    return CueSettings(
      type: type ?? this.type,
      pattern: pattern ?? this.pattern,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CueSettings &&
      other.type == type &&
      other.pattern == pattern &&
      other.durationSeconds == durationSeconds;

  @override
  int get hashCode => Object.hash(type, pattern, durationSeconds);
}
