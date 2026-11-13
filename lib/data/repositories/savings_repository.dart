import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../domain/services/accounting_engine.dart';
import '../../domain/services/auto_backup_coordinator.dart';

class SavingsRepository {
  final AppDatabase _db;
  final AccountingEngine _accounting;
  static const uuid = Uuid();

  SavingsRepository({AppDatabase? db, AccountingEngine? accounting})
      : _db = db ?? AppDatabase(),
        _accounting = accounting ?? AccountingEngine(db: db);

  /// Generates next sequential receipt number (e.g. RCP-2026-0001)
  Future<String> _generateReceiptNumber(DatabaseExecutor txn) async {
    final year = DateTime.now().year;
    final prefix = 'RCP-$year-';
    final result = await txn.rawQuery(
      'SELECT receipt_number FROM transactions WHERE receipt_number LIKE ? ORDER BY receipt_number DESC LIMIT 1',
      ['$prefix%'],
    );

    if (result.isEmpty) {
      return '${prefix}0001';
    }
    final latest = result.first['receipt_number'] as String;
    final numPart = int.tryParse(latest.replaceAll(prefix, '')) ?? 0;
    return '$prefix${(numPart + 1).toString().padLeft(4, '0')}';
  }

  /// Records a random or regular savings deposit atomically
  Future<String> recordDeposit({
    required String memberId,
    required int amountPaise,
    required PaymentMode paymentMode,
    String? remarks,
    DateTime? date,
  }) async {
    if (amountPaise <= 0) {
      throw ArgumentError('Deposit amount must be greater than zero');
    }

    final db = await _db.database;
    final transactionDate = date ?? DateTime.now();

    final receipt = await db.transaction<String>((txn) async {
      // 1. Validate active member
      final memberResults = await txn.query(
        'members',
        where: 'id = ?',
        whereArgs: [memberId],
        limit: 1,
      );
      if (memberResults.isEmpty) throw StateError('Member not found');
      final member = memberResults.first;
      if ((member['is_active'] as int) != 1) {
        throw StateError('Cannot deposit to an inactive member');
      }

      final orgId = member['organization_id'] as String;
      final memberCode = member['member_code'] as String;
      final receiptNumber = await _generateReceiptNumber(txn);
      final transactionId = uuid.v4();

      // 2. Insert transaction
      await txn.insert('transactions', {
        'id': transactionId,
        'organization_id': orgId,
        'member_id': memberId,
        'transaction_type': 'savings_deposit',
        'payment_mode': paymentMode.name,
        'amount_paise': amountPaise,
        'transaction_date': transactionDate.toIso8601String(),
        'receipt_number': receiptNumber,
        'remarks': remarks ?? 'Savings deposit',
        'is_reversed': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 3. Post double-entry journal lines
      await _accounting.postSavingsDeposit(
        txn,
        transactionId: transactionId,
        date: transactionDate,
        amountPaise: amountPaise,
        mode: paymentMode,
        memberCode: memberCode,
      );

      // 4. Audit log
      await txn.insert('audit_logs', {
        'id': uuid.v4(),
        'action': 'SAVINGS_DEPOSIT',
        'entity_type': 'transaction',
        'entity_id': transactionId,
        'details_json': '{"memberCode": "$memberCode", "amountPaise": $amountPaise, "mode": "${paymentMode.name}"}',
        'created_at': DateTime.now().toIso8601String(),
      });

      return receiptNumber;
    });
    AutoBackupCoordinator.triggerSilentBackup();
    return receipt;
  }

  /// Records an authorized savings withdrawal with strict available balance validation
  Future<String> recordWithdrawal({
    required String memberId,
    required int amountPaise,
    required PaymentMode paymentMode,
    required String reason,
    DateTime? date,
  }) async {
    if (amountPaise <= 0) {
      throw ArgumentError('Withdrawal amount must be greater than zero');
    }

    final db = await _db.database;
    final transactionDate = date ?? DateTime.now();

    final receipt = await db.transaction<String>((txn) async {
      // 1. Validate active member
      final memberResults = await txn.query(
        'members',
        where: 'id = ?',
        whereArgs: [memberId],
        limit: 1,
      );
      if (memberResults.isEmpty) throw StateError('Member not found');
      final member = memberResults.first;
      if ((member['is_active'] as int) != 1) {
        throw StateError('Cannot withdraw for an inactive member');
      }

      // 2. Validate sufficient balance from transactions
      final balanceResult = await txn.rawQuery('''
        SELECT 
          COALESCE(SUM(CASE WHEN transaction_type = 'savings_deposit' THEN amount_paise ELSE 0 END), 0) -
          COALESCE(SUM(CASE WHEN transaction_type = 'savings_withdrawal' THEN amount_paise ELSE 0 END), 0) as balance
        FROM transactions
        WHERE member_id = ? AND is_reversed = 0
      ''', [memberId]);

      final availableBalancePaise = (balanceResult.first['balance'] as int?) ?? 0;
      if (amountPaise > availableBalancePaise) {
        throw StateError(
          'Insufficient savings balance. Available: $availableBalancePaise paise, Requested: $amountPaise paise',
        );
      }

      final orgId = member['organization_id'] as String;
      final memberCode = member['member_code'] as String;
      final receiptNumber = await _generateReceiptNumber(txn);
      final transactionId = uuid.v4();

      // 3. Insert transaction
      await txn.insert('transactions', {
        'id': transactionId,
        'organization_id': orgId,
        'member_id': memberId,
        'transaction_type': 'savings_withdrawal',
        'payment_mode': paymentMode.name,
        'amount_paise': amountPaise,
        'transaction_date': transactionDate.toIso8601String(),
        'receipt_number': receiptNumber,
        'remarks': reason,
        'is_reversed': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 4. Post double-entry journal lines
      await _accounting.postSavingsWithdrawal(
        txn,
        transactionId: transactionId,
        date: transactionDate,
        amountPaise: amountPaise,
        mode: paymentMode,
        memberCode: memberCode,
      );

      // 5. Audit log
      await txn.insert('audit_logs', {
        'id': uuid.v4(),
        'action': 'SAVINGS_WITHDRAWAL',
        'entity_type': 'transaction',
        'entity_id': transactionId,
        'details_json': '{"memberCode": "$memberCode", "amountPaise": $amountPaise, "reason": "$reason"}',
        'created_at': DateTime.now().toIso8601String(),
      });

      return receiptNumber;
    });
    AutoBackupCoordinator.triggerSilentBackup();
    return receipt;
  }

  /// Returns total savings liabilities across all active members from live journal lines (2001)
  Future<int> getTotalSavingsLiabilities() async {
    return _accounting.getAccountBalance(AccountingEngine.codeMemberSavingsLiability);
  }

  /// Returns savings transactions (deposits & withdrawals) optionally filtered by memberId
  Future<List<Map<String, dynamic>>> getSavingsTransactions({String? memberId}) async {
    final db = await _db.database;
    var sql = '''
      SELECT 
        t.*,
        m.member_code,
        m.full_name as member_name
      FROM transactions t
      JOIN members m ON t.member_id = m.id
      WHERE t.transaction_type IN ('savings_deposit', 'savings_withdrawal')
    ''';
    var args = <dynamic>[];
    if (memberId != null) {
      sql += ' AND t.member_id = ?';
      args.add(memberId);
    }
    sql += ' ORDER BY t.transaction_date DESC';
    return db.rawQuery(sql, args);
  }
}

