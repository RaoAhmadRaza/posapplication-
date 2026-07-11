/// Formats a money amount as 'PKR 1,234.50' — 2 decimals, thousands-grouped.
/// Display only; never used for computation. Sign-safe (negatives → 'PKR -50.00').
String formatPkr(num amount) {
  final negative = amount < 0;
  final fixed = amount.abs().toStringAsFixed(2); // "1234.50"
  final dot = fixed.indexOf('.');
  final intPart = fixed.substring(0, dot);
  final decPart = fixed.substring(dot + 1);
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  return 'PKR ${negative ? '-' : ''}$buf.$decPart';
}
