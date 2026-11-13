import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../domain/entities/loan.dart';
import '../../domain/services/accounting_engine.dart';

class LoanRepaymentItem {
  final String id;
  final String transactionId;
  final DateTime paymentDate;
  final int totalPaidPaise;
  final int interestPortionPaise;
  final int principalPortionPaise;
  final String receiptNumber;

  const LoanRepaymentItem({
    required this.id,
    required this.transactionId,
    required this.paymentDate,
    required this.totalPaidPaise,
    required this.interestPortionPaise,
    required this.principalPortionPaise,
    required this.receiptNumber,
  });
}

class LoanDetailData {
  final Loan loan;
  final String memberName;
  final String memberCode;
  final int totalRepaidPrincipalPaise;
  final int totalPaidInterestPaise;
  final int outstandingPrincipalPaise;
  final int repaymentsCount;
  final List<LoanRepaymentItem> repayments;

  const LoanDetailData({
    required this.loan,
    required this.memberName,
    required this.memberCode,
    required this.totalRepaidPrincipalPaise,
    required this.totalPaidInterestPaise,
    required this.outstandingPrincipalPaise,
    required this.repaymentsCount,
    required this.repayments,
  });
}

class LoanRepository {
  final AppDatabase _db;
  final AccountingEngine _accounting;
  static const uuid = Uuid();

  LoanRepository({AppDatabase? db, AccountingEngine? accounting})
      : _db = db ?? AppDatabase(),
        _accounting = accounting ?? AccountingEngine(db: db);

  /// Generates next sequential readable Loan ID (e.g. LN-2026-0001)
  Future<String> _generateLoanCode(DatabaseExecutor txn) async {
    final year = DateTime.now().year;
    final prefix = 'LN-$year-';
    final result = await txn.rawQuery(
      'SELECT loan_code FROM loans WHERE loan_code LIKE ? ORDER BY loan_code DESC LIMIT 1',
      ['$prefix%'],
    );

    if (result.isEmpty) {
      return '${prefix}0001';
    }
    final latest = result.first['loan_code'] as String;
    final numPart = int.tryParse(latest.replaceAll(prefix, '')) ?? 0;
    return '$prefix${(numPart + 1).toString().padLeft(4, '0')}';
  }

  /// Creates a new loan in Draft state
  Future<Loan> createLoanDraft({
    required String memberId,
    required int principalPaise,
    int monthlyInterestBps = 100, // 1% default
    int? durationMonths,
    DateTime? issueDate,
    DateTime? firstRepaymentDate,
    String? remarks,
  }) async {
    if (principalPaise <= 0) {
      throw ArgumentError('Principal amount must be greater than zero');
    }

    final db = await _db.database;
    final now = DateTime.now();
    final loanDate = issueDate ?? now;

    return await db.transaction<Loan>((txn) async {
      // Validate active member
      final memberResults = await txn.query(
        'members',
        where: 'id = ?',
        whereArgs: [memberId],
        limit: 1,
      );
      if (memberResults.isEmpty) throw StateError('Member not found');
      if ((memberResults.first['is_active'] as int) != 1) {
        throw StateError('Cannot create a loan for an inactive member');
      }

      final orgId = memberResults.first['organization_id'] as String;
      final loanCode = await _generateLoanCode(txn);
      final loanId = uuid.v4();

      final loan = Loan(
        id: loanId,
        organizationId: orgId,
        memberId: memberId,
        loanCode: loanCode,
        principalPaise: principalPaise,
        monthlyInterestBps: monthlyInterestBps,
        calculationMethod: 'reducing_balance',
        dayCountBasis: 365,
        issueDate: loanDate,
        durationMonths: durationMonths,
        firstRepaymentDate: firstRepaymentDate,
        status: 'Draft',
        remarks: remarks,
        createdAt: now,
        updatedAt: now,
      );

      await txn.insert('loans', loan.toMap());

      await txn.insert('audit_logs', {
        'id': uuid.v4(),
        'action': 'LOAN_DRAFT_CREATED',
        'entity_type': 'loan',
        'entity_id': loanId,
        'details_json': '{"loanCode": "$loanCode", "principalPaise": $principalPaise}',
        'created_at': now.toIso8601String(),
      });

      return loan;
    });
  }

  /// Confirms loan disbursement: Draft -> Active, posts accounting journal atomically
  Future<String> disburseLoan({
    required String loanId,
    required PaymentMode paymentMode,
    DateTime? disbursementDate,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    final disburseDate = disbursementDate ?? now;

    return await db.transaction<String>((txn) async {
      final loanResults = await txn.query('loans', where: 'id = ?', whereArgs: [loanId], limit: 1);
      if (loanResults.isEmpty) throw StateError('Loan not found');
      final loanData = loanResults.first;

      if (loanData['status'] != 'Draft') {
        throw StateError('Only Draft loans can be disbursed. Current: ${loanData['status']}');
      }

      final loan = Loan.fromMap(loanData);
      final transactionId = uuid.v4();
      final disbursementId = uuid.v4();

      // 1. Record disbursement record
      await txn.insert('loan_disbursements', {
        'id': disbursementId,
        'loan_id': loan.id,
        'amount_paise': loan.principalPaise,
        'payment_mode': paymentMode.name,
        'disbursement_date': disburseDate.toIso8601String(),
        'created_at': now.toIso8601String(),
      });

      // 2. Record transaction with guaranteed unique sequential receipt number
      final prevDisbursements = await txn.rawQuery(
        'SELECT COUNT(*) as count FROM transactions WHERE receipt_number LIKE ? OR receipt_number LIKE ?',
        ['DIS-${loan.loanCode}%', 'RCP-DIS-${loan.loanCode}%'],
      );
      final disCount = Sqflite.firstIntValue(prevDisbursements) ?? 0;
      final receiptNumber = disCount == 0
          ? 'RCP-DIS-${loan.loanCode}'
          : 'RCP-DIS-${loan.loanCode}-${disCount + 1}';

      await txn.insert('transactions', {
        'id': transactionId,
        'organization_id': loan.organizationId,
        'member_id': loan.memberId,
        'transaction_type': 'loan_disbursement',
        'payment_mode': paymentMode.name,
        'amount_paise': loan.principalPaise,
        'transaction_date': disburseDate.toIso8601String(),
        'receipt_number': receiptNumber,
        'remarks': 'Disbursement for loan ${loan.loanCode}',
        'is_reversed': 0,
        'created_at': now.toIso8601String(),
      });

      // 3. Post double-entry journal lines
      await _accounting.postLoanDisbursement(
        txn,
        transactionId: transactionId,
        date: disburseDate,
        amountPaise: loan.principalPaise,
        mode: paymentMode,
        loanCode: loan.loanCode,
      );

      // 4. Transition status to Active
      await txn.update(
        'loans',
        {
          'status': 'Active',
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [loan.id],
      );

      // 5. Audit log
      await txn.insert('audit_logs', {
        'id': uuid.v4(),
        'action': 'LOAN_DISBURSED',
        'entity_type': 'loan',
        'entity_id': loan.id,
        'details_json': '{"loanCode": "${loan.loanCode}", "mode": "${paymentMode.name}", "amountPaise": ${loan.principalPaise}}',
        'created_at': now.toIso8601String(),
      });

      return receiptNumber;
    });
  }

  /// Fetches all loans
  Future<List<Loan>> getLoans({String? memberId, String? status}) async {
    final db = await _db.database;
    var whereClauses = <String>[];
    var whereArgs = <dynamic>[];

    if (memberId != null) {
      whereClauses.add('member_id = ?');
      whereArgs.add(memberId);
    }
    if (status != null) {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final results = await db.query(
      'loans',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
    );

    return results.map((m) => Loan.fromMap(m)).toList();
  }

  /// Fetches a single loan by ID
  Future<Loan?> getLoanById(String loanId) async {
    final db = await _db.database;
    final results = await db.query('loans', where: 'id = ?', whereArgs: [loanId], limit: 1);
    if (results.isEmpty) return null;
    return Loan.fromMap(results.first);
  }

  /// Fetches rich details for a loan including member info, repayment history, and balances
  Future<LoanDetailData?> getLoanDetail(String loanId) async {
    final db = await _db.database;
    final loan = await getLoanById(loanId);
    if (loan == null) return null;

    final memberResults = await db.query('members', where: 'id = ?', whereArgs: [loan.memberId], limit: 1);
    final memberName = memberResults.isNotEmpty ? memberResults.first['full_name'] as String : 'Unknown';
    final memberCode = memberResults.isNotEmpty ? memberResults.first['member_code'] as String : '---';

    final repResults = await db.rawQuery('''
      SELECT 
        r.*,
        t.receipt_number
      FROM repayments r
      JOIN transactions t ON r.transaction_id = t.id
      WHERE r.loan_id = ? AND t.is_reversed = 0
      ORDER BY r.payment_date DESC
    ''', [loanId]);

    int totalPrincipalPaid = 0;
    int totalInterestPaid = 0;
    final repayments = <LoanRepaymentItem>[];

    for (final row in repResults) {
      final pPaid = row['principal_portion_paise'] as int;
      final iPaid = row['interest_portion_paise'] as int;
      totalPrincipalPaid += pPaid;
      totalInterestPaid += iPaid;

      repayments.add(LoanRepaymentItem(
        id: row['id'] as String,
        transactionId: row['transaction_id'] as String,
        paymentDate: DateTime.parse(row['payment_date'] as String),
        totalPaidPaise: row['total_paid_paise'] as int,
        interestPortionPaise: iPaid,
        principalPortionPaise: pPaid,
        receiptNumber: row['receipt_number'] as String,
      ));
    }

    final outstanding = loan.principalPaise - totalPrincipalPaid;

    return LoanDetailData(
      loan: loan,
      memberName: memberName,
      memberCode: memberCode,
      totalRepaidPrincipalPaise: totalPrincipalPaid,
      totalPaidInterestPaise: totalInterestPaid,
      outstandingPrincipalPaise: outstanding > 0 ? outstanding : 0,
      repaymentsCount: repayments.length,
      repayments: repayments,
    );
  }

  /// Reverses an accidental loan disbursement via balanced reversal journal entry:
  /// Debit: Cash (1001) / Bank (1002)
  /// Credit: Loan Principal Receivables (1101)
  /// Reverts loan status to Draft. Allowed ONLY if 0 repayments exist.
  Future<void> reverseDisbursement({
    required String loanId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('Reversal reason is mandatory');
    }
    final db = await _db.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      // 1. Fetch loan
      final loanResults = await txn.query('loans', where: 'id = ?', whereArgs: [loanId], limit: 1);
      if (loanResults.isEmpty) throw StateError('Loan not found');
      final loan = loanResults.first;
      final loanCode = loan['loan_code'] as String;

      if (loan['status'] != 'Active' && loan['status'] != 'Partially Repaid') {
        throw StateError('Only Active or Partially Repaid loans can have disbursement reversed');
      }

      // 2. Verify zero repayments made
      final repCount = await txn.rawQuery(
        'SELECT COUNT(*) as count FROM repayments WHERE loan_id = ?',
        [loanId],
      );
      final count = Sqflite.firstIntValue(repCount) ?? 0;
      if (count > 0) {
        throw StateError('Cannot reverse disbursement for a loan with existing repayments ($count repayments recorded)');
      }

      // 3. Find disbursement transaction
      final txResults = await txn.query(
        'transactions',
        where: "receipt_number = ? AND transaction_type = 'loan_disbursement' AND is_reversed = 0",
        whereArgs: ['DIS-$loanCode'],
        limit: 1,
      );
      if (txResults.isEmpty) {
        throw StateError('Disbursement transaction not found or already reversed');
      }
      final tx = txResults.first;
      final txId = tx['id'] as String;

      // 4. Mark transaction as reversed
      await txn.update(
        'transactions',
        {
          'is_reversed': 1,
          'reversal_reason': reason.trim(),
        },
        where: 'id = ?',
        whereArgs: [txId],
      );

      // 5. Reverse journal entry
      final journalResults = await txn.query(
        'journal_entries',
        where: 'transaction_id = ? AND is_reversal = 0',
        whereArgs: [txId],
      );
      for (final jEntry in journalResults) {
        final jEntryId = jEntry['id'] as String;
        await _accounting.reverseJournalEntry(
          txn,
          originalEntryId: jEntryId,
          reversalReason: reason.trim(),
          reversalDate: now,
        );
      }

      // 6. Revert loan status to 'Draft'
      await txn.update(
        'loans',
        {
          'status': 'Draft',
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [loanId],
      );

      // 7. Audit log
      await txn.insert('audit_logs', {
        'id': uuid.v4(),
        'action': 'LOAN_DISBURSEMENT_REVERSED',
        'entity_type': 'loan',
        'entity_id': loanId,
        'details_json': '{"loanCode": "$loanCode", "reason": "$reason"}',
        'created_at': now.toIso8601String(),
      });
    });
  }
}

