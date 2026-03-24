import 'package:flutter/material.dart';
import '../../../../services/circle_service.dart';
import '../widgets/in_circle_view.dart';
import '../widgets/no_circle_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = CircleService();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(child: StreamBuilder<Circle?>(
            stream: service.getUserCircleStream(),
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

              final circle = snapshot.data;

              if (circle != null) {
                return InCircleView(circle: circle);
              } else {
                return const NoCircleView();
              }
            },
          )),
        ],
      ),
    );
  }
}
