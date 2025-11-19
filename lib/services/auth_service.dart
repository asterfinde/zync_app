// lib/services/auth_service.dart

import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/domain/entities/user.dart' as app;

/// AuthService - Servicio simplificado para autenticación
/// Reemplaza: AuthRepository, AuthDataSource, GetCurrentUser, SignInOrRegister, SignOut
class AuthService {
  final firebase.FirebaseAuth _auth = firebase.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtiene el usuario actual desde Firestore
  /// Retorna null si no hay usuario autenticado
  Future<app.User?> getCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        log('[AuthService] No hay usuario autenticado');
        return null;
      }

      log('[AuthService] Obteniendo datos de Firestore para: ${firebaseUser.uid}');
      final doc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!doc.exists) {
        log('[AuthService] ⚠️ Usuario no existe en Firestore: ${firebaseUser.uid}');
        return null;
      }

      final data = doc.data()!;
      return app.User(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: data['name'] ?? '',
        nickname: data['nickname'] ?? '',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
    } catch (e) {
      log('[AuthService] ❌ Error obteniendo usuario: $e');
      throw Exception('Error obteniendo usuario: $e');
    }
  }

  /// Inicia sesión o registra un usuario
  /// Si el usuario no existe en Firestore, lo crea
  Future<app.User> signInOrRegister({
    required String email,
    required String password,
    String nickname = '',
  }) async {
    try {
      log('[AuthService] Intentando signInOrRegister para: $email');

      // Intentar login primero
      firebase.UserCredential? userCredential;
      try {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        log('[AuthService] ✅ Login exitoso para: $email');
      } on firebase.FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          // Usuario no existe, registrar
          log('[AuthService] Usuario no existe, registrando...');
          userCredential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          log('[AuthService] ✅ Registro exitoso para: $email');
        } else {
          throw Exception('Error de autenticación: ${e.message}');
        }
      }

      final firebaseUser = userCredential.user!;

      // Verificar si el usuario existe en Firestore
      final doc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!doc.exists) {
        // Crear usuario en Firestore
        log('[AuthService] Creando usuario en Firestore...');
        final now = DateTime.now();
        await _firestore.collection('users').doc(firebaseUser.uid).set({
          'email': email,
          'name': nickname.isNotEmpty ? nickname : email.split('@')[0],
          'nickname': nickname.isNotEmpty ? nickname : email.split('@')[0],
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });

        return app.User(
          uid: firebaseUser.uid,
          email: email,
          name: nickname.isNotEmpty ? nickname : email.split('@')[0],
          nickname: nickname.isNotEmpty ? nickname : email.split('@')[0],
          createdAt: now,
          updatedAt: now,
        );
      }

      // Usuario ya existe, retornar datos de Firestore
      final data = doc.data()!;
      return app.User(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? email,
        name: data['name'] ?? '',
        nickname: data['nickname'] ?? '',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
    } catch (e) {
      log('[AuthService] ❌ Error en signInOrRegister: $e');
      throw Exception('Error de autenticación: $e');
    }
  }

  /// Cierra sesión del usuario actual
  Future<void> signOut() async {
    try {
      log('[AuthService] Cerrando sesión...');
      await _auth.signOut();
      log('[AuthService] ✅ Sesión cerrada');
    } catch (e) {
      log('[AuthService] ❌ Error cerrando sesión: $e');
      throw Exception('Error cerrando sesión: $e');
    }
  }

  /// Stream de cambios de autenticación
  Stream<firebase.User?> get authStateChanges => _auth.authStateChanges();
}

// ============================================================================
// RIVERPOD PROVIDER
// ============================================================================

/// Provider para AuthService
/// Reemplaza GetIt (sl<GetCurrentUser>, sl<SignInOrRegister>, sl<SignOut>)
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});