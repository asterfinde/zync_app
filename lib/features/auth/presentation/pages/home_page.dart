import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenemos el email del usuario desde el estado del BLoC para mostrarlo
    final userEmail = (context.watch<AuthBloc>().state as Authenticated).user.email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zync Home'),
        automaticallyImplyLeading: false, // Oculta el botón de "atrás"
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('¡Bienvenido de nuevo!'),
            const SizedBox(height: 8),
            Text(
              userEmail, // Muestra el email del usuario
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Al presionar, disparamos el evento para cerrar sesión
                context.read<AuthBloc>().add(const SignOutEvent());
              },
              child: const Text('CERRAR SESIÓN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Un color distintivo
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}