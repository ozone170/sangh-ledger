import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../domain/services/accounting_engine.dart';
import '../../domain/services/interest_calculator.dart';

class RepaymentAllocation {
  final int totalPaidPaise;
  final int accruedInterestPaise;
  final int interestPaidPaise;
  final int principalPaidPaise;
  final int remainingPrincipalPaise;
  final int remainingInterestPaise;
  final int elapsedDays;

  const RepaymentAllocation({
    required this.totalPaidPaise,
    required this.accruedInterestPaise,
    required this.interestPaidPaise,
    required this.principalPaidPaise,
    required this.remainingPrincipalPaise,
    required this.remainingInterestPaise,
    required this.elapsedDays,
  });
}

class RepaymentRepository {
  final AppDatabase _db;
  final AccountingEngine _accounting;
  static const uuid = Uuid();

  RepaymentRepository({AppDatabase? db, AccountingEngine? accounting})
      : _db = db ?? AppDatabase(),
        _accounting = accounting ?? AccountingEngine(db: db);

  /// Computes dynamic accrued interest and allocation preview up to paymentDate
  Future<RepaymentAllocation> previewAllocation({
    required String loanId,
    required DateTime paymentDate,
    required int paymentAmountPaise,
  }) async {
    final db = await _db.database;

    final loanResults = await db.query('loans', where: 'id = ?', whereArgs: [loanId], limit: 1);
    if (loanResults.isEmpty) throw StateError('Loan not found');
    final loan = loanResults.first;

    final principalPaise = loan['principal_paise'] as int;
    final monthlyBps = loan['monthly_interest_bps'] as int;

    // 1. Calculate already paid principal
    final repResult = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(principal_portion_paise), 0) as paid_principal
      FROM repayments
      WHERE loan_id = ?
    ''', [loanId]);

    final totalPaidPrincipal = (repResult.first['paid_principal'] as int?) ?? 0;

    final currentOutstandingPrincipal = principalPaise - totalPaidPrincipal;

    // 2. Determine last accrual/payment date
    final lastRepayment = await db.query(
      'repayments',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'payment_date DESC',
      limit: 1,
    );

    final fromDate = lastRepayment.isNotEmpty
        ? DateTime.parse(lastRepayment.first['payment_date'] as String)
        : DateTime.parse(loan['issue_date'] as String);

    final elapsedDays = InterestCalculator.calculateElapsedDays(fromDate, paymentDate);
    final newlyAccruedInterest = InterestCalculator.calculateReducingInterestPaise(
      principalPaise: currentOutstandingPrincipal,
      monthlyBps: monthlyBps,
      days: daysToAccrue(elapsedDays),
    );

    // Total unpaid interest = newly accrued + previous unpaid interest
    // For reducing balance, each interval computes interest on current outstanding principal
    final totalUnpaidInterest = newlyAccruedInterest;

    final maxPayable = currentOutstandingPrincipal + totalUnpaidInterest;
    if (paymentAmountPaise > maxPayable) {
      throw ArgumentError(
        'Payment amount exceeds total outstanding obligation. '
        'Max payable: $maxPayable paise, Entered: $paymentAmountPaise paise',
      );
    }

    // Allocation Order: Interest FIRST, Principal SECOND
    int interestPaid = 0;
    int principalPaid = 0;

    if (paymentAmountPaise <= totalUnpaidInterest) {
      interestPaid = paymentAmountPaise;
      principalPaid = 0;
    } else {
      interestPaid = totalUnpaidInterest;
      principalPaid = paymentAmountPaise - totalUnpaidInterest;
    }

    final remainingPrincipal = currentOutstandingPrincipal - principalPaid;
    final remainingInterest = totalUnpaidInterest - interestPaid;

    return RepaymentAllocation(
      totalPaidPaise: paymentAmountPaise,
      accruedInterestPaise: totalUnpaidInterest,
      interestPaidPaise: interestPaid,
      principalPaidPaise: principalPaid,
      remainingPrincipalPaise: remainingPrincipal,
      remainingInterestPaise: remainingInterest,
      elapsedDays: elapsedDays,
    );
  }

  static int daysToAccrue(int elapsed) => elapsed > 0 ? elapsed : 0;

  /// Posts repayment, allocations, interest accrual, and double-entry journal atomically
  Future<String> recordRepayment({
    required String loanId,
    required int amountPaise,
    required PaymentMode paymentMode,
    required DateTime paymentDate,
    String? remarks,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();

    return await db.transaction<String>((txn) async {
      // 1. Fetch loan details
      final loanResults = await txn.query('loans', where: 'id = ?', whereArgs: [loanId], limit: 1);
      if (loanResults.isEmpty) throw StateError('Loan not found');
      final loan = loanResults.first;
      final loanCode = loan['loan_code'] as String;
      final memberId = loan['member_id'] as String;
      final orgId = loan['organization_id'] as String;

      // 2. Compute allocation
      final preview = await previewAllocation(
        loanId: loanId,
        paymentDate: paymentDate,
        paymentAmountPaise: amountPaise,
      );

      final transactionId = uuid.v4();
      final repaymentId = uuid.v4();
      final receiptNumber = 'REP-$loanCode-${now.millisecondsSinceEpoch % 100000}';

      // 3. Record transaction
      await txn.insert('transactions', {
        'id': transactionId,
        'organization_id': orgId,
        'member_id': memberId,
        'transaction_type': 'loan_repayment',
        'payment_mode': paymentMode.name,
        'amount_paise': amountPaise,
        'transaction_date': paymentDate.toIso8601String(),
        'receipt_number': receiptNumber,
        'remarks': remarks ?? 'Repayment for $loanCode',
        'is_reversed': 0,
        'created_at': now.toIso8601String(),
      });

      // 4. Record repayment
      await txn.insert('repayments', {
        'id': repaymentId,
        'transaction_id': transactionId,
        'loan_id': loanId,
        'payment_date': paymentDate.toIso8601String(),
        'total_paid_paise': amountPaise,
        'interest_portion_paise': preview.interestPaidPaise,
        'principal_portion_paise': preview.principalPaidPaise,
        'created_at': now.toIso8601String(),
      });

      // 5. Post interest accrual if interest was accrued
      if (preview.accruedInterestPaise > 0) {
        await _accounting.postInterestAccrual(
          txn,
          transactionId: transactionId,
          date: paymentDate,
          amountPaise: preview.accruedInterestPaise,
          loanCode: loanCode,
        );
      }

      // 6. Post interest collection (if interest paid > 0)
      if (preview.interestPaidPaise > 0) {
        await _accounting.postInterestCollection(
          txn,
          transactionId: transactionId,
          date: paymentDate,
          amountPaise: preview.interestPaidPaise,
          mode: paymentMode,
          loanCode: loanCode,
        );
      }

      // 7. Post principal repayment (if principal paid > 0)
      if (preview.principalPaidPaise > 0) {
        await _accounting.postPrincipalRepayment(
          txn,
          transactionId: transactionId,
          date: paymentDate,
          amountPaise: preview.principalPaidPaise,
          mode: paymentMode,
          loanCode: loanCode,
        );
      }

      // 8. Update loan status to Closed if fully settled
      if (preview.remainingPrincipalPaise == 0 && preview.remainingInterestPaise == 0) {
        await txn.update(
          'loans',
          {
            'status': 'Closed',
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [loanId],
        );
      } else {
        await txn.update(
          'loans',
          {
            'status': 'Partially Repaid',
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [loanId],
        );
      }

      // 9. Audit log
      await txn.insert('audit_logs', {
        'id': uuid.v4(),
        'action': 'LOAN_REPAYMENT',
        'entity_type': 'repayment',
        'entity_id': repaymentId,
        'details_json': '{"loanCode": "$loanCode", "totalPaid": $amountPaise, "interest": ${preview.interestPaidPaise}, "principal": ${preview.principalPaidPaise}}',
        'created_at': now.toIso8601String(),
      });

      return receiptNumber;
    });
  }
}
