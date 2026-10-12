import '../core/utils/formatters.dart';

/// Time-period choices used by FoG History and FoG Reports.
enum PeriodOption { last7Days, last30Days, allTime, custom }

extension PeriodOptionX on PeriodOption {
  String get label {
    switch (this) {
      case PeriodOption.last7Days:
        return 'Last 7 days';
      case PeriodOption.last30Days:
        return 'Last 30 days';
      case PeriodOption.allTime:
        return 'All recorded episodes';
      case PeriodOption.custom:
        return 'Choose dates';
    }
  }

  String get shortLabel {
    switch (this) {
      case PeriodOption.last7Days:
        return '7 days';
      case PeriodOption.last30Days:
        return '30 days';
      case PeriodOption.allTime:
        return 'All';
      case PeriodOption.custom:
        return 'Custom';
    }
  }
}

/// An inclusive range of calendar days.
class DateRange {
  DateRange(DateTime start, DateTime end)
      : start = Fmt.dayOnly(start),
        end = Fmt.dayOnly(end);

  final DateTime start;
  final DateTime end;

  int get days => end.difference(start).inDays + 1;

  bool contains(DateTime t) {
    final day = Fmt.dayOnly(t);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  String get label => '${Fmt.date(start)} – ${Fmt.date(end)}';
}
