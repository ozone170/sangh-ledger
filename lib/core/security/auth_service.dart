import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../database/app_database.dart';
import 'crypto_utils.dart';

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final int? lockoutSecondsRemaining;

  const AuthResult.success()
      : isSuccess = true,
        errorMessage = null,
        lockoutSecondsRemaining = null;

  const AuthResult.failure(this.errorMessage, {this.lockoutSecondsRemaining})
      : isSuccess = false;
}

class AuthService {
  final AppDatabase _db;
  final LocalAuthentication _localAuth;

  AuthService({AppDatabase? db, LocalAuthentication? localAuth})
      : _db = db ?? AppDatabase(),
        _localAuth = localAuth ?? LocalAuthentication();

  /// Verifies administrator login with username and password
  Future<AuthResult> loginWithPassword({
    required String username,
    required String password,
  }) async {
    final db = await _db.database;
    final results = await db.query(
      'admins',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );

    if (results.isEmpty) {
      return const AuthResult.failure('Invalid credentials');
    }

    final admin = results.first;
    final failedAttempts = admin['failed_attempts'] as int? ?? 0;
    final lockedUntilStr = admin['locked_until'] as String?;

    // Check lockout status
    if (lockedUntilStr != null) {
      final lockedUntil = DateTime.tryParse(lockedUntilStr);
      if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
        final remaining = lockedUntil.difference(DateTime.now()).inSeconds;
        return AuthResult.failure(
          'Account locked due to multiple failed attempts.',
          lockoutSecondsRemaining: remaining,
        );
      }
    }

    final passwordHash = admin['password_hash'] as String;
    final isValid = await CryptoUtils.verifyPassword(password, passwordHash);

    if (isValid) {
      // Reset failed attempts on success
      await db.update(
        'admins',
        {'failed_attempts': 0, 'locked_until': null},
        where: 'id = ?',
        whereArgs: [admin['id']],
      );
      return const AuthResult.success();
    } else {
      final newFailed = failedAttempts + 1;
      String? newLockedUntil;
      int? lockoutSecs;

      if (newFailed >= 3) {
        // Exponential backoff: 30s * 2^(failed - 3)
        final power = (newFailed - 3).clamp(0, 5);
        lockoutSecs = 30 * (1 << power);
        newLockedUntil = DateTime.now().add(Duration(seconds: lockoutSecs)).toIso8601String();
      }

      await db.update(
        'admins',
        {
          'failed_attempts': newFailed,
          'locked_until': newLockedUntil,
        },
        where: 'id = ?',
        whereArgs: [admin['id']],
      );

      return AuthResult.failure(
        'Invalid password',
        lockoutSecondsRemaining: lockoutSecs,
      );
    }
  }

  /// Verifies administrator login with PIN
  Future<AuthResult> loginWithPin(String pin) async {
    final db = await _db.database;
    final results = await db.query('admins', limit: 1);
    if (results.isEmpty) return const AuthResult.failure('No administrator registered');

    final admin = results.first;
    final pinHash = admin['pin_hash'] as String?;
    if (pinHash == null || pinHash.isEmpty) {
      return const AuthResult.failure('PIN not configured');
    }

    final isValid = await CryptoUtils.verifyPassword(pin, pinHash);
    if (isValid) {
      return const AuthResult.success();
    }
    return const AuthResult.failure('Invalid PIN');
  }

  /// Attempts biometric authentication (fingerprint / face)
  Future<AuthResult> authenticateWithBiometrics({
    String reason = 'Authenticate to access Sangh Ledger',
  }) async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        return const AuthResult.failure('Biometric hardware not available on device');
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        return const AuthResult.success();
      }
      return const AuthResult.failure('Biometric authentication failed or was cancelled');
    } on PlatformException catch (e) {
      return AuthResult.failure('Biometric error: ${e.message}');
    }
  }

  /// Resets password using security recovery question and answer
  Future<bool> resetPasswordWithRecoveryQuestion({
    required String recoveryAnswer,
    required String newPassword,
  }) async {
    final db = await _db.database;
    final results = await db.query('admins', limit: 1);
    if (results.isEmpty) return false;

    final admin = results.first;
    final storedAnswerHash = admin['recovery_answer_hash'] as String;

    final isAnswerValid = await CryptoUtils.verifyPassword(
      recoveryAnswer.trim().toLowerCase(),
      storedAnswerHash,
    );

    if (!isAnswerValid) return false;

    final newHash = await CryptoUtils.hashPassword(newPassword);
    await db.update(
      'admins',
      {
        'password_hash': newHash,
        'failed_attempts': 0,
        'locked_until': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [admin['id']],
    );
    return true;
  }
}
