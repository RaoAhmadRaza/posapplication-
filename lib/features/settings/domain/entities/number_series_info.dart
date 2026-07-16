/// Read-only view of a number_series row.
class NumberSeriesInfo {
  final String type;
  final String prefix;
  final int padding;
  final int currentNumber;

  const NumberSeriesInfo({
    required this.type,
    required this.prefix,
    required this.padding,
    required this.currentNumber,
  });

  /// Next number as it will render (prefix + zero-padded next). Branch code,
  /// where enabled, is prepended at generation time — omitted from this preview.
  String get nextNumberPreview =>
      '$prefix${(currentNumber + 1).toString().padLeft(padding, '0')}';
}
