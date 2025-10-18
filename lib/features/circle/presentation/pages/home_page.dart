import 'package:flutter/material.dart';
import '../../services/firebase_circle_service.dart';
import '../widgets/in_circle_view.dart';
import '../widgets/no_circle_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _service = FirebaseCircleService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
          
          if (circle != null) {
            // Usuario está en un círculo - mostrar InCircleView
            return InCircleView(circle: circle);
          } else {
            // Usuario NO está en círculo - mostrar NoCircleView
            return const NoCircleView();
          }
        },
      ),
    );
  }
}
