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
  const EpisodeContext({
    this.activities = const [],
    this.note,
    this.otherSituation,
  });

  /// Chosen from [AppConstants.contextOptions].
  final List<String> activities;

  /// Free-text note from older versions of the app, which no longer ask
  /// for one. Kept so it is still shown and not lost when editing.
  final String? note;

  /// What the patient typed after choosing "Other"; null when not chosen.
  final String? otherSituation;

  bool get hasOther => (otherSituation ?? '').trim().isNotEmpty;

  /// [activities] followed by "Other: ..." when there is a custom situation.
  List<String> get situations => [
        ...activities,
        if (hasOther) 'Other: ${otherSituation!.trim()}',
      ];

  bool get isEmpty =>
      activities.isEmpty && !hasOther && (note ?? '').trim().isEmpty;
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
