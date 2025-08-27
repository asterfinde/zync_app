// main.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';

import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/sign_in_page.dart';
import 'features/auth/presentation/pages/home_page.dart'; // <-- Importa la nueva HomePage
import 'core/di/injection_container.dart' as di;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<AuthBloc>()..add(const CheckAuthStatusEvent()),
      child: MaterialApp(
        title: 'Zync App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        // --- ESTA ES LA LÓGICA DE NAVEGACIÓN ---
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is Authenticated) {
              return const HomePage(); // Si está autenticado, muestra HomePage
            } else if (state is Unauthenticated || state is AuthError) {
              return const SignInPage(); // Si no, muestra SignInPage
            }
            // Mientras se verifica, muestra un loader para evitar parpadeos
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }
}