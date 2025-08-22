// lib/features/auth/data/models/user_model.dart

import '../../domain/entities/user.dart';
import 'package:meta/meta.dart';

/// UserModel es una implementación concreta de la entidad User.
/// Contiene la lógica para convertir datos desde/hacia JSON,
/// lo cual es una responsabilidad de la capa de datos.
class UserModel extends User {
  const UserModel({
    required String uid,
    required String email,
  }) : super(uid: uid, email: email);

  /// Factory constructor para crear un UserModel a partir de un mapa JSON.
  /// Esto es útil cuando se reciben datos de una API.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'],
      email: json['email'],
    );
  }

  /// Método para convertir un UserModel a un mapa JSON.
  /// Esto es útil para enviar datos a una API.
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
    };
  }
}
