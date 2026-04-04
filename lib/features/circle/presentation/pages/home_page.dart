import 'package:flutter/material.dart';
import '../../../../core/services/silent_functionality_coordinator.dart';
import '../../../../services/circle_service.dart';
import '../widgets/in_circle_view.dart';
import '../widgets/no_circle_view.dart';
import '../widgets/pending_request_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _service = CircleService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Verificar permisos al llegar a HomePage (cubre T4.6: denegación inicial)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SilentFunctionalityCoordinator.onAppResumed(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Verificar permisos al volver al frente (cubre T4.9: revocación desde Ajustes)
    if (state == AppLifecycleState.resumed && mounted) {
      SilentFunctionalityCoordinator.onAppResumed(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<UserCircleState>(
        stream: _service.getUserCircleStream(),
        builder: (context, snapshot) {
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

          final state = snapshot.data;

          if (state is UserInCircle) {
            return InCircleView(circle: state.circle);
          } else if (state is UserPendingRequest) {
            return PendingRequestView(pendingCircleId: state.pendingCircleId);
          } else {
            return const NoCircleView();
          }
        },
      ),
    );
  }
}
