import '../../core/database/app_database.dart';

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
}
