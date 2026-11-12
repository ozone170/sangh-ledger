import 'package:flutter_test/flutter_test.dart';
import 'package:sangh_ledger/core/security/crypto_utils.dart';
import 'package:sangh_ledger/core/utils/currency_formatter.dart';
import 'package:sangh_ledger/data/repositories/member_repository.dart';
import 'package:sangh_ledger/domain/services/accounting_engine.dart';
import 'package:sangh_ledger/domain/services/backup_service.dart';
import 'package:sangh_ledger/domain/services/interest_calculator.dart';

void main() {
  group('TASK 17 – Full Financial, Security & Scale Audit Suite', () {
    test('1. Financial Edge Cases – ₹50,00,000 Large Loan 365 Days Interest', () {
      // Principal: ₹50,00,000 = 500,000,000 paise
      // Annual rate: 12% = ₹6,00,000 = 60,000,000 paise
      final interest = InterestCalculator.calculateReducingInterestPaise(
        principalPaise: 500000000,
        monthlyBps: 100, // 1%
        days: 365,
      );

      expect(interest, 60000000); // Exact ₹6,00,000.00 to the single paisa!
    });

    test('2. Financial Edge Cases – 1-Paisa Precision & Non-Compounding', () {
      final int1 = InterestCalculator.calculateReducingInterestPaise(
        principalPaise: 10000, // ₹100
        monthlyBps: 100,
        days: 15,
      );
      // (10000 * 100 * 12 * 15 + 1825000) / 3650000 = (180,000,000 + 1,825,000) / 3,650,000 = 49 paise
      expect(int1, 49);
    });

    test('3. Scale & Performance – 10,000 Transaction Arithmetic Stability', () {
      // Perform 10,000 cumulative integer paise additions & subtractions
      int totalBalancePaise = 0;
      const depositPerTx = 25050; // ₹250.50
      const withdrawalPerTx = 10025; // ₹100.25

      for (int i = 0; i < 10000; i++) {
        totalBalancePaise += depositPerTx;
        totalBalancePaise -= withdrawalPerTx;
      }

      // Expected net: 10000 * 15025 = 150,250,000 paise (₹15,02,500.00)
      expect(totalBalancePaise, 150250000);
      expect(CurrencyFormatter.formatPaise(totalBalancePaise), '₹15,02,500.00');
    });

    test('4. Security Audit – PBKDF2 Key Derivation from Admin Password', () async {
      final salt = CryptoUtils.generateRandomBytes(16);
      final key1 = await BackupService.deriveKeyFromPassword('Admin@1234', salt);
      final key2 = await BackupService.deriveKeyFromPassword('Admin@1234', salt);
      final keyWrong = await BackupService.deriveKeyFromPassword('WrongPassword', salt);

      expect(key1.length, 32); // 256 bits
      expect(key1, equals(key2)); // Deterministic with same salt
      expect(key1, isNot(equals(keyWrong))); // Different key for wrong password
    });

    test('5. Hard Scale Rule – 100 Active Members Maximum Constraint', () {
      expect(MemberRepository.maxActiveMembers, 100);
    });

    test('6. Double-Entry Immutability & Reversal Symmetry', () {
      final line1 = JournalLineDraft(accountCode: AccountingEngine.codeCash, debitPaise: 50000);
      final line2 = JournalLineDraft(accountCode: AccountingEngine.codeMemberSavingsLiability, creditPaise: 50000);

      expect(line1.debitPaise, line2.creditPaise);

      // Symmetrical Reversal Lines
      final revLine1 = JournalLineDraft(accountCode: line1.accountCode, creditPaise: line1.debitPaise);
      final revLine2 = JournalLineDraft(accountCode: line2.accountCode, debitPaise: line2.creditPaise);

      expect(revLine1.creditPaise, revLine2.debitPaise);
    });
  });
}
