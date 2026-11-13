import 'package:flutter_test/flutter_test.dart';
import 'package:sangh_ledger/domain/services/interest_calculator.dart';

void main() {
  group('InterestCalculator 30-Day Month Reducing-Balance Daily Interest Tests', () {
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

    test('30-Day month convention: ₹1,000 loan at 1% monthly for 30 days = exactly ₹10.00 (1000 paise)', () {
      // Principal = ₹1,000 (100,000 paise)
      // 1% of ₹1,000 = ₹10.00 (1,000 paise)
      final interest = InterestCalculator.calculateReducingInterestPaise(
        principalPaise: 100000,
        monthlyBps: 100,
        days: 30,
      );

      expect(interest, 1000); // Exactly ₹10.00 (1000 paise)
    });

    test('30-Day month convention: ₹1,000 loan at 1% monthly for 1 day = ₹0.33 (33 paise)', () {
      // Principal = ₹1,000 (100,000 paise)
      // Daily interest = ₹10 / 30 = ₹0.33 (33 paise)
      final interest = InterestCalculator.calculateReducingInterestPaise(
        principalPaise: 100000,
        monthlyBps: 100,
        days: 1,
      );

      expect(interest, 33); // Exactly ₹0.33 (33 paise)
    });

    test('Same-day repayment computeAccrual charges minimum 1-day interest (₹0.33 on ₹1,000)', () {
      final now = DateTime.utc(2026, 11, 13, 10, 0);
      final laterToday = DateTime.utc(2026, 11, 13, 16, 0);

      final accrual = InterestCalculator.computeAccrual(
        principalPaise: 100000,
        monthlyBps: 100,
        fromDate: now,
        toDate: laterToday,
      );

      expect(accrual.days, 1);
      expect(accrual.interestPaise, 33);
    });

    test('Large ₹10,00,000 loan computes accurately without integer overflow', () {
      // Principal: ₹10,00,000 = 100,000,000 paise
      // 30 days @ 100 bps (1% monthly = ₹10,000 / month = 1,000,000 paise)
      final interest = InterestCalculator.calculateReducingInterestPaise(
        principalPaise: 100000000,
        monthlyBps: 100,
        days: 30,
      );

      expect(interest, 1000000); // Exactly ₹10,000.00
    });

    test('1-paisa rounding edge case with ROUND_HALF_UP', () {
      // Small principal: ₹100 (10,000 paise), 1 day @ 100 bps
      // (10,000 * 100 * 1 + 150000) / 300000 = 1,150,000 / 300000 = 3.83 -> rounds to 3 paise
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
  });
}
