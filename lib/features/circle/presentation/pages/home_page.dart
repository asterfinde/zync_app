import 'package:flutter/material.dart';
import '../../../../services/circle_service.dart';
import '../widgets/in_circle_view.dart';
import '../widgets/no_circle_view.dart';
import '../widgets/pending_request_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<UserCircleState>(
        stream: CircleService().getUserCircleStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
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
