import '../../core/database/app_database.dart';
import 'interest_calculator.dart';

class TrialBalanceItem {
  final String accountCode;
  final String accountName;
  final String accountType;
  final int debitBalancePaise;
  final int creditBalancePaise;

  const TrialBalanceItem({
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.debitBalancePaise,
    required this.creditBalancePaise,
  });
}

class TrialBalanceReport {
  final List<TrialBalanceItem> items;
  final int totalDebitsPaise;
  final int totalCreditsPaise;
  final bool isBalanced;

  const TrialBalanceReport({
    required this.items,
    required this.totalDebitsPaise,
    required this.totalCreditsPaise,
    required this.isBalanced,
  });
}

class ReportsService {
  final AppDatabase _db;

  ReportsService({AppDatabase? db}) : _db = db ?? AppDatabase();

  /// 11. Trial Balance Report:
  /// Aggregates all journal lines and verifies Total Debits == Total Credits to the exact paisa
  Future<TrialBalanceReport> getTrialBalance() async {
    final db = await _db.database;
    final accounts = await db.query('accounting_accounts', orderBy: 'code ASC');

    final items = <TrialBalanceItem>[];
    int totalDebits = 0;
    int totalCredits = 0;

    for (final acc in accounts) {
      final code = acc['code'] as String;
      final name = acc['name'] as String;
      final type = acc['account_type'] as String;

      final res = await db.rawQuery('''
        SELECT 
          COALESCE(SUM(debit_paise), 0) as total_debits,
          COALESCE(SUM(credit_paise), 0) as total_credits
        FROM journal_lines
        WHERE account_code = ?
      ''', [code]);

      final debits = (res.first['total_debits'] as int?) ?? 0;
      final credits = (res.first['total_credits'] as int?) ?? 0;

      int netDebit = 0;
      int netCredit = 0;

      if (type == 'Asset' || type == 'Expense') {
        final net = debits - credits;
        if (net >= 0) {
          netDebit = net;
        } else {
          netCredit = -net;
        }
      } else {
        final net = credits - debits;
        if (net >= 0) {
          netCredit = net;
        } else {
          netDebit = -net;
        }
      }

      totalDebits += netDebit;
      totalCredits += netCredit;

      items.add(TrialBalanceItem(
        accountCode: code,
        accountName: name,
        accountType: type,
        debitBalancePaise: netDebit,
        creditBalancePaise: netCredit,
      ));
    }

    return TrialBalanceReport(
      items: items,
      totalDebitsPaise: totalDebits,
      totalCreditsPaise: totalCredits,
      isBalanced: totalDebits == totalCredits,
    );
  }

  /// 9. Daily Cashbook: All cash receipts and cash payments for a given date
  Future<List<Map<String, dynamic>>> getDailyCashbook(DateTime date) async {
    final db = await _db.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    return await db.rawQuery('''
      SELECT 
        t.*, 
        m.member_code, 
        m.full_name
      FROM transactions t
      JOIN members m ON t.member_id = m.id
      WHERE t.payment_mode = 'cash' 
        AND t.transaction_date LIKE ?
        AND t.is_reversed = 0
      ORDER BY t.created_at ASC
    ''', ['$dateStr%']);
  }

  /// 1. Member Register: All members with status, code, phone
  Future<List<Map<String, dynamic>>> getMemberRegister() async {
    final db = await _db.database;
    return await db.query('members', orderBy: 'member_code ASC');
  }

  /// 3. Savings Register: All active members with their ledger-derived savings balance
  Future<List<Map<String, dynamic>>> getSavingsRegister() async {
    final db = await _db.database;
    return await db.rawQuery('''
      SELECT 
        m.id, 
        m.member_code, 
        m.full_name,
        COALESCE(SUM(CASE WHEN t.transaction_type = 'savings_deposit' THEN t.amount_paise ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN t.transaction_type = 'savings_withdrawal' THEN t.amount_paise ELSE 0 END), 0) as balance_paise
      FROM members m
      LEFT JOIN transactions t ON m.id = t.member_id AND t.is_reversed = 0
      GROUP BY m.id
      ORDER BY m.member_code ASC
    ''');
  }

  /// 4. Loan Register: All loans with status, principal, issue date
  Future<List<Map<String, dynamic>>> getLoanRegister() async {
    final db = await _db.database;
    return await db.rawQuery('''
      SELECT 
        l.*, 
        m.member_code, 
        m.full_name
      FROM loans l
      JOIN members m ON l.member_id = m.id
      ORDER BY l.loan_code ASC
    ''');
  }

  /// 12. Audit History Report
  Future<List<Map<String, dynamic>>> getAuditHistory({int limit = 100}) async {
    final db = await _db.database;
    return await db.query('audit_logs', orderBy: 'created_at DESC', limit: limit);
  }

  /// 2. Individual Member Ledger
  Future<List<Map<String, dynamic>>> getMemberLedger(String memberId) async {
    final db = await _db.database;
    return await db.rawQuery('''
      SELECT t.*, m.member_code, m.full_name
      FROM transactions t
      JOIN members m ON t.member_id = m.id
      WHERE t.member_id = ? AND t.is_reversed = 0
      ORDER BY t.transaction_date ASC
    ''', [memberId]);
  }

  /// 5. Outstanding Principal Report
  Future<List<Map<String, dynamic>>> getOutstandingPrincipalReport() async {
    final db = await _db.database;
    return await db.rawQuery('''
      SELECT 
        l.loan_code,
        m.member_code,
        m.full_name,
        l.principal_paise,
        COALESCE(SUM(r.principal_portion_paise), 0) as paid_principal,
        (l.principal_paise - COALESCE(SUM(r.principal_portion_paise), 0)) as outstanding_principal,
        l.status
      FROM loans l
      JOIN members m ON l.member_id = m.id
      LEFT JOIN repayments r ON l.id = r.loan_id
      WHERE l.status IN ('Active', 'Partially Repaid')
      GROUP BY l.id
      ORDER BY l.loan_code ASC
    ''');
  }

  /// 6. Outstanding Interest Report
  Future<List<Map<String, dynamic>>> getOutstandingInterestReport() async {
    final db = await _db.database;
    final now = DateTime.now();
    final loans = await db.rawQuery('''
      SELECT l.*, m.member_code, m.full_name
      FROM loans l
      JOIN members m ON l.member_id = m.id
      WHERE l.status IN ('Active', 'Partially Repaid')
      ORDER BY l.loan_code ASC
    ''');

    final results = <Map<String, dynamic>>[];
    for (final l in loans) {
      final loanId = l['id'] as String;
      final principalPaise = l['principal_paise'] as int;
      final monthlyBps = l['monthly_interest_bps'] as int;

      final rep = await db.rawQuery(
        'SELECT COALESCE(SUM(principal_portion_paise), 0) as paid FROM repayments WHERE loan_id = ?',
        [loanId],
      );
      final paid = (rep.first['paid'] as int?) ?? 0;
      final currentPrincipal = principalPaise - paid;

      final lastRep = await db.query(
        'repayments',
        where: 'loan_id = ?',
        whereArgs: [loanId],
        orderBy: 'payment_date DESC',
        limit: 1,
      );
      final fromDate = lastRep.isNotEmpty
          ? DateTime.parse(lastRep.first['payment_date'] as String)
          : DateTime.parse(l['issue_date'] as String);
      final days = InterestCalculator.calculateElapsedDays(fromDate, now);
      final interest = InterestCalculator.calculateReducingInterestPaise(
        principalPaise: currentPrincipal,
        monthlyBps: monthlyBps,
        days: days > 0 ? days : 0,
      );

      results.add({
        'loan_code': l['loan_code'],
        'member_code': l['member_code'],
        'full_name': l['full_name'],
        'outstanding_principal': currentPrincipal,
        'accrued_interest': interest,
        'days': days,
        'rate_bps': monthlyBps,
      });
    }
    return results;
  }

  /// 7. Interest Collected Report
  Future<List<Map<String, dynamic>>> getInterestCollectedReport() async {
    final db = await _db.database;
    return await db.rawQuery('''
      SELECT 
        r.payment_date,
        l.loan_code,
        m.member_code,
        m.full_name,
        r.interest_portion_paise,
        r.total_paid_paise
      FROM repayments r
      JOIN loans l ON r.loan_id = l.id
      JOIN members m ON l.member_id = m.id
      JOIN transactions t ON r.transaction_id = t.id
      WHERE t.is_reversed = 0 AND r.interest_portion_paise > 0
      ORDER BY r.payment_date DESC
    ''');
  }

  /// 8. Repayment Report
  Future<List<Map<String, dynamic>>> getRepaymentReport() async {
    final db = await _db.database;
    return await db.rawQuery('''
      SELECT 
        r.*,
        l.loan_code,
        m.member_code,
        m.full_name,
        t.receipt_number,
        t.payment_mode
      FROM repayments r
      JOIN loans l ON r.loan_id = l.id
      JOIN members m ON l.member_id = m.id
      JOIN transactions t ON r.transaction_id = t.id
      WHERE t.is_reversed = 0
      ORDER BY r.payment_date DESC
    ''');
  }

  /// 10. Monthly Summary
  Future<List<Map<String, dynamic>>> getMonthlySummary([int? year]) async {
    final db = await _db.database;
    final targetYear = (year ?? DateTime.now().year).toString();
    return await db.rawQuery('''
      SELECT 
        SUBSTR(transaction_date, 1, 7) as month_str,
        SUM(CASE WHEN transaction_type = 'savings_deposit' THEN amount_paise ELSE 0 END) as deposits,
        SUM(CASE WHEN transaction_type = 'savings_withdrawal' THEN amount_paise ELSE 0 END) as withdrawals,
        SUM(CASE WHEN transaction_type = 'loan_disbursement' THEN amount_paise ELSE 0 END) as disbursements,
        SUM(CASE WHEN transaction_type = 'loan_repayment' THEN amount_paise ELSE 0 END) as repayments,
        COUNT(*) as total_tx_count
      FROM transactions
      WHERE is_reversed = 0 AND transaction_date LIKE ?
      GROUP BY SUBSTR(transaction_date, 1, 7)
      ORDER BY month_str DESC
    ''', ['$targetYear%']);
  }
}

