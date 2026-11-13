import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../domain/services/accounting_engine.dart';
import '../../domain/services/auto_backup_coordinator.dart';

class TransactionItem {
  final String id;
  final String organizationId;
  final String memberId;
  final String memberCode;
  final String memberName;
  final String transactionType;
  final String paymentMode;
  final int amountPaise;
  final DateTime transactionDate;
  final String receiptNumber;
  final String? remarks;
  final bool isReversed;
  final String? reversalReason;

  const TransactionItem({
    required this.id,
    required this.organizationId,
    required this.memberId,
    required this.memberCode,
    required this.memberName,
    required this.transactionType,
    required this.paymentMode,
    required this.amountPaise,
    required this.transactionDate,
    required this.receiptNumber,
    this.remarks,
    required this.isReversed,
    this.reversalReason,
  });
}

class TransactionDetailInfo {
  final TransactionItem transaction;
  final List<Map<String, dynamic>> journalLines;
  final List<Map<String, dynamic>> auditLogs;

  const TransactionDetailInfo({
    required this.transaction,
    required this.journalLines,
    required this.auditLogs,
  });
}

class TransactionRepository {
  final AppDatabase _db;
  final AccountingEngine _accounting;
  static const uuid = Uuid();

  TransactionRepository({AppDatabase? db, AccountingEngine? accounting})
      : _db = db ?? AppDatabase(),
        _accounting = accounting ?? AccountingEngine(db: db);

  /// Fetches transactions with query search and filters
  Future<List<TransactionItem>> getTransactions({
    String? query,
    String? transactionType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _db.database;
    var sql = '''
      SELECT 
        t.*, 
        m.member_code, 
        m.full_name as member_name
      FROM transactions t
      LEFT JOIN members m ON t.member_id = m.id
      WHERE 1=1
    ''';
    var args = <dynamic>[];

    if (query != null && query.trim().isNotEmpty) {
      sql += ' AND (t.receipt_number LIKE ? OR m.full_name LIKE ? OR m.member_code LIKE ?)';
      final p = '%${query.trim()}%';
      args.addAll([p, p, p]);
    }

    if (transactionType != null && transactionType.isNotEmpty) {
      sql += ' AND t.transaction_type = ?';
      args.add(transactionType);
    }

    if (startDate != null) {
      sql += ' AND t.transaction_date >= ?';
      args.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      sql += ' AND t.transaction_date <= ?';
      args.add(endDate.toIso8601String());
    }

    sql += ' ORDER BY t.transaction_date DESC';

    final results = await db.rawQuery(sql, args);
    return results.map((row) {
      return TransactionItem(
        id: row['id'] as String,
        organizationId: (row['organization_id'] as String?) ?? '',
        memberId: (row['member_id'] as String?) ?? '',
        memberCode: (row['member_code'] as String?) ?? 'N/A',
        memberName: (row['member_name'] as String?) ?? 'Sangh General',
        transactionType: row['transaction_type'] as String,
        paymentMode: row['payment_mode'] as String,
        amountPaise: row['amount_paise'] as int,
        transactionDate: DateTime.parse(row['transaction_date'] as String),
        receiptNumber: row['receipt_number'] as String,
        remarks: row['remarks'] as String?,
        isReversed: (row['is_reversed'] as int) == 1,
        reversalReason: row['reversal_reason'] as String?,
      );
    }).toList();
  }

  /// Fetches a single transaction by receipt number
  Future<TransactionItem?> getTransactionByReceiptNumber(String receiptNumber) async {
    final db = await _db.database;
    final results = await db.rawQuery('''
      SELECT 
        t.*, 
        m.member_code, 
        m.full_name as member_name
      FROM transactions t
      LEFT JOIN members m ON t.member_id = m.id
      WHERE t.receipt_number = ?
      LIMIT 1
    ''', [receiptNumber]);

    if (results.isEmpty) return null;
    final row = results.first;
    return TransactionItem(
      id: row['id'] as String,
      organizationId: (row['organization_id'] as String?) ?? '',
      memberId: (row['member_id'] as String?) ?? '',
      memberCode: (row['member_code'] as String?) ?? 'N/A',
      memberName: (row['member_name'] as String?) ?? 'Sangh General',
      transactionType: row['transaction_type'] as String,
      paymentMode: row['payment_mode'] as String,
      amountPaise: row['amount_paise'] as int,
      transactionDate: DateTime.parse(row['transaction_date'] as String),
      receiptNumber: row['receipt_number'] as String,
      remarks: row['remarks'] as String?,
      isReversed: (row['is_reversed'] as int) == 1,
      reversalReason: row['reversal_reason'] as String?,
    );
  }

  /// Fetches transaction detail along with double-entry journal lines and audit logs
  Future<TransactionDetailInfo?> getTransactionDetails(String transactionId) async {
    final db = await _db.database;
    final txList = await getTransactions();
    final matches = txList.where((t) => t.id == transactionId).toList();
    if (matches.isEmpty) return null;
    final tx = matches.first;

    final entryResults = await db.query(
      'journal_entries',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );

    var journalLines = <Map<String, dynamic>>[];
    if (entryResults.isNotEmpty) {
      final entryId = entryResults.first['id'] as String;
      journalLines = await db.query(
        'journal_lines',
        where: 'journal_entry_id = ?',
        whereArgs: [entryId],
      );
    }

    final auditLogs = await db.query(
      'audit_logs',
      where: 'entity_id = ?',
      whereArgs: [transactionId],
    );

    return TransactionDetailInfo(
      transaction: tx,
      journalLines: journalLines,
      auditLogs: auditLogs,
    );
  }

  /// Atomic Reversal Workflow
  Future<void> reverseTransaction({
    required String transactionId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('Reversal reason is mandatory');
    }

    final db = await _db.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      // 1. Fetch transaction
      final txResults = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );
      if (txResults.isEmpty) throw StateError('Transaction not found');
      final tx = txResults.first;

      if ((tx['is_reversed'] as int) == 1) {
        throw StateError('This transaction has already been reversed');
      }

      // 2. Mark original transaction as reversed
      await txn.update(
        'transactions',
        {
          'is_reversed': 1,
          'reversal_reason': reason.trim(),
        },
        where: 'id = ?',
        whereArgs: [transactionId],
      );

      // 3. Find and reverse all journal entries for this transaction
      final entryResults = await txn.query(
        'journal_entries',
        where: 'transaction_id = ? AND is_reversal = 0',
        whereArgs: [transactionId],
      );

      for (final entry in entryResults) {
        final originalEntryId = entry['id'] as String;
        await _accounting.reverseJournalEntry(
          txn,
          originalEntryId: originalEntryId,
          reversalReason: reason.trim(),
          reversalDate: now,
        );
      }

      // If loan disbursement is reversed, revert loan status to Draft
      if (tx['transaction_type'] == 'loan_disbursement') {
        final receipt = tx['receipt_number'] as String;
        final loanCode = receipt.replaceFirst('DIS-', '');
        await txn.update(
          'loans',
          {
            'status': 'Draft',
            'updated_at': now.toIso8601String(),
          },
          where: 'loan_code = ?',
          whereArgs: [loanCode],
        );
      }

      // 4. Audit Log
      await txn.insert('audit_logs', {
        'id': uuid.v4(),
        'action': 'TRANSACTION_REVERSED',
        'entity_type': 'transaction',
        'entity_id': transactionId,
        'details_json': '{"reason": "$reason", "amountPaise": ${tx['amount_paise']}}',
        'created_at': now.toIso8601String(),
      });
    });
    AutoBackupCoordinator.triggerSilentBackup();
  }
}
