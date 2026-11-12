class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formats paise integer to standard Indian Rupee string (e.g. 10050 -> "₹100.50", 10000000 -> "₹1,00,000.00")
  static String formatPaise(int paise, {bool includeSymbol = true}) {
    final isNegative = paise < 0;
    final absPaise = paise.abs();
    final rupees = absPaise ~/ 100;
    final remainderPaise = absPaise % 100;

    final rupeesFormatted = _formatIndianGrouping(rupees);
    final paiseStr = remainderPaise.toString().padLeft(2, '0');
    final sign = isNegative ? '-' : '';
    final symbol = includeSymbol ? '₹' : '';

    return '$sign$symbol$rupeesFormatted.$paiseStr';
  }

  /// Parses user-entered rupee decimal string (e.g. "500.50", "500", "0.75") into exact integer paise
  /// NEVER uses double or float parsing to avoid IEEE 754 precision issues.
  static int? parseToPaise(String input) {
    final trimmed = input.trim().replaceAll(',', '').replaceAll('₹', '').replaceAll(' ', '');
    if (trimmed.isEmpty) return null;

    final isNegative = trimmed.startsWith('-');
    final clean = isNegative ? trimmed.substring(1) : trimmed;

    final parts = clean.split('.');
    if (parts.length > 2) return null; // Invalid multiple decimal dots

    final rupeesPart = parts[0].isEmpty ? '0' : parts[0];
    if (!RegExp(r'^\d+$').hasMatch(rupeesPart)) return null;

    int rupees;
    try {
      rupees = int.parse(rupeesPart);
    } catch (_) {
      return null;
    }

    int paise = 0;
    if (parts.length == 2) {
      var decimalPart = parts[1];
      if (decimalPart.length > 2) {
        decimalPart = decimalPart.substring(0, 2); // Truncate beyond 2 decimal places
      }
      if (decimalPart.isNotEmpty && !RegExp(r'^\d+$').hasMatch(decimalPart)) {
        return null;
      }
      decimalPart = decimalPart.padRight(2, '0');
      paise = int.parse(decimalPart);
    }

    final totalPaise = (rupees * 100) + paise;
    return isNegative ? -totalPaise : totalPaise;
  }

  /// Formats numbers using the Indian numbering system (e.g. 1234567 -> 12,34,567)
  static String _formatIndianGrouping(int number) {
    final str = number.toString();
    if (str.length <= 3) return str;

    final lastThree = str.substring(str.length - 3);
    final remaining = str.substring(0, str.length - 3);

    final buffer = StringBuffer();
    for (var i = 0; i < remaining.length; i++) {
      if (i > 0 && (remaining.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(remaining[i]);
    }
    buffer.write(',');
    buffer.write(lastThree);
    return buffer.toString();
  }
}
