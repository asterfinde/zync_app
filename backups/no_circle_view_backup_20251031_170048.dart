import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../auth/presentation/provider/auth_provider.dart';
import '../../../auth/presentation/provider/auth_state.dart';
import '../../../../core/services/silent_functionality_coordinator.dart';
import 'create_circle_view.dart';
import 'join_circle_view.dart';

class NoCircleView extends ConsumerStatefulWidget {
  const NoCircleView({super.key});

  @override
  ConsumerState<NoCircleView> createState() => _NoCircleViewState();
}

class _NoCircleViewState extends ConsumerState<NoCircleView> {

  String _getCurrentUserNickname() {
    final authState = ref.watch(authProvider);
    if (authState is Authenticated) {
      return authState.user.nickname.isNotEmpty 
          ? authState.user.nickname 
          : authState.user.email.split('@')[0];
    }
    return 'Usuario';
  }

  void _navigateToCreateCircle() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateCircleView(),
      ),
    );
  }

  void _navigateToJoinCircle() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const JoinCircleView(),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Cerrar Sesión',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Estás seguro de que quieres cerrar sesión?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                print('🔴 [LOGOUT] Iniciando proceso de logout...');
                await FirebaseAuth.instance.signOut();
                print('🔴 [LOGOUT] Firebase signOut completado, llamando deactivateAfterLogout...');
                // NUEVO: Desactivar funcionalidad silenciosa al hacer logout
                await SilentFunctionalityCoordinator.deactivateAfterLogout();
                print('🔴 [LOGOUT] deactivateAfterLogout completado');
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sesión cerrada exitosamente'),
                      backgroundColor: Color(0xFF1CE4B3),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al cerrar sesión: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // AppBar personalizado (igual que InCircleView)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
          color: Colors.black,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Zync',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      _getCurrentUserNickname(),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  switch (value) {
                    case 'logout':
                      _showLogoutDialog(context);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.grey),
                      title: Text('Cerrar Sesión'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Contenido principal
        Expanded(
          child: Container(
            color: Colors.black,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40), // Espacio reducido
                  
                  // Mensaje principal
                  Text(
                    "Aún no estás en un círculo",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  
                  // Mensaje de acción
                  Text(
                    "¿Qué te gustaría hacer?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  
                  // Botón Crear Círculo
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    child: ElevatedButton(
                      onPressed: _navigateToCreateCircle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1CE4B3),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_circle,
                            color: Colors.black,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Crear un Círculo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Crea tu propio círculo e invita a otros',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  
                  // Divider OR
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          "O",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Botón Unirse a Círculo
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    child: ElevatedButton(
                      onPressed: _navigateToJoinCircle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 91, 207, 139),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.group_add,
                            color: Colors.black,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Unirse a un Círculo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Únete con un código de invitación',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 100), // Espacio final
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
