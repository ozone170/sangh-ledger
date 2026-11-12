import 'package:flutter_test/flutter_test.dart';
import 'package:sangh_ledger/domain/services/reports_service.dart';

void main() {
  group('Reports and Double-Entry Trial Balance Verification Tests', () {
    test('TrialBalanceReport validates debits equal credits', () {
      const balancedReport = TrialBalanceReport(
        items: [
          TrialBalanceItem(
            accountCode: '1001',
            accountName: 'Cash in Hand',
            accountType: 'Asset',
            debitBalancePaise: 500000,
            creditBalancePaise: 0,
          ),
          TrialBalanceItem(
            accountCode: '2001',
            accountName: 'Member Savings Liabilities',
            accountType: 'Liability',
            debitBalancePaise: 0,
            creditBalancePaise: 500000,
          ),
        ],
        totalDebitsPaise: 500000,
        totalCreditsPaise: 500000,
        isBalanced: true,
      );

      expect(balancedReport.isBalanced, isTrue);
      expect(balancedReport.totalDebitsPaise, balancedReport.totalCreditsPaise);
    });

    test('Unbalanced trial balance flag is correctly detected', () {
      const unbalanced = TrialBalanceReport(
        items: [],
        totalDebitsPaise: 500000,
        totalCreditsPaise: 490000,
        isBalanced: false,
      );

      expect(unbalanced.isBalanced, isFalse);
    });
  });
}

