class InterestCalculationResult {
  final int days;
  final int interestPaise;
  final int outstandingPrincipalPaise;
  final int monthlyBps;
  final DateTime fromDate;
  final DateTime toDate;

  const InterestCalculationResult({
    required this.days,
    required this.interestPaise,
    required this.outstandingPrincipalPaise,
    required this.monthlyBps,
    required this.fromDate,
    required this.toDate,
  });
}

class InterestCalculator {
  InterestCalculator._();

  // 30-Day Month Convention: 10,000 basis points * 30 days = 300,000
  static const int defaultDenominator = 300000;
  static final BigInt _denominatorBigInt = BigInt.from(defaultDenominator);
  static final BigInt _halfDenominator = BigInt.from(defaultDenominator ~/ 2); // 150000 for ROUND_HALF_UP

  /// Normalizes a DateTime to Asia/Kolkata (UTC+05:30) date-only (midnight)
  static DateTime toKolkataDate(DateTime date) {
    // Offset for Asia/Kolkata is +5 hours 30 minutes
    final kolkataTime = date.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateTime.utc(kolkataTime.year, kolkataTime.month, kolkataTime.day);
  }

  /// Calculates elapsed calendar days strictly in Asia/Kolkata timezone
  static int calculateElapsedDays(DateTime fromDate, DateTime toDate) {
    final d1 = toKolkataDate(fromDate);
    final d2 = toKolkataDate(toDate);
    final diff = d2.difference(d1).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Calculates reducing-balance daily interest in integer paise using exact BigInt arithmetic with ROUND_HALF_UP.
  /// 30-Day Month Convention Formula:
  /// ((principalPaise * monthlyBps * days) + 150000) / 300000
  static int calculateReducingInterestPaise({
    required int principalPaise,
    required int monthlyBps,
    required int days,
  }) {
    if (principalPaise <= 0 || monthlyBps <= 0 || days <= 0) {
      return 0;
    }

    final p = BigInt.from(principalPaise);
    final bps = BigInt.from(monthlyBps);
    final d = BigInt.from(days);

    final numerator = p * bps * d;
    final rounded = (numerator + _halfDenominator) ~/ _denominatorBigInt;

    return rounded.toInt();
  }

  /// Computes full interest calculation result between two dates using 30-day month daily convention.
  /// If elapsedDays == 0 (same-day disbursement + repayment), charges minimum 1 day of interest (effectiveDays = 1).
  static InterestCalculationResult computeAccrual({
    required int principalPaise,
    required int monthlyBps,
    required DateTime fromDate,
    required DateTime toDate,
    bool chargeMinOneDayForSameDay = true,
  }) {
    final rawElapsedDays = calculateElapsedDays(fromDate, toDate);
    final effectiveDays = (rawElapsedDays == 0 && chargeMinOneDayForSameDay) ? 1 : rawElapsedDays;
    final interest = calculateReducingInterestPaise(
      principalPaise: principalPaise,
      monthlyBps: monthlyBps,
      days: effectiveDays,
    );

    return InterestCalculationResult(
      days: effectiveDays,
      interestPaise: interest,
      outstandingPrincipalPaise: principalPaise,
      monthlyBps: monthlyBps,
      fromDate: fromDate,
      toDate: toDate,
    );
  }
}

