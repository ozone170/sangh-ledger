import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/security/crypto_utils.dart';

class OnboardingDraft {
  final int currentStep;
  final String sanghName;
  final String address;
  final String contactPhone;
  final String? registrationNumber;
  final String financialYearStart;
  final String? logoPath;
  final String username;
  final String password;
  final String? pin;
  final bool biometricEnabled;
  final String recoveryQuestion;
  final String recoveryAnswer;

  const OnboardingDraft({
    this.currentStep = 0,
    this.sanghName = '',
    this.address = '',
    this.contactPhone = '',
    this.registrationNumber,
    this.financialYearStart = '01-04', // 1st April
    this.logoPath,
    this.username = 'admin',
    this.password = '',
    this.pin,
    this.biometricEnabled = false,
    this.recoveryQuestion = 'What is the founding year of the Sangh?',
    this.recoveryAnswer = '',
  });

  OnboardingDraft copyWith({
    int? currentStep,
    String? sanghName,
    String? address,
    String? contactPhone,
    String? registrationNumber,
    String? financialYearStart,
    String? logoPath,
    String? username,
    String? password,
    String? pin,
    bool? biometricEnabled,
    String? recoveryQuestion,
    String? recoveryAnswer,
  }) {
    return OnboardingDraft(
      currentStep: currentStep ?? this.currentStep,
      sanghName: sanghName ?? this.sanghName,
      address: address ?? this.address,
      contactPhone: contactPhone ?? this.contactPhone,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      financialYearStart: financialYearStart ?? this.financialYearStart,
      logoPath: logoPath ?? this.logoPath,
      username: username ?? this.username,
      password: password ?? this.password,
      pin: pin ?? this.pin,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      recoveryQuestion: recoveryQuestion ?? this.recoveryQuestion,
      recoveryAnswer: recoveryAnswer ?? this.recoveryAnswer,
    );
  }

  Map<String, dynamic> toJson() => {
        'currentStep': currentStep,
        'sanghName': sanghName,
        'address': address,
        'contactPhone': contactPhone,
        'registrationNumber': registrationNumber,
        'financialYearStart': financialYearStart,
        'logoPath': logoPath,
        'username': username,
        'biometricEnabled': biometricEnabled,
        'recoveryQuestion': recoveryQuestion,
      };

  factory OnboardingDraft.fromJson(Map<String, dynamic> json) => OnboardingDraft(
        currentStep: json['currentStep'] as int? ?? 0,
        sanghName: json['sanghName'] as String? ?? '',
        address: json['address'] as String? ?? '',
        contactPhone: json['contactPhone'] as String? ?? '',
        registrationNumber: json['registrationNumber'] as String?,
        financialYearStart: json['financialYearStart'] as String? ?? '01-04',
        logoPath: json['logoPath'] as String?,
        username: json['username'] as String? ?? 'admin',
        biometricEnabled: json['biometricEnabled'] as bool? ?? false,
        recoveryQuestion: json['recoveryQuestion'] as String? ?? 'What is the founding year of the Sangh?',
      );
}

class OnboardingNotifier extends StateNotifier<OnboardingDraft> {
  static const String _draftKey = 'sangh_ledger_onboarding_draft';
  final FlutterSecureStorage _storage;
  final AppDatabase _db;

  OnboardingNotifier(this._storage, this._db) : super(const OnboardingDraft()) {
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    try {
      final jsonStr = await _storage.read(key: _draftKey);
      if (jsonStr != null) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = OnboardingDraft.fromJson(map);
      }
    } catch (_) {}
  }

  Future<void> saveStep(OnboardingDraft draft) async {
    state = draft;
    try {
      await _storage.write(key: _draftKey, value: jsonEncode(draft.toJson()));
    } catch (_) {}
  }

  Future<void> commitOrganizationSetup() async {
    final db = await _db.database;
    const uuid = Uuid();
    final now = DateTime.now().toIso8601String();

    final orgId = uuid.v4();
    final adminId = uuid.v4();

    final passwordHash = await CryptoUtils.hashPassword(state.password);
    final pinHash = (state.pin != null && state.pin!.isNotEmpty)
        ? await CryptoUtils.hashPassword(state.pin!)
        : null;
    final recoveryAnswerHash = await CryptoUtils.hashPassword(
      state.recoveryAnswer.trim().toLowerCase(),
    );

    await db.transaction((txn) async {
      // 0. Remove any uninitialized or default dummy organization rows
      await txn.delete('organizations', where: "is_initialized = 0 OR id = 'org_default_sangh'");

      // 1. Create Organization
      await txn.insert('organizations', {
        'id': orgId,
        'name': state.sanghName.trim(),
        'logo_path': state.logoPath,
        'address': state.address.trim(),
        'contact_phone': state.contactPhone.trim(),
        'registration_number': state.registrationNumber?.trim(),
        'financial_year_start': state.financialYearStart,
        'currency': 'INR',
        'monthly_interest_bps': 100,
        'max_members': 100,
        'is_initialized': 1,
        'created_at': now,
        'updated_at': now,
      });

      // 2. Create Administrator
      await txn.insert('admins', {
        'id': adminId,
        'organization_id': orgId,
        'username': state.username.trim(),
        'password_hash': passwordHash,
        'pin_hash': pinHash,
        'biometric_enabled': state.biometricEnabled ? 1 : 0,
        'recovery_question': state.recoveryQuestion,
        'recovery_answer_hash': recoveryAnswerHash,
        'failed_attempts': 0,
        'locked_until': null,
        'created_at': now,
        'updated_at': now,
      });

      // 3. Mark app initialization in app_settings
      await txn.insert('app_settings', {
        'key': 'is_initialized',
        'value': 'true',
        'updated_at': now,
      });
    });

    // Store admin password securely for zero-touch silent auto-backups
    try {
      await _storage.write(key: 'admin_backup_password', value: state.password);
    } catch (_) {}

    // Clear draft after successful commit
    await _storage.delete(key: _draftKey);
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingDraft>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final db = ref.watch(appDatabaseProvider);
  return OnboardingNotifier(storage, db);
});

