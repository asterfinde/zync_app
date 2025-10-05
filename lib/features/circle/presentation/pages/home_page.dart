import 'package:flutter/material.dart';
import '../widgets/no_circle_view.dart';
import '../widgets/in_circle_view.dart';
import '../../services/firebase_circle_service.dart';
import '../../../../core/services/silent_functionality_coordinator.dart';
import '../../../../core/services/status_service.dart';
import '../../../../core/services/app_badge_service.dart';
import '../../../circle/domain_old/entities/user_status.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _service = FirebaseCircleService();
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    // Actualizar contexto del coordinador cuando se inicia HomePage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SilentFunctionalityCoordinator.updateContext(context);
      // Marcar como visto cuando el usuario llega a HomePage (ha visto los cambios)
      _markBadgeAsSeen();
    });
  }
  
  /// Marcar como visto para limpiar badge cuando el usuario ve la pantalla
  Future<void> _markBadgeAsSeen() async {
    try {
      await AppBadgeService.markAsSeen();
      print('🟢 [HomePage] Badge marcado como visto');
    } catch (e) {
      print('❌ [HomePage] Error marcando badge como visto: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // También actualizar el contexto en cada build para asegurar que esté actualizado
    SilentFunctionalityCoordinator.updateContext(context);
    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: StreamBuilder<Circle?>(
        stream: _service.getUserCircleStream(),
        builder: (context, snapshot) {
          // Mostrar loading solo en la primera carga
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando...', style: TextStyle(color: Colors.white)),
                ],
              ),
            );
          }

          final circle = snapshot.data;
          
          // Log para debugging
          print('[HomePage] Stream update - Circle: ${circle?.name ?? 'null'}');
          
          if (circle != null) {
            // Usuario está en un círculo - mostrar InCircleView
            print('[HomePage] Showing InCircleView for circle: ${circle.name}');
            return InCircleView(circle: circle);
          } else {
            // Usuario NO está en círculo - mostrar NoCircleView
            print('[HomePage] Showing NoCircleView');
            return const NoCircleView();
          }
        },
      ),
      // FAB para envío rápido del estado "available" (🟢) - Solo cuando está en círculo
      floatingActionButton: StreamBuilder<Circle?>(
        stream: _service.getUserCircleStream(),
        builder: (context, snapshot) {
          final circle = snapshot.data;
          
          // Solo mostrar FAB cuando el usuario está en un círculo
          if (circle == null) return const SizedBox.shrink();
          
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.tealAccent.shade400.withOpacity(0.8), 
                  Colors.tealAccent.shade400
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.tealAccent.shade400.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: ElevatedButton(
              onPressed: _isUpdatingStatus ? null : () => _quickStatusUpdate(),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUpdatingStatus 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                    ),
                  )
                : const Text(
                    'Enviar estado normal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
            ),
          );
        },
      ),
    );
  }

  /// Actualización rápida del estado a "available" (🟢)
  Future<void> _quickStatusUpdate() async {
    if (_isUpdatingStatus) return;
    
    setState(() {
      _isUpdatingStatus = true;
    });
    
    try {
      print('[HomePage] 🟢 Enviando estado rápido: available');
      
      final result = await StatusService.updateUserStatus(StatusType.available);
      
      // El cambio se refleja inmediatamente en el emoji del usuario
      // No necesitamos SnackBar porque es visualmente directo
      if (!result.isSuccess && mounted) {
        // Solo mostrar error si algo salió mal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result.errorMessage}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[HomePage] Error en quickStatusUpdate: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error actualizando estado'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }
}
