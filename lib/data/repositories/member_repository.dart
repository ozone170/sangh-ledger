import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../domain/entities/member.dart';
import '../../domain/services/auto_backup_coordinator.dart';

class MemberWithBalance {
  final Member member;
  final int savingsBalancePaise;
  final int loanPrincipalPaise;

  const MemberWithBalance({
    required this.member,
    required this.savingsBalancePaise,
    required this.loanPrincipalPaise,
  });
}

class MemberRepository {
  final AppDatabase _db;
  static const int maxActiveMembers = 100;

  MemberRepository({AppDatabase? db}) : _db = db ?? AppDatabase();

  /// Returns total count of currently active members
  Future<int> getActiveMembersCount(DatabaseExecutor txn) async {
    final result = await txn.rawQuery(
      'SELECT COUNT(*) as count FROM members WHERE is_active = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Generates the next sequential member code (e.g. SGH001, SGH002)
  Future<String> getNextMemberCode(DatabaseExecutor txn) async {
    final result = await txn.rawQuery(
      'SELECT member_code FROM members ORDER BY member_code DESC LIMIT 1',
    );
    if (result.isEmpty) {
      return 'SGH001';
    }
    final latestCode = result.first['member_code'] as String;
    final numberPart = int.tryParse(latestCode.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final nextNumber = numberPart + 1;
    return 'SGH${nextNumber.toString().padLeft(3, '0')}';
  }

  /// Adds a new member, enforcing the 100 active member cap
  Future<Member> addMember({
    required String fullName,
    required String phone,
    required String address,
    bool isActive = true,
  }) async {
    final db = await _db.database;
    const uuid = Uuid();
    final now = DateTime.now();

    final member = await db.transaction<Member>((txn) async {
      // Dynamically fetch or seed valid organization id
      final orgId = await _db.getActiveOrganizationId(txn);

      if (isActive) {
        final activeCount = await getActiveMembersCount(txn);
        if (activeCount >= maxActiveMembers) {
          throw StateError('Maximum limit of 100 active members reached');
        }
      }

      final memberCode = await getNextMemberCode(txn);
      final memberId = uuid.v4();

      final member = Member(
        id: memberId,
        organizationId: orgId,
        memberCode: memberCode,
        fullName: fullName.trim(),
        phone: phone.trim(),
        address: address.trim(),
        isActive: isActive,
        createdAt: now,
        updatedAt: now,
      );

      await txn.insert('members', member.toMap());

      // Automatically create linked savings account
      await txn.insert('savings_accounts', {
        'id': uuid.v4(),
        'organization_id': orgId,
        'member_id': memberId,
        'status': 'active',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      return member;
    });
    AutoBackupCoordinator.triggerSilentBackup();
    return member;
  }

  /// Updates member details
  Future<void> updateMember(Member member) async {
    final db = await _db.database;
    final now = DateTime.now();
    await db.update(
      'members',
      {
        'full_name': member.fullName.trim(),
        'phone': member.phone.trim(),
        'address': member.address.trim(),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [member.id],
    );
  }

  /// Toggles member active/inactive status with 100 active members enforcement
  Future<void> setMemberActiveStatus(String memberId, bool makeActive) async {
    final db = await _db.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      if (makeActive) {
        final activeCount = await getActiveMembersCount(txn);
        if (activeCount >= maxActiveMembers) {
          throw StateError('Maximum limit of 100 active members reached');
        }
      }
      await txn.update(
        'members',
        {
          'is_active': makeActive ? 1 : 0,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [memberId],
      );
    });
  }

  /// Fetches all active members ordered by member_code ASC (for dropdowns)
  Future<List<Member>> getActiveMembers() async {
    return getMembers(activeOnly: true);
  }

  /// Fetches members with optional active filter and search query
  Future<List<Member>> getMembers({bool? activeOnly, String? query}) async {
    final db = await _db.database;
    var whereClauses = <String>[];
    var whereArgs = <dynamic>[];

    if (activeOnly != null) {
      whereClauses.add('is_active = ?');
      whereArgs.add(activeOnly ? 1 : 0);
    }

    if (query != null && query.trim().isNotEmpty) {
      whereClauses.add('(full_name LIKE ? OR member_code LIKE ? OR phone LIKE ?)');
      final pattern = '%${query.trim()}%';
      whereArgs.addAll([pattern, pattern, pattern]);
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final results = await db.query(
      'members',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'member_code ASC',
    );

    return results.map((m) => Member.fromMap(m)).toList();
  }

  /// Gets member by ID
  Future<Member?> getMemberById(String id) async {
    final db = await _db.database;
    final results = await db.query(
      'members',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Member.fromMap(results.first);
  }

  /// Fetches members with live ledger-calculated savings and loan balances
  Future<List<MemberWithBalance>> getMembersWithBalances({bool? activeOnly, String? query}) async {
    final db = await _db.database;
    var whereClauses = <String>[];
    var whereArgs = <dynamic>[];

    if (activeOnly != null) {
      whereClauses.add('m.is_active = ?');
      whereArgs.add(activeOnly ? 1 : 0);
    }

    if (query != null && query.trim().isNotEmpty) {
      whereClauses.add('(m.full_name LIKE ? OR m.member_code LIKE ? OR m.phone LIKE ?)');
      final pattern = '%${query.trim()}%';
      whereArgs.addAll([pattern, pattern, pattern]);
    }

    final where = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final sql = '''
      SELECT 
        m.*,
        COALESCE((
          SELECT 
            SUM(CASE WHEN t.transaction_type = 'savings_deposit' THEN t.amount_paise ELSE 0 END) -
            SUM(CASE WHEN t.transaction_type = 'savings_withdrawal' THEN t.amount_paise ELSE 0 END)
          FROM transactions t
          WHERE t.member_id = m.id AND t.is_reversed = 0
        ), 0) as savings_balance,
        COALESCE((
          SELECT 
            SUM(l.principal_paise) - COALESCE((
              SELECT SUM(r.principal_portion_paise)
              FROM repayments r
              JOIN transactions tr ON r.transaction_id = tr.id
              WHERE r.loan_id = l.id AND tr.is_reversed = 0
            ), 0)
          FROM loans l
          WHERE l.member_id = m.id AND l.status IN ('Active', 'Partially Repaid')
        ), 0) as loan_principal
      FROM members m
      $where
      ORDER BY m.member_code ASC
    ''';

    final results = await db.rawQuery(sql, whereArgs.isNotEmpty ? whereArgs : null);

    return results.map((row) {
      final member = Member.fromMap(row);
      final savings = (row['savings_balance'] as int?) ?? 0;
      final loan = (row['loan_principal'] as int?) ?? 0;
      return MemberWithBalance(
        member: member,
        savingsBalancePaise: savings > 0 ? savings : 0,
        loanPrincipalPaise: loan > 0 ? loan : 0,
      );
    }).toList();
  }
}

