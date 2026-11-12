import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../domain/entities/member.dart';

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

    return await db.transaction<Member>((txn) async {
      // Fetch organization id
      final orgResults = await txn.query('organizations', limit: 1);
      final orgId = orgResults.isNotEmpty ? orgResults.first['id'] as String : 'org_default';

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
}
