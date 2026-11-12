import 'package:flutter_test/flutter_test.dart';
import 'package:sangh_ledger/data/repositories/member_repository.dart';
import 'package:sangh_ledger/domain/entities/member.dart';

void main() {
  group('Member Entity and Code Generation Tests', () {
    test('Member entity serialization and deserialization', () {
      final now = DateTime.now();
      final member = Member(
        id: 'uuid-123',
        organizationId: 'org-456',
        memberCode: 'SGH001',
        fullName: 'Ramesh Gowda',
        phone: '9876543210',
        address: 'Bangalore, Karnataka',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = member.toMap();
      expect(map['id'], 'uuid-123');
      expect(map['member_code'], 'SGH001');
      expect(map['is_active'], 1);

      final restored = Member.fromMap(map);
      expect(restored.fullName, 'Ramesh Gowda');
      expect(restored.phone, '9876543210');
      expect(restored.isActive, isTrue);
    });

    test('MemberRepository defines maxActiveMembers as 100', () {
      expect(MemberRepository.maxActiveMembers, 100);
    });
  });
}

