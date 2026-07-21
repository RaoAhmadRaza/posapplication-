/// The display currency symbol, sourced from the active branch's currency.
/// ponytail: a single module-level value — display-only, set once when the
/// active branch resolves (setDisplayCurrency). Not used in any arithmetic.
String _displayCurrency = 'PKR';

/// Set the money display symbol (from branches.currency). Ignores null/empty.
void setDisplayCurrency(String? currency) {
  if (currency != null && currency.isNotEmpty) _displayCurrency = currency;
}

/// The active display currency symbol, for widgets that render the symbol
/// separately from the number (see AppMoneyText).
String get displayCurrency => _displayCurrency;

/// Formats a money amount WITHOUT the currency symbol: '1,234.50'.
/// Thousands-grouped, sign-safe. `decimals` 0 drops the fractional part.
/// Display only; never used for computation.
String formatAmount(num amount, {int decimals = 2}) {
  final negative = amount < 0;
  final fixed = amount.abs().toStringAsFixed(decimals);
  final dot = fixed.indexOf('.');
  final intPart = dot == -1 ? fixed : fixed.substring(0, dot);
  final decPart = dot == -1 ? '' : fixed.substring(dot + 1);
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  final sign = negative ? '-' : '';
  return decPart.isEmpty ? '$sign$buf' : '$sign$buf.$decPart';
}

/// Formats a money amount as 'PKR 1,234.50' — 2 decimals, thousands-grouped.
/// The symbol follows the active branch's currency (see setDisplayCurrency).
/// Display only; never used for computation. Sign-safe (negatives → 'PKR -50.00').
String formatPkr(num amount) => '$_displayCurrency ${formatAmount(amount)}';
