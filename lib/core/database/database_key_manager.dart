import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../security/crypto_utils.dart';

class DatabaseKeyManager {
  static const String _keyName = 'sangh_ledger_sqlcipher_256bit_key';
  final FlutterSecureStorage _storage;

  DatabaseKeyManager({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Retrieves the existing 256-bit key or securely generates and stores a new one
  Future<String> getOrCreateEncryptionKey() async {
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

  /// Checks whether an encryption key already exists
  Future<bool> hasKey() async {
    final key = await _storage.read(key: _keyName);
    return key != null && key.isNotEmpty;
  }
}

