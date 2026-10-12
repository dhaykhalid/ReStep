import 'package:flutter/material.dart';

import 'cue_settings.dart';
export 'cue_settings.dart';

/// How an episode entered the FoG history.
enum EpisodeSource { detected, manual, quickAssistance }

extension EpisodeSourceX on EpisodeSource {
  String get label {
    switch (this) {
      case EpisodeSource.detected:
        return 'Detected';
      case EpisodeSource.manual:
        return 'Added manually';
      case EpisodeSource.quickAssistance:
        return 'Quick Assistance';
    }
  }

  IconData get icon {
    switch (this) {
      case EpisodeSource.detected:
        return Icons.sensors;
      case EpisodeSource.manual:
        return Icons.edit_note_rounded;
      case EpisodeSource.quickAssistance:
        return Icons.touch_app_rounded;
    }
  }
}

/// Optional Patient-Reported Context attached to an episode.
class EpisodeContext {
  const EpisodeContext({this.activities = const [], this.note});

  final List<String> activities;
  final String? note;

  bool get isEmpty => activities.isEmpty && (note ?? '').trim().isEmpty;
}

class FogEpisode {
  const FogEpisode({
    required this.id,
    required this.startTime,
    required this.duration,
    required this.source,
    this.cueDelivered,
    this.context,
    this.alertContactName,
    this.alertSentAt,
    this.alertCancelled = false,
  });

  final String id;
  final DateTime startTime;
  final Duration duration;
  final EpisodeSource source;

  /// Null when no cue was delivered (for example a manually added episode).
  final CueType? cueDelivered;
  final EpisodeContext? context;

  /// Emergency escalation record (an alert sent to the emergency contact).
  final String? alertContactName;
  final DateTime? alertSentAt;
  final bool alertCancelled;

  bool get hasContext => context != null && !context!.isEmpty;
  bool get alertSent => alertSentAt != null;

  FogEpisode copyWith({
    EpisodeContext? context,
    bool? alertCancelled,
  }) {
    return FogEpisode(
      id: id,
      startTime: startTime,
      duration: duration,
      source: source,
      cueDelivered: cueDelivered,
      context: context ?? this.context,
      alertContactName: alertContactName,
      alertSentAt: alertSentAt,
      alertCancelled: alertCancelled ?? this.alertCancelled,
    );
  }
}
