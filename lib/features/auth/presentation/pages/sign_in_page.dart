// lib/features/auth/presentation/pages/sign_in_page.dart

import 'dart:developer';
// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zync_app/core/di/injection_container.dart' as di;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:zync_app/core/usecases/usecase.dart';
import 'package:zync_app/features/auth/domain/usecases/sign_in_or_register.dart';
import 'package:zync_app/features/auth/domain/usecases/sign_out.dart';
import 'package:zync_app/features/circle/domain/repositories/circle_repository.dart';
import 'package:zync_app/features/circle/domain/usecases/create_circle.dart';
import 'package:zync_app/features/circle/domain/usecases/join_circle.dart';

import '../provider/auth_provider.dart';
import '../provider/auth_state.dart';
import '../widgets/auth_form.dart';

class SignInPage extends ConsumerWidget {
  const SignInPage({super.key});

  void _submitAuthForm(WidgetRef ref, String email, String password) {
    log("[SignInPage] _submitAuthForm called. Triggering signInOrRegister...");
    ref.read(authProvider.notifier).signInOrRegister(email, password);
  }

  // --- FUNCIÓN SEMILLERO COMPLETAMENTE REESCRITA ---
  Future<void> _seedDatabase(BuildContext context) async {
    // ignore_for_file: avoid_print
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    print('--- Iniciando Semillero de Pruebas Zync ---');
    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Iniciando sembrado...')));

    // Obtenemos las dependencias
    final firestore = di.sl<FirebaseFirestore>();
    final firebaseAuth = di.sl<fb_auth.FirebaseAuth>();
    final signInOrRegister = di.sl<SignInOrRegister>();
    final createCircle = di.sl<CreateCircle>();
    final joinCircle = di.sl<JoinCircle>();
    final signOut = di.sl<SignOut>();
    final circleRepo = di.sl<CircleRepository>();

    const user1Email = 'user1@zync.com';
    const user2Email = 'user2@zync.com';
    const password = '123456';
    const circleName = 'Círculo de Prueba';

    try {
      // 1. LIMPIAR DATOS DE FORMA SEGURA
      print('Limpiando datos de prueba anteriores...');
      await _clearTestData(firestore, firebaseAuth, user1Email, user2Email, password);
      print('-> Datos limpios.');

      // 2. CREAR USUARIO 1 Y CÍRCULO
      print('Creando Usuario 1 y Círculo...');
      final user1Result = await signInOrRegister(SignInOrRegisterParams(email: user1Email, password: password));
      final user1 = user1Result.getOrElse(() => throw Exception('Falló la creación del Usuario 1'));
      await createCircle(CreateCircleParams(name: circleName));
      final circleResult = await circleRepo.getCircleByCreatorId(user1.uid);
      final invitationCode = circleResult.getOrElse(() => throw Exception('Falló la obtención del Círculo')).invitationCode;
      print('-> Usuario 1 y Círculo creados. Código: $invitationCode');
      await signOut(NoParams());

      // 3. CREAR USUARIO 2 Y UNIRLO
      print('Creando Usuario 2 y uniéndolo al círculo...');
      await signInOrRegister(SignInOrRegisterParams(email: user2Email, password: password));
      await joinCircle(JoinCircleParams(invitationCode: invitationCode));
      print('-> Usuario 2 creado y unido.');
      await signOut(NoParams());

      print('--- ✅ Proceso completado ---');
      scaffoldMessenger.showSnackBar(const SnackBar(
        content: Text('¡Sembrado completado! Base de datos lista.'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      print('--- ❌ Ocurrió un error ---');
      print(e);
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text('Error en el sembrado: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // Nueva función de limpieza que elimina usuarios y círculos específicos
  Future<void> _clearTestData(FirebaseFirestore firestore, fb_auth.FirebaseAuth firebaseAuth, String email1, String email2, String password) async {
    // Borra el círculo del usuario 1 si existe
    try {
      final userCredential = await firebaseAuth.signInWithEmailAndPassword(email: email1, password: password);
      final user = userCredential.user;
      if (user != null) {
        final circleSnapshot = await firestore.collection('circles').where('members', arrayContains: user.uid).get();
        for (final doc in circleSnapshot.docs) {
          await doc.reference.delete();
        }
        await user.delete();
      }
    } catch (e) {
      print('Usuario 1 no existía o no se pudo limpiar: $e');
    }

    // Borra el usuario 2 si existe
    try {
      final userCredential = await firebaseAuth.signInWithEmailAndPassword(email: email2, password: password);
      await userCredential.user?.delete();
    } catch (e) {
      print('Usuario 2 no existía o no se pudo limpiar: $e');
    }
  }
  // --- FIN DE LA NUEVA FUNCIONALIDAD ---

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    log("[BUILD] SignInPage rebuilding...");
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is AuthError) {
        log("[SignInPage] Listener detected AuthError: ${next.message}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    final authState = ref.watch(authProvider);
    log("[SignInPage] Watching authState. Current state is: $authState");

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zync'),
        actions: [
          IconButton(
            key: const ValueKey('seed_database_button'),
            icon: const Icon(Icons.build_circle),
            tooltip: 'Limpiar y Poblar BD',
            onPressed: () => _seedDatabase(context),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: AuthForm(
              submitFn: (email, password) => _submitAuthForm(ref, email, password),
              isLoading: authState is AuthLoading,
            ),
          ),
        ),
      ),
    );
  }
}