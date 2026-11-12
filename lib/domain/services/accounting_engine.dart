import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';

class JournalLineDraft {
  final String accountCode;
  final int debitPaise;
  final int creditPaise;
  final String? description;

  const JournalLineDraft({
    required this.accountCode,
    this.debitPaise = 0,
    this.creditPaise = 0,
    this.description,
  }) : assert(debitPaise >= 0 && creditPaise >= 0, 'Amounts must be non-negative');
}

enum PaymentMode { cash, bank }

class AccountingEngine {
  final AppDatabase _db;
  static const uuid = Uuid();

  // Standard Chart of Accounts codes
  static const String codeCash = '1001';
  static const String codeBank = '1002';
  static const String codeLoanPrincipalReceivable = '1101';
  static const String codeInterestReceivable = '1102';
  static const String codeMemberSavingsLiability = '2001';
  static const String codeInterestIncome = '4001';
  static const String codeAuthorizedAdjustment = '5001';

  AccountingEngine({AppDatabase? db}) : _db = db ?? AppDatabase();

  static String getCashOrBankCode(PaymentMode mode) {
    return mode == PaymentMode.cash ? codeCash : codeBank;
  }

  /// Posts an atomic journal entry with lines. Validates SUM(debits) == SUM(credits) strictly.
  Future<String> postJournalEntry(
    DatabaseExecutor txn, {
    String? transactionId,
    required DateTime entryDate,
    required String description,
    required List<JournalLineDraft> lines,
    bool isReversal = false,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('Journal entry must have at least one line');
    }

    int totalDebits = 0;
    int totalCredits = 0;

    for (final line in lines) {
      totalDebits += line.debitPaise;
      totalCredits += line.creditPaise;
    }

    if (totalDebits != totalCredits) {
      throw ArgumentError(
        'Unbalanced journal entry: Total debits ($totalDebits paise) does not equal total credits ($totalCredits paise)',
      );
    }

    if (totalDebits == 0) {
      throw ArgumentError('Journal entry amount must be greater than zero');
    }

    final entryId = uuid.v4();
    final now = DateTime.now().toIso8601String();

    await txn.insert('journal_entries', {
      'id': entryId,
      'transaction_id': transactionId,
      'entry_date': entryDate.toIso8601String(),
      'description': description,
      'is_reversal': isReversal ? 1 : 0,
      'created_at': now,
    });

    for (final line in lines) {
      await txn.insert('journal_lines', {
        'id': uuid.v4(),
        'journal_entry_id': entryId,
        'account_code': line.accountCode,
        'debit_paise': line.debitPaise,
        'credit_paise': line.creditPaise,
        'description': line.description ?? description,
      });
    }

    return entryId;
  }

  /// 1. Savings Deposit Posting Template:
  /// Debit: Cash (1001) / Bank (1002)
  /// Credit: Member Savings Liabilities (2001)
  Future<String> postSavingsDeposit(
    DatabaseExecutor txn, {
    required String transactionId,
    required DateTime date,
    required int amountPaise,
    required PaymentMode mode,
    required String memberCode,
  }) async {
    final assetAccount = getCashOrBankCode(mode);
    return postJournalEntry(
      txn,
      transactionId: transactionId,
      entryDate: date,
      description: 'Savings deposit for $memberCode via ${mode.name.toUpperCase()}',
      lines: [
        JournalLineDraft(
          accountCode: assetAccount,
          debitPaise: amountPaise,
          description: 'Cash/Bank received for savings deposit',
        ),
        JournalLineDraft(
          accountCode: codeMemberSavingsLiability,
          creditPaise: amountPaise,
          description: 'Member savings liability increase ($memberCode)',
        ),
      ],
    );
  }

  /// 2. Savings Withdrawal Posting Template:
  /// Debit: Member Savings Liabilities (2001)
  /// Credit: Cash (1001) / Bank (1002)
  Future<String> postSavingsWithdrawal(
    DatabaseExecutor txn, {
    required String transactionId,
    required DateTime date,
    required int amountPaise,
    required PaymentMode mode,
    required String memberCode,
  }) async {
    final assetAccount = getCashOrBankCode(mode);
    return postJournalEntry(
      txn,
      transactionId: transactionId,
      entryDate: date,
      description: 'Savings withdrawal for $memberCode via ${mode.name.toUpperCase()}',
      lines: [
        JournalLineDraft(
          accountCode: codeMemberSavingsLiability,
          debitPaise: amountPaise,
          description: 'Member savings liability reduction ($memberCode)',
        ),
        JournalLineDraft(
          accountCode: assetAccount,
          creditPaise: amountPaise,
          description: 'Cash/Bank payout for savings withdrawal',
        ),
      ],
    );
  }

  /// 3. Loan Disbursement Posting Template:
  /// Debit: Loan Principal Receivables (1101)
  /// Credit: Cash (1001) / Bank (1002)
  Future<String> postLoanDisbursement(
    DatabaseExecutor txn, {
    required String transactionId,
    required DateTime date,
    required int amountPaise,
    required PaymentMode mode,
    required String loanCode,
  }) async {
    final assetAccount = getCashOrBankCode(mode);
    return postJournalEntry(
      txn,
      transactionId: transactionId,
      entryDate: date,
      description: 'Loan disbursement for $loanCode via ${mode.name.toUpperCase()}',
      lines: [
        JournalLineDraft(
          accountCode: codeLoanPrincipalReceivable,
          debitPaise: amountPaise,
          description: 'Loan principal receivable asset ($loanCode)',
        ),
        JournalLineDraft(
          accountCode: assetAccount,
          creditPaise: amountPaise,
          description: 'Cash/Bank disbursed for loan',
        ),
      ],
    );
  }

  /// 4. Principal Repayment Posting Template:
  /// Debit: Cash (1001) / Bank (1002)
  /// Credit: Loan Principal Receivables (1101)
  Future<String> postPrincipalRepayment(
    DatabaseExecutor txn, {
    required String transactionId,
    required DateTime date,
    required int amountPaise,
    required PaymentMode mode,
    required String loanCode,
  }) async {
    final assetAccount = getCashOrBankCode(mode);
    return postJournalEntry(
      txn,
      transactionId: transactionId,
      entryDate: date,
      description: 'Loan principal repayment for $loanCode',
      lines: [
        JournalLineDraft(
          accountCode: assetAccount,
          debitPaise: amountPaise,
          description: 'Cash/Bank received for loan principal',
        ),
        JournalLineDraft(
          accountCode: codeLoanPrincipalReceivable,
          creditPaise: amountPaise,
          description: 'Loan principal receivable reduction ($loanCode)',
        ),
      ],
    );
  }

  /// 5. Interest Accrual Posting Template:
  /// Debit: Interest Receivables (1102)
  /// Credit: Interest Income (4001)
  Future<String> postInterestAccrual(
    DatabaseExecutor txn, {
    required String transactionId,
    required DateTime date,
    required int amountPaise,
    required String loanCode,
  }) async {
    return postJournalEntry(
      txn,
      transactionId: transactionId,
      entryDate: date,
      description: 'Daily reducing interest accrual for $loanCode',
      lines: [
        JournalLineDraft(
          accountCode: codeInterestReceivable,
          debitPaise: amountPaise,
          description: 'Interest receivable accrued asset ($loanCode)',
        ),
        JournalLineDraft(
          accountCode: codeInterestIncome,
          creditPaise: amountPaise,
          description: 'Interest income recognized ($loanCode)',
        ),
      ],
    );
  }

  /// 6. Interest Collection Posting Template:
  /// Debit: Cash (1001) / Bank (1002)
  /// Credit: Interest Receivables (1102)
  Future<String> postInterestCollection(
    DatabaseExecutor txn, {
    required String transactionId,
    required DateTime date,
    required int amountPaise,
    required PaymentMode mode,
    required String loanCode,
  }) async {
    final assetAccount = getCashOrBankCode(mode);
    return postJournalEntry(
      txn,
      transactionId: transactionId,
      entryDate: date,
      description: 'Interest collected for $loanCode',
      lines: [
        JournalLineDraft(
          accountCode: assetAccount,
          debitPaise: amountPaise,
          description: 'Cash/Bank received for accrued interest',
        ),
        JournalLineDraft(
          accountCode: codeInterestReceivable,
          creditPaise: amountPaise,
          description: 'Interest receivable settlement ($loanCode)',
        ),
      ],
    );
  }

  /// 7. Reverse Transaction Posting Template:
  /// Posts an equal-and-opposite journal entry
  Future<String> reverseJournalEntry(
    DatabaseExecutor txn, {
    required String originalEntryId,
    required String reversalReason,
    required DateTime reversalDate,
  }) async {
    final originalLines = await txn.query(
      'journal_lines',
      where: 'journal_entry_id = ?',
      whereArgs: [originalEntryId],
    );

    if (originalLines.isEmpty) {
      throw StateError('Original journal entry lines not found for reversal');
    }

    // Invert debits and credits
    final reversalLines = originalLines.map((line) {
      return JournalLineDraft(
        accountCode: line['account_code'] as String,
        debitPaise: line['credit_paise'] as int,
        creditPaise: line['debit_paise'] as int,
        description: 'Reversal: ${line['description'] ?? reversalReason}',
      );
    }).toList();

    return postJournalEntry(
      txn,
      entryDate: reversalDate,
      description: 'REVERSAL: $reversalReason',
      lines: reversalLines,
      isReversal: true,
    );
  }

  /// Derives account net balance in paise:
  /// For Assets/Expenses: Debits - Credits
  /// For Liabilities/Equity/Income: Credits - Debits
  Future<int> getAccountBalance(String accountCode) async {
    final balances = await getAllAccountBalances();
    return balances[accountCode] ?? 0;
  }

  /// Live query over journal_lines grouped by account_code adhering strictly to sign conventions:
  /// Assets (1001, 1002, 1101, 1102): SUM(debit_paise) - SUM(credit_paise)
  /// Liabilities (2001) & Income (4001): SUM(credit_paise) - SUM(debit_paise)
  Future<Map<String, int>> getAllAccountBalances() async {
    final db = await _db.database;
    final results = await db.rawQuery('''
      SELECT 
        a.code,
        a.account_type,
        COALESCE(SUM(jl.debit_paise), 0) as total_debit,
        COALESCE(SUM(jl.credit_paise), 0) as total_credit
      FROM accounting_accounts a
      LEFT JOIN journal_lines jl ON a.code = jl.account_code
      GROUP BY a.code, a.account_type
    ''');

    final map = <String, int>{};
    for (final row in results) {
      final code = row['code'] as String;
      final type = row['account_type'] as String;
      final debit = (row['total_debit'] as int?) ?? 0;
      final credit = (row['total_credit'] as int?) ?? 0;
      if (type == 'Asset' || type == 'Expense') {
        map[code] = debit - credit;
      } else {
        map[code] = credit - debit;
      }
    }
    return map;
  }

  /// Derives a member's total savings balance from transaction entries
  Future<int> getMemberSavingsBalance(String memberId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN transaction_type = 'savings_deposit' THEN amount_paise ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN transaction_type = 'savings_withdrawal' THEN amount_paise ELSE 0 END), 0) as balance
      FROM transactions
      WHERE member_id = ? AND is_reversed = 0
    ''', [memberId]);

    return (result.first['balance'] as int?) ?? 0;
  }

  /// Derives a member's outstanding loan principal from active loans and principal repayments
  Future<int> getMemberLoanPrincipal(String memberId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(l.principal_paise), 0) - 
        COALESCE((
          SELECT SUM(r.principal_portion_paise)
          FROM repayments r
          JOIN loans l2 ON r.loan_id = l2.id
          JOIN transactions t ON r.transaction_id = t.id
          WHERE l2.member_id = ? AND t.is_reversed = 0
        ), 0) as outstanding_principal
      FROM loans l
      WHERE l.member_id = ? AND l.status IN ('Active', 'Partially Repaid')
    ''', [memberId, memberId]);

    final principal = (result.first['outstanding_principal'] as int?) ?? 0;
    return principal > 0 ? principal : 0;
  }
}

