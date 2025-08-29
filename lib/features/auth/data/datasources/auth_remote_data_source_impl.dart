import 'dart:developer'; // Añadido para logging
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import '../../../../core/error/exceptions.dart';
import '../../data/models/user_model.dart';
import 'auth_remote_data_source.dart';

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final firebase.FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  AuthRemoteDataSourceImpl({
    required this.firebaseAuth,
    required this.firestore,
  });

  @override
  Future<UserModel> signInOrRegister({required String email, required String password}) async {
    try {
      log('[AuthDataSource] HU: Intentando iniciar sesión para $email...');
      final userCredential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user == null) {
        throw ServerException(message: 'User not found after sign in.');
      }
      log('[AuthDataSource] HU: Inicio de sesión exitoso para ${userCredential.user!.uid}.');
      await _createOrUpdateUserDocument(userCredential.user!);
      return UserModel.fromFirebase(userCredential.user!);
    } on firebase.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        log('[AuthDataSource] HU: Usuario no encontrado, intentando registrar a $email...');
        try {
          final newUserCredential = await firebaseAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          if (newUserCredential.user == null) {
            throw ServerException(message: 'User not found after sign up.');
          }
          log('[AuthDataSource] HU: Registro exitoso para ${newUserCredential.user!.uid}.');
          await _createOrUpdateUserDocument(newUserCredential.user!);
          return UserModel.fromFirebase(newUserCredential.user!);
        } on firebase.FirebaseAuthException catch (signUpException) {
          log('[AuthDataSource] HU: FALLO en el registro: ${signUpException.message}');
          throw ServerException(message: signUpException.message ?? 'Sign up failed.');
        }
      }
      log('[AuthDataSource] HU: FALLO en la autenticación: ${e.message}');
      throw ServerException(message: e.message ?? 'Authentication failed.');
    } catch (e) {
      log('[AuthDataSource] HU: FALLO inesperado en signInOrRegister: ${e.toString()}');
      throw ServerException(message: 'An unexpected error occurred.');
    }
  }

  Future<void> _createOrUpdateUserDocument(firebase.User user) async {
    final userRef = firestore.collection('users').doc(user.uid);
    log('[AuthDataSource] HU: Creando/Actualizando documento en Firestore para el usuario ${user.uid}...');
    await userRef.set(
      {
        'uid': user.uid,
        'email': user.email,
        'name': user.displayName ?? 'Usuario',
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    log('[AuthDataSource] HU: Documento de usuario ${user.uid} creado/actualizado con éxito.');
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = firebaseAuth.currentUser;
    if (user == null) return null;
    return UserModel.fromFirebase(user);
  }

  @override
  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }
}


// // lib/features/auth/data/datasources/auth_remote_data_source_impl.dart

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart' as firebase;

// import '../../../../core/error/exceptions.dart';
// import '../../data/models/user_model.dart';
// import 'auth_remote_data_source.dart';

// class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
//   final firebase.FirebaseAuth firebaseAuth;
//   final FirebaseFirestore firestore;

//   AuthRemoteDataSourceImpl({
//     required this.firebaseAuth,
//     required this.firestore,
//   });

//   @override
//   Future<UserModel> signInOrRegister({required String email, required String password}) async {
//     try {
//       final userCredential = await firebaseAuth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       if (userCredential.user == null) {
//         throw ServerException(message: 'User not found after sign in.');
//       }
//       await _createOrUpdateUserDocument(userCredential.user!);
//       return UserModel.fromFirebase(userCredential.user!);
//     } on firebase.FirebaseAuthException catch (e) {
//       if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
//         // Para simplificar, si el usuario no existe o la contraseña es incorrecta,
//         // intentamos crearlo. Firebase manejará el error si el email ya existe.
//         try {
//           final newUserCredential = await firebaseAuth.createUserWithEmailAndPassword(
//             email: email,
//             password: password,
//           );
//           if (newUserCredential.user == null) {
//             throw ServerException(message: 'User not found after sign up.');
//           }
//           await _createOrUpdateUserDocument(newUserCredential.user!);
//           return UserModel.fromFirebase(newUserCredential.user!);
//         } on firebase.FirebaseAuthException catch (signUpException) {
//           // Maneja errores específicos del registro, como 'email-already-in-use'
//           throw ServerException(message: signUpException.message ?? 'Sign up failed.');
//         }
//       }
//       throw ServerException(message: e.message ?? 'Authentication failed.');
//     } catch (e) {
//       throw ServerException(message: 'An unexpected error occurred.');
//     }
//   }

//   Future<void> _createOrUpdateUserDocument(firebase.User user) async {
//     final userRef = firestore.collection('users').doc(user.uid);
//     await userRef.set(
//       {
//         'uid': user.uid,
//         'email': user.email,
//         // --- CAMBIO MÍNIMO Y ÚNICO ---
//         // Se asegura de que un nuevo usuario siempre tenga un nombre por defecto.
//         'name': user.displayName ?? 'Usuario',
//         'createdAt': FieldValue.serverTimestamp(),
//       },
//       SetOptions(merge: true),
//     );
//   }

//   @override
//   Future<UserModel?> getCurrentUser() async {
//     final user = firebaseAuth.currentUser;
//     if (user == null) return null;
//     return UserModel.fromFirebase(user);
//   }

//   @override
//   Future<void> signOut() async {
//     await firebaseAuth.signOut();
//   }
// }


// // // lib/features/auth/data/datasources/auth_remote_data_source_impl.dart

// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:firebase_auth/firebase_auth.dart' as firebase;

// // import '../../../../core/error/exceptions.dart';
// // import '../../data/models/user_model.dart';
// // import 'auth_remote_data_source.dart';

// // class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
// //   final firebase.FirebaseAuth firebaseAuth;
// //   final FirebaseFirestore firestore;

// //   AuthRemoteDataSourceImpl({
// //     required this.firebaseAuth,
// //     required this.firestore,
// //   });

// //   @override
// //   Future<UserModel> signInOrRegister({required String email, required String password}) async {
// //     try {
// //       final userCredential = await firebaseAuth.signInWithEmailAndPassword(
// //         email: email,
// //         password: password,
// //       );
// //       if (userCredential.user == null) {
// //         throw ServerException(message: 'User not found after sign in.');
// //       }
// //       await _createOrUpdateUserDocument(userCredential.user!);
// //       return UserModel.fromFirebase(userCredential.user!);
// //     } on firebase.FirebaseAuthException catch (e) {
// //       if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
// //         final newUserCredential = await firebaseAuth.createUserWithEmailAndPassword(
// //           email: email,
// //           password: password,
// //         );
// //         if (newUserCredential.user == null) {
// //           throw ServerException(message: 'User not found after sign up.');
// //         }
// //         await _createOrUpdateUserDocument(newUserCredential.user!);
// //         return UserModel.fromFirebase(newUserCredential.user!);
// //       }
// //       throw ServerException(message: e.message ?? 'Authentication failed.');
// //     } catch (e) {
// //       throw ServerException(message: 'An unexpected error occurred.');
// //     }
// //   }

// //   Future<void> _createOrUpdateUserDocument(firebase.User user) async {
// //     final userRef = firestore.collection('users').doc(user.uid);
// //     await userRef.set(
// //       {
// //         'uid': user.uid,
// //         'email': user.email,
// //         'name': user.displayName ?? '', // Asegurar que siempre haya un nombre
// //         'createdAt': FieldValue.serverTimestamp(),
// //       },
// //       SetOptions(merge: true),
// //     );
// //   }

// //   @override
// //   Future<UserModel?> getCurrentUser() async {
// //     final user = firebaseAuth.currentUser;
// //     if (user == null) return null;
// //     return UserModel.fromFirebase(user);
// //   }

// //   @override
// //   Future<void> signOut() async {
// //     await firebaseAuth.signOut();
// //   }
// // } 