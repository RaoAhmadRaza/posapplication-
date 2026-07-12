import '../../domain/entities/fiscal_period.dart';

class FiscalPeriodModel {
  static FiscalPeriod fromJson(Map<String, dynamic> json) {
    return FiscalPeriod(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      startDate: _date(json['start_date']),
      endDate: _date(json['end_date']),
      status: _status(json['status'] as String?),
      closedAt: json['closed_at'] == null
          ? null
          : DateTime.tryParse(json['closed_at'].toString())?.toLocal(),
    );
  }

  static DateTime _date(Object? v) =>
      DateTime.tryParse(v.toString())?.toLocal() ?? DateTime.now();

  static FiscalPeriodStatus _status(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'CLOSED':
        return FiscalPeriodStatus.closed;
      case 'LOCKED':
        return FiscalPeriodStatus.locked;
      case 'OPEN':
      default:
        return FiscalPeriodStatus.open;
    }
  }
}
