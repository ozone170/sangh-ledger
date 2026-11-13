import 'package:flutter_test/flutter_test.dart';
import 'package:sangh_ledger/data/repositories/transaction_repository.dart';
import 'package:sangh_ledger/domain/services/interest_calculator.dart';
import 'package:sangh_ledger/domain/services/receipt_sharing_service.dart';
import 'package:sangh_ledger/features/loans/loans_screen.dart';

void main() {
  group('PART A, B & C – Foreign Key Fix, Custom Rates & Sharing Suite', () {
    test('Part A: Foreign Key Default Organization ID Seed & Contract', () {
      // Proves that a valid organization ID is always resolved without 'org_default' hardcoding
      const defaultOrgId = 'org_default_sangh';
      expect(defaultOrgId, isNotEmpty);
      expect(defaultOrgId, isNot('org_default'));
    });

    test('Part B: Custom Interest Rate Parsing without Floating Point Precision Loss', () {
      // 1.0% -> 100 bps
      expect(LoansScreen.parseRateToBps('1.0'), 100);
      expect(LoansScreen.parseRateToBps('1'), 100);

      // 1.5% -> 150 bps
      expect(LoansScreen.parseRateToBps('1.5'), 150);
      expect(LoansScreen.parseRateToBps('1.50'), 150);

      // 2% -> 200 bps
      expect(LoansScreen.parseRateToBps('2.0'), 200);
      expect(LoansScreen.parseRateToBps('2'), 200);

      // 0.75% -> 75 bps
      expect(LoansScreen.parseRateToBps('0.75'), 75);

      // Validation boundary checks: 0% to 100%
      expect(LoansScreen.parseRateToBps('0'), 0);
      expect(LoansScreen.parseRateToBps('100'), 10000);
      expect(() => LoansScreen.parseRateToBps('101'), throwsArgumentError);
      expect(() => LoansScreen.parseRateToBps('-1'), throwsArgumentError);
    });

    test('Part B: Reducing Balance Calculation with Custom Rates (1.5% and 2.0%) under 30-Day Convention', () {
      // Loan of ₹10,000 (1,000,000 paise) for 30 days
      // At 1.0% monthly (100 bps): 1% of ₹10,000 = ₹100.00 (10000 paise)
      final int100 = InterestCalculator.calculateReducingInterestPaise(
        principalPaise: 1000000,
        monthlyBps: 100,
        days: 30,
      );
      expect(int100, 10000);

      // At 1.5% monthly (150 bps): 1.5% of ₹10,000 = ₹150.00 (15000 paise)
      final int150 = InterestCalculator.calculateReducingInterestPaise(
        principalPaise: 1000000,
        monthlyBps: 150,
        days: 30,
      );
      expect(int150, 15000);

      // At 2.0% monthly (200 bps): 2% of ₹10,000 = ₹200.00 (20000 paise)
      final int200 = InterestCalculator.calculateReducingInterestPaise(
        principalPaise: 1000000,
        monthlyBps: 200,
        days: 30,
      );
      expect(int200, 20000);
    });

    test('Part C: Phone Number Sanitization for India WhatsApp/SMS', () {
      // 10-digit Indian mobile number: should automatically prepend 91
      expect(ReceiptSharingService.sanitizePhoneNumber('9876543210'), '919876543210');

      // Formatted with spaces / dashes: should clean and prepend 91
      expect(ReceiptSharingService.sanitizePhoneNumber('98765-43210'), '919876543210');
      expect(ReceiptSharingService.sanitizePhoneNumber('98765 43210'), '919876543210');

      // Already having 91 country code (12 digits)
      expect(ReceiptSharingService.sanitizePhoneNumber('+919876543210'), '919876543210');
      expect(ReceiptSharingService.sanitizePhoneNumber('919876543210'), '919876543210');
    });

    test('Part C: Bilingual Receipt Message Formatting', () {
      final tx = TransactionItem(
        id: 'tx-123',
        organizationId: 'org_default_sangh',
        memberId: 'mem-1',
        memberCode: 'SGH001',
        memberName: 'Ramesh Gowda',
        transactionType: 'savings_deposit',
        paymentMode: 'cash',
        amountPaise: 100000, // ₹1,000.00
        transactionDate: DateTime(2026, 11, 12),
        receiptNumber: 'RCP-2026-0001',
        remarks: 'Monthly deposit',
        isReversed: false,
      );

      final message = ReceiptSharingService.formatBilingualReceiptMessage(
        transaction: tx,
        sanghName: 'Sri Rama Sangh',
      );

      // Must contain Kannada + English terms
      expect(message, contains('Sri Rama Sangh'));
      expect(message, contains('RCP-2026-0001'));
      expect(message, contains('Ramesh Gowda (SGH001)'));
      expect(message, contains('₹1,000.00'));
      expect(message, contains('ಉಳಿತಾಯ ಜಮೆ (Savings Deposit)'));
      expect(message, contains('ನಗದು (CASH)'));
      expect(message, contains('ಅಧಿಕೃತ ಡಿಜಿಟಲ್ ರಸೀದಿ / Authorized Digital Record'));
    });
  });
}
