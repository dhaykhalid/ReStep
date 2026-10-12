import '../../models/fog_episode.dart';
import '../../models/period.dart';
import '../../widgets/mini_bar_chart.dart';
import 'formatters.dart';

/// Builds the data for the "episodes over time" bar chart.
class EpisodeAnalytics {
  EpisodeAnalytics._();

  /// Ranges of up to 10 days are shown per day, longer ranges per week
  /// (up to the 8 most recent weeks).
  static List<BarDatum> chartData(List<FogEpisode> episodes, DateRange range) {
    final days = range.days;
    if (days <= 10) {
      return [
        for (var i = 0; i < days; i++) _daily(episodes, Fmt.addDays(range.start, i)),
      ];
    }
    var buckets = (days / 7).ceil();
    if (buckets > 8) buckets = 8;
    final result = <BarDatum>[];
    for (var i = buckets - 1; i >= 0; i--) {
      final bucketEnd = Fmt.addDays(range.end, -7 * i);
      final bucketStart = Fmt.addDays(bucketEnd, -6);
      final count = episodes.where((e) {
        final d = Fmt.dayOnly(e.startTime);
        return !d.isBefore(bucketStart) && !d.isAfter(bucketEnd);
      }).length;
      result.add(BarDatum(Fmt.dayMonth(bucketStart), count));
    }
    return result;
  }

  /// "Per day" or "Per week", matching [chartData].
  static String chartUnit(DateRange range) =>
      range.days <= 10 ? 'Episodes per day' : 'Episodes per week';

  static BarDatum _daily(List<FogEpisode> episodes, DateTime day) {
    final count =
        episodes.where((e) => Fmt.sameDay(e.startTime, day)).length;
    return BarDatum(Fmt.weekdayShort(day), count);
  }
}
