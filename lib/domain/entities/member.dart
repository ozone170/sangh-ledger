class Member {
  final String id;
  final String organizationId;
  final String memberCode;
  final String fullName;
  final String phone;
  final String address;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Member({
    required this.id,
    required this.organizationId,
    required this.memberCode,
    required this.fullName,
    required this.phone,
    required this.address,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Member copyWith({
    String? id,
    String? organizationId,
    String? memberCode,
    String? fullName,
    String? phone,
    String? address,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Member(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      memberCode: memberCode ?? this.memberCode,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'organization_id': organizationId,
        'member_code': memberCode,
        'full_name': fullName,
        'phone': phone,
        'address': address,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Member.fromMap(Map<String, dynamic> map) => Member(
        id: map['id'] as String,
        organizationId: map['organization_id'] as String,
        memberCode: map['member_code'] as String,
        fullName: map['full_name'] as String,
        phone: map['phone'] as String,
        address: map['address'] as String,
        isActive: (map['is_active'] as int) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
