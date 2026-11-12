import 'package:flutter_test/flutter_test.dart';
import 'package:sangh_ledger/domain/services/accounting_engine.dart';

void main() {
  group('AccountingEngine Journal Validation Tests', () {
    test('JournalLineDraft validates non-negative paise', () {
      expect(
        () => JournalLineDraft(accountCode: '1001', debitPaise: 5000, creditPaise: 0),
        returnsNormally,
      );
    });

    test('Chart of Accounts codes are standard and verified', () {
      expect(AccountingEngine.codeCash, '1001');
      expect(AccountingEngine.codeBank, '1002');
      expect(AccountingEngine.codeLoanPrincipalReceivable, '1101');
      expect(AccountingEngine.codeInterestReceivable, '1102');
      expect(AccountingEngine.codeMemberSavingsLiability, '2001');
      expect(AccountingEngine.codeInterestIncome, '4001');
      expect(AccountingEngine.codeAuthorizedAdjustment, '5001');
    });

    test('getCashOrBankCode maps payment modes properly', () {
      expect(AccountingEngine.getCashOrBankCode(PaymentMode.cash), '1001');
      expect(AccountingEngine.getCashOrBankCode(PaymentMode.bank), '1002');
    });
  });
}

