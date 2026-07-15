/// Result of resolve_tax_rate: the applicable rate and where it came from.
/// source: 'product' (per-product override) | 'tax_rule' (tenant default) | 'none'.
class ResolvedTaxRate {
  final double rate;
  final String source;
  final String? code;
  final String? mode;

  const ResolvedTaxRate({
    required this.rate,
    required this.source,
    this.code,
    this.mode,
  });
}
