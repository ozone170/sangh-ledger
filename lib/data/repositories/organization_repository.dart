import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';

class OrganizationInfo {
  final String id;
  final String name;
  final String? logoPath;
  final String address;
  final String contactPhone;
  final String? registrationNumber;
  final String financialYearStart;
  final String currency;
  final int monthlyInterestBps;

  const OrganizationInfo({
    required this.id,
    required this.name,
    this.logoPath,
    required this.address,
    required this.contactPhone,
    this.registrationNumber,
    required this.financialYearStart,
    required this.currency,
    required this.monthlyInterestBps,
  });

  factory OrganizationInfo.fromMap(Map<String, dynamic> map) {
    return OrganizationInfo(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Sangh Ledger',
      logoPath: map['logo_path'] as String?,
      address: map['address'] as String? ?? 'Karnataka, India',
      contactPhone: map['contact_phone'] as String? ?? '',
      registrationNumber: map['registration_number'] as String?,
      financialYearStart: map['financial_year_start'] as String? ?? '01-04',
      currency: map['currency'] as String? ?? 'INR',
      monthlyInterestBps: map['monthly_interest_bps'] as int? ?? 100,
    );
  }
}

class OrganizationRepository {
  final AppDatabase _db;

  OrganizationRepository({AppDatabase? db}) : _db = db ?? AppDatabase();

  Future<OrganizationInfo?> getOrganization() async {
    try {
      final db = await _db.database;
      final results = await db.query('organizations', limit: 1);
      if (results.isNotEmpty) {
        return OrganizationInfo.fromMap(results.first);
      }
    } catch (_) {}
    return null;
  }

  Future<void> updateLogoPath(String logoPath) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'organizations',
      {'logo_path': logoPath, 'updated_at': now},
    );
  }

  Future<void> updateProfile({
    required String name,
    required String address,
    required String contactPhone,
    String? registrationNumber,
    String? logoPath,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final data = <String, dynamic>{
      'name': name.trim(),
      'address': address.trim(),
      'contact_phone': contactPhone.trim(),
      'registration_number': registrationNumber?.trim(),
      'updated_at': now,
    };
    if (logoPath != null) {
      data['logo_path'] = logoPath;
    }
    await db.update('organizations', data);
  }
}

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepository();
});

final organizationProvider = FutureProvider<OrganizationInfo?>((ref) async {
  final repo = ref.watch(organizationRepositoryProvider);
  return repo.getOrganization();
});

