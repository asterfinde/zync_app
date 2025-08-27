// lib/features/auth/data/datasources/auth_remote_data_source_impl.dart

import 'package:firebase_auth/firebase_auth.dart' as firebase;
import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';
import 'auth_remote_data_source.dart';

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final firebase.FirebaseAuth firebaseAuth;

  AuthRemoteDataSourceImpl({required this.firebaseAuth});

  @override
  Future<UserModel> signInOrRegister({required String email, required String password}) async {
    try {
      final userCredential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user!;
      return UserModel(uid: user.uid, email: user.email!);
    } on firebase.FirebaseAuthException {
      // Si el login falla, intenta registrar
      try {
        final userCredential = await firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = userCredential.user!;
        return UserModel(uid: user.uid, email: user.email!);
      } on firebase.FirebaseAuthException catch (e) {
        throw ServerException(message: e.message);
      }
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = firebaseAuth.currentUser;
    if (user != null) {
      return UserModel(uid: user.uid, email: user.email!);
    }
    return null;
  }

  @override
  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }
}