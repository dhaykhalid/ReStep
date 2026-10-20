import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, Timestamp;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'models/episode_stats.dart';
import 'models/fog_episode.dart';
import 'services/report_service.dart';

/// One episode in the report (FoG_Episode + Cue in the class diagram).
class FogReportRow {
  FogReportRow({
    required this.start,
    required this.durationSeconds,
    this.cue = '',
    this.recording = 'Automatic',
    this.activities = const [],
    this.note = '',
  });

  final DateTime start; // episode_date + episode_time
  final double durationSeconds; // duration
  final String cue; // cue_name, empty if no cue was delivered
  final String recording; // recording_method: Automatic, Manual or Quick Assistance
  final List<String> activities; // context: activities
  final String note; // episode_notes
}

const _navy = PdfColor.fromInt(0xFF083E80);
const _cyan = PdfColor.fromInt(0xFF4FC3E8);
const _ink = PdfColor.fromInt(0xFF102B4E);
const _text = PdfColor.fromInt(0xFF33475F);
const _mute = PdfColor.fromInt(0xFF6B7C93);
const _hair = PdfColor.fromInt(0xFFE6ECF3);
const _soft = PdfColor.fromInt(0xFFF7F9FC);

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String _two(int n) => n.toString().padLeft(2, '0');
String _d(DateTime d) => '${_two(d.day)} ${_months[d.month - 1]} ${d.year}';
String _t(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
String _dayTitle(DateTime d) => '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

int _age(DateTime birth) {
  final now = DateTime.now();
  var a = now.year - birth.year;
  if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) a--;
  return a;
}

String _context(FogReportRow e) {
  final parts = <String>[
    if (e.activities.isNotEmpty) e.activities.join(', '),
    if (e.note.trim().isNotEmpty) e.note.trim(),
  ];
  return parts.isEmpty ? '-' : parts.join(' - ');
}

/// Builds the ReStep FoG report (day-by-day layout) and opens the share sheet.
Future<void> shareFogReportFromRows({
  required String patientName,
  DateTime? birthDate,
  String? email,
  required String periodLabel,
  required int days,
  required List<FogReportRow> rows,
}) async {
  final sorted = [...rows]..sort((a, b) => a.start.compareTo(b.start));
  final total = sorted.length;
  final avg = total == 0 ? 0.0 : sorted.fold<double>(0, (s, e) => s + e.durationSeconds) / total;
  final longest = total == 0 ? 0.0 : sorted.map((e) => e.durationSeconds).reduce((a, b) => a > b ? a : b);
  final perDay = days <= 0 ? 0.0 : total / days * 7; // per week

  final logo = pw.MemoryImage(base64Decode(_logoBase64));

  pw.TextStyle ts(double size, {PdfColor color = _text, bool bold = false}) =>
      pw.TextStyle(fontSize: size, color: color, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);

  pw.Widget field(String label, String value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label.toUpperCase(), style: ts(7.5, color: _mute)),
      pw.SizedBox(height: 2),
      pw.Text(value, style: ts(10.5, color: _ink, bold: true)),
    ],
  );

  pw.Widget kpi(String value, String label) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12),
      decoration: pw.BoxDecoration(
        color: _soft,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _hair, width: 0.6),
      ),
      child: pw.Column(children: [
        pw.Text(value, style: ts(20, color: _navy, bold: true)),
        pw.SizedBox(height: 2),
        pw.Text(label, style: ts(8, color: _mute)),
      ]),
    ),
  );

  pw.Widget section(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 22, bottom: 8),
    child: pw.Row(children: [
      pw.Container(width: 4, height: 16, color: _cyan),
      pw.SizedBox(width: 8),
      pw.Text(title, style: ts(13, color: _navy, bold: true)),
    ]),
  );

  pw.Widget cell(String s, {bool bold = false, bool header = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6),
    child: pw.Text(s, style: header ? ts(8, color: _navy, bold: true) : ts(8.8, color: bold ? _ink : _text, bold: bold)),
  );

  pw.Widget dayHeader(DateTime d, List<FogReportRow> items) {
    final avgDay = items.fold<double>(0, (s, e) => s + e.durationSeconds) / items.length;
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: const pw.BoxDecoration(
        color: _soft,
        border: pw.Border(left: pw.BorderSide(color: _cyan, width: 3)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(_dayTitle(d), style: ts(11, color: _navy, bold: true)),
          pw.Text('${items.length} ${items.length == 1 ? 'episode' : 'episodes'}  |  avg ${avgDay.toStringAsFixed(1)} s', style: ts(8.5, color: _mute)),
        ],
      ),
    );
  }

  pw.Widget dayTable(List<FogReportRow> items) {
    const heads = ['Time', 'Duration', 'Cue used', 'Recording', 'Context and notes'];
    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(0.9),
        1: pw.FlexColumnWidth(1.1),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(1.3),
        4: pw.FlexColumnWidth(4),
      },
      border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _hair, width: 0.5), bottom: pw.BorderSide(color: _hair, width: 0.5)),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 1))),
          children: [for (final h in heads) cell(h, header: true)],
        ),
        for (final e in items)
          pw.TableRow(children: [
            cell(_t(e.start), bold: true),
            cell('${e.durationSeconds.toStringAsFixed(1)} s'),
            cell(e.cue.isEmpty ? '-' : e.cue),
            cell(e.recording, bold: e.recording == 'Manual'),
            cell(_context(e)),
          ]),
      ],
    );
  }

  // group the episodes by day
  final byDay = <DateTime, List<FogReportRow>>{};
  for (final e in sorted) {
    byDay.putIfAbsent(DateTime(e.start.year, e.start.month, e.start.day), () => []).add(e);
  }

  final doc = pw.Document(title: 'ReStep FoG Report', author: 'ReStep');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(57, 45, 57, 57),
      footer: (c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.SizedBox(),
          pw.Text('Page ${c.pageNumber} of ${c.pagesCount}', style: ts(7.5, color: _mute)),
        ],
      ),
      build: (c) => [
        // header
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _cyan, width: 2))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(logo, width: 112),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('FoG Report', style: ts(22, color: _navy, bold: true)),
                pw.Text('Day-by-day record', style: ts(9.5, color: _mute)),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 12),

        // patient
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(flex: 38, child: field('Patient', patientName)),
          pw.Expanded(
            flex: 31,
            child: field('Date of birth', birthDate == null ? '-' : '${_d(birthDate)} (${_age(birthDate)} y)'),
          ),
          pw.Expanded(flex: 31, child: field('Report period', periodLabel)),
        ]),
        pw.SizedBox(height: 10),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(flex: 38, child: field('Email', email ?? '-')),
          pw.Expanded(flex: 31, child: field('Generated', _d(DateTime.now()))),
          pw.Expanded(flex: 31, child: pw.SizedBox()),
        ]),
        pw.SizedBox(height: 14),

        // summary
        pw.Row(children: [
          kpi('$total', 'Episodes'),
          pw.SizedBox(width: 8),
          kpi('${perDay.toStringAsFixed(1)}/week', 'Frequency'),
          pw.SizedBox(width: 8),
          kpi('${avg.toStringAsFixed(1)} s', 'Average duration'),
          pw.SizedBox(width: 8),
          kpi('${longest.toStringAsFixed(1)} s', 'Longest episode'),
        ]),

        section('Day by day'),
        if (total == 0)
          pw.Text('No FoG episodes were recorded in this period.', style: ts(10, color: _ink))
        else
          for (final entry in byDay.entries) ...[
            dayHeader(entry.key, entry.value),
            dayTable(entry.value),
          ],
      ],
    ),
  );

  final now = DateTime.now();
  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: 'ReStep_FoG_Report_${now.year}${_two(now.month)}${_two(now.day)}.pdf',
  );
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Called by ReportService.share: turns the app's ReportResult into the report.
Future<void> shareFogReportPdf(ReportResult r) async {
  final rows = <FogReportRow>[
    for (final e in r.episodes)
      FogReportRow(
        start: e.startTime,
        durationSeconds: e.duration.inMilliseconds / 1000.0,
        cue: e.cueDelivered == null ? '' : _cap(e.cueDelivered!.name),
        recording: e.source == EpisodeSource.manual
            ? 'Manual'
            : e.source == EpisodeSource.quickAssistance
                ? 'Quick Assistance'
                : 'Automatic',
        activities: e.context?.activities ?? const [],
        note: e.context?.note ?? '',
      ),
  ];

  // patient email and birth date (from the signed-in account and Firestore)
  final email = FirebaseAuth.instance.currentUser?.email;
  DateTime? birth;
  if (email != null) {
    try {
      final snap = await FirebaseFirestore.instance.collection('patients').doc(email).get();
      final v = snap.data()?['birth_date'];
      if (v is Timestamp) {
        birth = v.toDate();
      } else if (v is String) {
        birth = DateTime.tryParse(v);
      }
    } catch (_) {
      // the report still works without it
    }
  }

  return shareFogReportFromRows(
    patientName: r.patientName,
    birthDate: birth,
    email: email,
    periodLabel: r.periodLabel.replaceAll('\u2013', '-'),
    days: r.range?.days ?? EpisodeStats.spanDays(r.episodes, r.generatedAt),
    rows: rows,
  );
}
// ReStep logo (small PNG, embedded so no assets or pubspec changes are needed)
const _logoBase64 =
    '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';