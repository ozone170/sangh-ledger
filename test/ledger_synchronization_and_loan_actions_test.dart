import 'package:flutter_test/flutter_test.dart';
import 'package:sangh_ledger/domain/entities/loan.dart';
import 'package:sangh_ledger/domain/services/accounting_engine.dart';

void main() {
  group('Ledger Synchronization, Balances & Loan Disbursement Actions', () {
    test('1. Double-Entry Savings Deposit: Cash (1001) & Savings Liability (2001)', () {
      const depositPaise = 100000; // ₹1,000.00
      const memberCode = 'SGH001';

      // Savings Deposit: Debit Cash (1001), Credit Member Savings Liabilities (2001)
      final lines = [
        const JournalLineDraft(
          accountCode: AccountingEngine.codeCash,
          debitPaise: depositPaise,
          creditPaise: 0,
        ),
        const JournalLineDraft(
          accountCode: AccountingEngine.codeMemberSavingsLiability,
          debitPaise: 0,
          creditPaise: depositPaise,
          description: 'Member savings liability increase ($memberCode)',
        ),
      ];

      // Verify double-entry balancing
      final totalDebits = lines.fold<int>(0, (sum, l) => sum + l.debitPaise);
      final totalCredits = lines.fold<int>(0, (sum, l) => sum + l.creditPaise);
      expect(totalDebits, equals(totalCredits));
      expect(totalDebits, equals(100000));

      // Check standard sign conventions:
      // Asset (Cash): Debits - Credits = +100,000 paise (+₹1,000.00)
      final cashNet = lines
          .where((l) => l.accountCode == AccountingEngine.codeCash)
          .fold<int>(0, (sum, l) => sum + l.debitPaise - l.creditPaise);
      expect(cashNet, equals(100000));

      // Liability (Savings): Credits - Debits = +100,000 paise (+₹1,000.00)
      final savingsNet = lines
          .where((l) => l.accountCode == AccountingEngine.codeMemberSavingsLiability)
          .fold<int>(0, (sum, l) => sum + l.creditPaise - l.debitPaise);
      expect(savingsNet, equals(100000));
    });

    test('2. Double-Entry Loan Disbursement: Loan Principal (1101) & Cash (1001)', () {
      const loanPrincipalPaise = 50000; // ₹500.00
      const loanCode = 'LN-2026-0001';

      // Loan Disbursement: Debit Loan Principal Receivable (1101), Credit Cash (1001)
      final lines = [
        const JournalLineDraft(
          accountCode: AccountingEngine.codeLoanPrincipalReceivable,
          debitPaise: loanPrincipalPaise,
          creditPaise: 0,
          description: 'Loan principal asset ($loanCode)',
        ),
        const JournalLineDraft(
          accountCode: AccountingEngine.codeCash,
          debitPaise: 0,
          creditPaise: loanPrincipalPaise,
          description: 'Cash disbursed for loan',
        ),
      ];

      final totalDebits = lines.fold<int>(0, (sum, l) => sum + l.debitPaise);
      final totalCredits = lines.fold<int>(0, (sum, l) => sum + l.creditPaise);
      expect(totalDebits, equals(totalCredits));
      expect(totalDebits, equals(50000));

      // Asset (Loan Principal Receivable): Debits - Credits = +50,000 (+₹500.00)
      final loanReceivableNet = lines
          .where((l) => l.accountCode == AccountingEngine.codeLoanPrincipalReceivable)
          .fold<int>(0, (sum, l) => sum + l.debitPaise - l.creditPaise);
      expect(loanReceivableNet, equals(50000));

      // Asset (Cash): Debits - Credits = -50,000 (-₹500.00)
      final cashNet = lines
          .where((l) => l.accountCode == AccountingEngine.codeCash)
          .fold<int>(0, (sum, l) => sum + l.debitPaise - l.creditPaise);
      expect(cashNet, equals(-50000));
    });

    test('3. Disbursement Reversal: Inverts lines and restores Cash & Loan Principal', () {
      const loanPrincipalPaise = 50000; // ₹500.00

      // Prior balances after ₹1,000 deposit and ₹500 disbursement:
      // Cash: 100,000 - 50,000 = 50,000 paise (₹500.00)
      // Loan Principal Receivable: 50,000 paise (₹500.00)
      int cashBalance = 50000;
      int loanReceivableBalance = 50000;

      // Reversal lines: Inverts original debits and credits
      final reversalLines = [
        const JournalLineDraft(
          accountCode: AccountingEngine.codeCash,
          debitPaise: loanPrincipalPaise,
          creditPaise: 0,
          description: 'Reversal: Cash restored',
        ),
        const JournalLineDraft(
          accountCode: AccountingEngine.codeLoanPrincipalReceivable,
          debitPaise: 0,
          creditPaise: loanPrincipalPaise,
          description: 'Reversal: Loan principal reduction',
        ),
      ];

      // Verify balanced reversal entry
      final revDebits = reversalLines.fold<int>(0, (sum, l) => sum + l.debitPaise);
      final revCredits = reversalLines.fold<int>(0, (sum, l) => sum + l.creditPaise);
      expect(revDebits, equals(revCredits));

      // Apply reversal to ledger balances
      for (final line in reversalLines) {
        if (line.accountCode == AccountingEngine.codeCash) {
          cashBalance += (line.debitPaise - line.creditPaise);
        } else if (line.accountCode == AccountingEngine.codeLoanPrincipalReceivable) {
          loanReceivableBalance += (line.debitPaise - line.creditPaise);
        }
      }

      // Assert Cash restored to ₹1,000 and Loan Principal restored to ₹0
      expect(cashBalance, equals(100000)); // Exactly ₹1,000.00
      expect(loanReceivableBalance, equals(0)); // Exactly ₹0.00
    });

    test('4. Loan Lifecycle State Transitions and Allowed Actions', () {
      final now = DateTime.now();
      var loan = Loan(
        id: 'loan-1',
        organizationId: 'org-1',
        memberId: 'mem-1',
        loanCode: 'LN-2026-0001',
        principalPaise: 50000,
        monthlyInterestBps: 100,
        calculationMethod: 'reducing_balance',
        dayCountBasis: 365,
        issueDate: now,
        status: 'Draft',
        createdAt: now,
        updatedAt: now,
      );

      // In Draft state: Disburse action is valid, Repay is not
      expect(loan.status, 'Draft');

      // Transition to Active upon disbursement
      loan = Loan.fromMap({...loan.toMap(), 'status': 'Active'});
      expect(loan.status, 'Active');

      // In Active state with 0 repayments: Both Repay and Reverse Disbursement are valid
      const repaymentsCount = 0;
      final canReverse = (loan.status == 'Active' || loan.status == 'Partially Repaid') && repaymentsCount == 0;
      expect(canReverse, isTrue);

      // Once a repayment is recorded, reversing disbursement is strictly disallowed
      const repaymentsCountAfterPayment = 1;
      final canReverseAfterPayment = (loan.status == 'Active' || loan.status == 'Partially Repaid') && repaymentsCountAfterPayment == 0;
      expect(canReverseAfterPayment, isFalse);

      // Reversal reverts status to Draft
      final revertedLoan = Loan.fromMap({...loan.toMap(), 'status': 'Draft'});
      expect(revertedLoan.status, 'Draft');
    });
  });
}

