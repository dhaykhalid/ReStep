import '../core/utils/formatters.dart';
import '../fog_report.dart';
import '../models/episode_stats.dart';
import '../models/fog_episode.dart';
import '../models/patient.dart';
import '../models/period.dart';

/// The content of a generated FoG report (summary measures + episode log).
class ReportResult {
  const ReportResult({
    required this.fileName,
    required this.generatedAt,
    required this.patientName,
    required this.range,
    required this.episodes,
    required this.stats,
  });

  final String fileName;
  final DateTime generatedAt;
  final String patientName;

  /// Null means "all recorded episodes".
  final DateRange? range;
  final List<FogEpisode> episodes;
  final EpisodeStats stats;

  String get periodLabel => range?.label ?? 'All recorded episodes';
}

/// Creates and shares the PDF FoG report.
/// TODO(backend): generate a real PDF (e.g. with the `pdf` package) and share it
/// with the system share sheet (e.g. `share_plus`).
abstract class ReportService {
  Future<ReportResult> generate({
    required Patient patient,
    required DateRange? range,
    required List<FogEpisode> episodes,
    required DateTime now,
  });

  Future<void> share(ReportResult report);
}

class MockReportService implements ReportService {
  @override
  Future<ReportResult> generate({
    required Patient patient,
    required DateRange? range,
    required List<FogEpisode> episodes,
    required DateTime now,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final sorted = [...episodes]
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    final days = range?.days ?? EpisodeStats.spanDays(sorted, now);
    return ReportResult(
      fileName: 'ReStep_FoG_Report_${Fmt.isoDate(now)}.pdf',
      generatedAt: now,
      patientName: patient.fullName,
      range: range,
      episodes: sorted,
      stats: EpisodeStats.from(sorted, days: days),
    );
  }

  @override
  Future<void> share(ReportResult report) async {
    await shareFogReportPdf(report);
  }
}

