import '../core/utils/formatters.dart';
import 'fog_episode.dart';

/// Summary statistics shown in FoG History and in FoG reports
/// (episode frequency and average duration, as required by the document).
class EpisodeStats {
  const EpisodeStats({
    required this.count,
    required this.average,
    required this.longest,
    required this.perWeek,
  });

  final int count;
  final Duration average;
  final Duration longest;
  final double perWeek;

  factory EpisodeStats.from(List<FogEpisode> episodes, {required int days}) {
    if (episodes.isEmpty) {
      return const EpisodeStats(
        count: 0,
        average: Duration.zero,
        longest: Duration.zero,
        perWeek: 0,
      );
    }
    var totalSeconds = 0;
    var longestSeconds = 0;
    for (final e in episodes) {
      totalSeconds += e.duration.inSeconds;
      if (e.duration.inSeconds > longestSeconds) {
        longestSeconds = e.duration.inSeconds;
      }
    }
    final safeDays = days < 1 ? 1 : days;
    return EpisodeStats(
      count: episodes.length,
      average: Duration(seconds: (totalSeconds / episodes.length).round()),
      longest: Duration(seconds: longestSeconds),
      perWeek: episodes.length / safeDays * 7,
    );
  }

  /// Days spanned by the episodes up to [now] (used when no range is chosen).
  static int spanDays(List<FogEpisode> episodes, DateTime now) {
    if (episodes.isEmpty) return 1;
    var earliest = Fmt.dayOnly(episodes.first.startTime);
    for (final e in episodes) {
      final d = Fmt.dayOnly(e.startTime);
      if (d.isBefore(earliest)) earliest = d;
    }
    final days = Fmt.dayOnly(now).difference(earliest).inDays + 1;
    return days < 1 ? 1 : days;
  }
}
