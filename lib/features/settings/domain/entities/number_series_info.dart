/// Read-only view of a number_series row. fiscal_year_reset is intentionally
/// surfaced as inert (no year component in the format → honouring it would
/// collide numbers), never editable here.
class NumberSeriesInfo {
  final String type;
  final String prefix;
  final int padding;
  final int currentNumber;
  final bool fiscalYearReset;

  const NumberSeriesInfo({
    required this.type,
    required this.prefix,
    required this.padding,
    required this.currentNumber,
    required this.fiscalYearReset,
  });

  /// Next number as it will render (prefix + zero-padded next). Branch code,
  /// where enabled, is prepended at generation time — omitted from this preview.
  String get nextNumberPreview =>
      '$prefix${(currentNumber + 1).toString().padLeft(padding, '0')}';
}
