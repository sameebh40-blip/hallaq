class CurrencyFormatters {
  static String bd(num value, {int maxDecimals = 1}) {
    final v = value.toDouble();
    final decimals = (v % 1.0) == 0 ? 0 : maxDecimals;
    return 'BD ${v.toStringAsFixed(decimals)}';
  }
}

