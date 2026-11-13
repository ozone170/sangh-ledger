import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../security/crypto_utils.dart';

class DatabaseKeyManager {
  static const String _keyName = 'sangh_ledger_sqlcipher_256bit_key';
  final FlutterSecureStorage _storage;

  DatabaseKeyManager({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: false,
              ),
            );

  /// Retrieves the existing 256-bit key or securely generates and stores a new one,
  /// with a retry-once fallback on transient Keystore initialization hiccups during cold boot.
  Future<String> getOrCreateEncryptionKey() async {
    try {
      return await _fetchOrGenerateKey();
    } catch (_) {
      // Retry once for transient Keystore initialization hiccups during cold boot
      await Future.delayed(const Duration(milliseconds: 300));
      return await _fetchOrGenerateKey();
    }
  }

  Future<String> _fetchOrGenerateKey() async {
    final existingKey = await _storage.read(key: _keyName);
    if (existingKey != null && existingKey.isNotEmpty) {
      return existingKey;
    }

    // Generate a 256-bit (32 bytes) cryptographically secure key
    final randomKeyBytes = CryptoUtils.generateRandomBytes(32);
    final keyHex = base64Url.encode(randomKeyBytes);

    await _storage.write(key: _keyName, value: keyHex);
    return keyHex;
  }

  /// Checks whether an encryption key already exists with retry-once fallback
  Future<bool> hasKey() async {
    try {
      final key = await _storage.read(key: _keyName);
      return key != null && key.isNotEmpty;
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 200));
      final key = await _storage.read(key: _keyName);
      return key != null && key.isNotEmpty;
    }
  }

  /// Deletes the encryption key (used during hard database reset/re-initialization)
  Future<void> deleteKey() async {
    await _storage.delete(key: _keyName);
  }
}
