// lib/features/circle/presentation/widgets/no_circle_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/global_keys.dart';
import '../provider/circle_provider.dart';

// CORRECCIÓN 1: Se convierte a ConsumerStatefulWidget para manejar
// correctamente el estado de los campos de texto (TextEditingControllers).
class NoCircleView extends ConsumerStatefulWidget {
  const NoCircleView({super.key});

  @override
  ConsumerState<NoCircleView> createState() => _NoCircleViewState();
}

class _NoCircleViewState extends ConsumerState<NoCircleView> {
  // Se declaran los controllers y una key para el formulario.
  final _createController = TextEditingController();
  final _joinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    // Es crucial hacer dispose de los controllers para liberar memoria.
    _createController.dispose();
    _joinController.dispose();
    super.dispose();
  }

  // CORRECCIÓN 3: Lógica robusta para el botón "Create Circle".
  void _onCreateCircle() {
    // Primero, se valida que el campo de texto no esté vacío.
    if (_createController.text.trim().isEmpty) {
      // Si está vacío, se muestra un mensaje de error y no se hace nada más.
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Please enter a name for your circle.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    // Solo si hay texto, se llama al provider para crear el círculo.
    ref.read(circleProvider.notifier).createCircle(_createController.text.trim());
  }

  void _onJoinCircle() {
    // Lógica similar para unirse a un círculo
    if (_joinController.text.trim().isEmpty) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Please enter an invitation code.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    ref.read(circleProvider.notifier).joinCircle(_joinController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    // CORRECCIÓN 2: Se construye la UI completa que el usuario espera ver.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "You're not in a circle yet.",
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // --- Sección para Crear Círculo ---
            Text(
              'Create a new Circle',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _createController,
              decoration: const InputDecoration(
                labelText: 'Circle Name',
                border: OutlineInputBorder(),
                hintText: 'e.g., Family, Close Friends',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Circle name cannot be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _onCreateCircle,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Create Circle'),
            ),

            const SizedBox(height: 40),
            const Row(children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text("OR"),
              ),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 40),

            // --- Sección para Unirse a Círculo ---
            Text(
              'Join an existing one',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _joinController,
              decoration: const InputDecoration(
                labelText: 'Invitation Code',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Invitation code cannot be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _onJoinCircle,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Join Circle'),
            ),
          ],
        ),
      ),
    );
  }
}