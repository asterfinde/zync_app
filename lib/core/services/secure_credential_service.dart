// lib/core/services/secure_credential_service.dart

import 'dart:developer';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureCredentialService {
  // FlutterSecureStorage sin encryptedSharedPreferences usa Android Keystore
  // nativo (API 18+), compatible con minSdk 21 del proyecto.
  static const _storage = FlutterSecureStorage();
  static const _keyEmail = 'auth_email';
  static const _keyPassword = 'auth_password';

  static Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    try {
      await _storage.write(key: _keyEmail, value: email);
      await _storage.write(key: _keyPassword, value: password);
      log('[SecureCredentialService] ✅ Credenciales guardadas en Keystore');
    } catch (e) {
      log('[SecureCredentialService] ⚠️ Error guardando credenciales: $e');
    }
  }

  static Future<Map<String, String>?> getCredentials() async {
    try {
      final email = await _storage.read(key: _keyEmail);
      final password = await _storage.read(key: _keyPassword);
      if (email == null || password == null) return null;
      return {'email': email, 'password': password};
    } catch (e) {
      log('[SecureCredentialService] ⚠️ Error leyendo credenciales: $e');
      return null;
    }
  }

  static Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _keyEmail);
      await _storage.delete(key: _keyPassword);
      log('[SecureCredentialService] ✅ Credenciales eliminadas del Keystore');
    } catch (e) {
      log('[SecureCredentialService] ⚠️ Error eliminando credenciales: $e');
    }
  }
}
