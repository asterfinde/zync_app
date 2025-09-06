// test/seed_database_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:zync_app/core/di/injection_container.dart' as di;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zync_app/core/usecases/usecase.dart';
import 'package:zync_app/features/auth/domain/usecases/sign_in_or_register.dart';
import 'package:zync_app/features/auth/domain/usecases/sign_out.dart';
import 'package:zync_app/features/circle/domain/repositories/circle_repository.dart';
import 'package:zync_app/features/circle/domain/usecases/create_circle.dart';
import 'package:zync_app/features/circle/domain/usecases/join_circle.dart';
import 'package:zync_app/firebase_options.dart';

// --- Configuración ---
const user1Email = 'usuario1@zync.com';
const user2Email = 'usuario2@zync.com';
const circleName = 'Círculo de Prueba';
const password = 'password123';
// ---------------------

void main() {
  // Usamos test() para que el runner de Flutter lo ejecute.
  test('Seed Firestore Database for Manual Testing', () async {
    // ignore_for_file: avoid_print

    print('--- Iniciando Semillero de Pruebas Zync ---');

    // 1. Inicializar Flutter, Firebase y la Inyección de Dependencias
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await di.init();

    // Obtenemos las dependencias
    final signInOrRegister = di.sl<SignInOrRegister>();
    final createCircle = di.sl<CreateCircle>();
    final joinCircle = di.sl<JoinCircle>();
    final signOut = di.sl<SignOut>();
    final circleRepo = di.sl<CircleRepository>();
    final firestore = di.sl<FirebaseFirestore>();

    try {
      // 2. LIMPIAR LA BASE DE DATOS
      print('\nPaso 1: Limpiando datos existentes en Firestore...');
      await _clearFirestoreData(firestore);
      print('-> Datos limpios.');

      // 3. Crear Usuario 1
      print('\nPaso 2: Creando Usuario 1 ($user1Email)...');
      final user1Result = await signInOrRegister(SignInOrRegisterParams(email: user1Email, password: password));
      final user1 = user1Result.getOrElse(() => throw Exception('Falló la creación del Usuario 1'));
      print('-> Usuario 1 creado con UID: ${user1.uid}');

      // 4. Crear el Círculo
      print('\nPaso 3: Creando Círculo "$circleName"...');
      await createCircle(CreateCircleParams(name: circleName));
      print('-> Círculo creado exitosamente.');

      // 5. Obtener el Código de Invitación
      print('\nPaso 4: Obteniendo código de invitación...');
      final circleResult = await circleRepo.getCircleByCreatorId(user1.uid);
      final invitationCode = circleResult.getOrElse(() => throw Exception('Falló la obtención del Círculo')).invitationCode;
      print('-> Código de invitación obtenido: $invitationCode');

      // 6. Cerrar sesión del Usuario 1
      await signOut(NoParams());

      // 7. Crear Usuario 2
      print('\nPaso 5: Creando Usuario 2 ($user2Email)...');
      final user2Result = await signInOrRegister(SignInOrRegisterParams(email: user2Email, password: password));
      user2Result.getOrElse(() => throw Exception('Falló la creación del Usuario 2'));
      print('-> Usuario 2 creado.');

      // 8. Unir Usuario 2 al Círculo
      print('\nPaso 6: Uniendo Usuario 2 al círculo...');
      await joinCircle(JoinCircleParams(invitationCode: invitationCode));
      print('-> Usuario 2 unido exitosamente.');

      print('\n--- ✅ Proceso completado exitosamente ---');
      print('BD lista. Puedes iniciar sesión con:');
      print('  - $user1Email (password: $password)');
      print('  - $user2Email (password: $password)');

    } catch (e) {
      print('\n--- ❌ Ocurrió un error durante el sembrado ---');
      print(e.toString());
      // Hacemos que la prueba falle si hay un error
      fail(e.toString());
    }
  });
}

Future<void> _clearFirestoreData(FirebaseFirestore firestore) async {
  final circlesSnapshot = await firestore.collection('circles').get();
  for (var doc in circlesSnapshot.docs) {
    await doc.reference.delete();
  }
  final usersSnapshot = await firestore.collection('users').get();
  for (var doc in usersSnapshot.docs) {
    await doc.reference.delete();
  }
}