import 'package:flutter_test/flutter_test.dart';
import 'package:sangh_ledger/domain/services/interest_calculator.dart';

void main() {
  group('InterestCalculator Reducing-Balance Daily Interest Tests', () {
    test('Zero days or zero principal produces 0 paise interest', () {
      expect(
        InterestCalculator.calculateReducingInterestPaise(
          principalPaise: 1000000,
          monthlyBps: 100,
          days: 0,
        ),
        0,
      );

      expect(
        InterestCalculator.calculateReducingInterestPaise(
          principalPaise: 0,
          monthlyBps: 100,
          days: 30,
        ),
        0,
      );
    });

    test('365 days at 100 bps monthly (1%) produces exactly 12% annual interest', () {
      // Principal = ₹10,000 (1,000,000 paise)
      // 12% of 10,000 = ₹1,200 (120,000 paise)
      final interest = InterestCalculator.calculateReducingInterestPaise(
        principalPaise: 1000000,
        monthlyBps: 100,
        days: 365,
      );

      expect(interest, 120000); // Exactly ₹1,200.00
    });

    test('Large ₹10,00,000 loan computes accurately without integer overflow', () {
      // Principal: ₹10,00,000 = 100,000,000 paise
      // 30 days @ 100 bps
      // Formula: (100000000 * 100 * 12 * 30 + 1825000) / 3650000
      // Numerator: 3,600,000,000,000
      // 3600000000000 / 3650000 = 986301 paise = ₹9,863.01
      final interest = InterestCalculator.calculateReducingInterestPaise(
        principalPaise: 100000000,
        monthlyBps: 100,
        days: 30,
      );

      expect(interest, 986301);
    });

    test('1-paisa rounding edge case with ROUND_HALF_UP', () {
      // Small principal: ₹100 (10,000 paise), 1 day @ 100 bps
      // Numerator = 10,000 * 100 * 12 * 1 = 12,000,000
      // 12,000,000 / 3,650,000 = 3.287 -> rounds to 3 paise
      final interest = InterestCalculator.calculateReducingInterestPaise(
        principalPaise: 10000,
        monthlyBps: 100,
        days: 1,
      );
      expect(interest, 3);
    });

    test('Leap year Feb 29 date calculations in Asia/Kolkata', () {
      // 2024 is a leap year (Feb 28 to March 1 = 2 days)
      final d1 = DateTime.utc(2024, 2, 28);
      final d2 = DateTime.utc(2024, 3, 1);
      final elapsed = InterestCalculator.calculateElapsedDays(d1, d2);
      expect(elapsed, 2);
    });

    test('Same-day repayment produces 0 elapsed days', () {
      final now = DateTime.utc(2026, 11, 12, 10, 0);
      final laterToday = DateTime.utc(2026, 11, 12, 15, 30);
      final elapsed = InterestCalculator.calculateElapsedDays(now, laterToday);
      expect(elapsed, 0);
    });
  });
}
