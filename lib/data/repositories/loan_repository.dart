import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../domain/entities/loan.dart';
import '../../domain/services/accounting_engine.dart';

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
  Future<void> disburseLoan({
    required String loanId,
    required PaymentMode paymentMode,
    DateTime? disbursementDate,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    final disburseDate = disbursementDate ?? now;

    await db.transaction((txn) async {
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

      // 2. Record transaction
      final receiptNumber = 'DIS-${loan.loanCode}';
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
}
