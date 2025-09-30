import 'package:flutter/material.dart';
import '../../../../core/global_keys.dart';
import '../../services/firebase_circle_service.dart';

class NoCircleView extends StatefulWidget {
  const NoCircleView({super.key});

  @override
  State<NoCircleView> createState() => _NoCircleViewState();
}

class _NoCircleViewState extends State<NoCircleView> {
  final _createController = TextEditingController();
  final _joinController = TextEditingController();
  final _service = FirebaseCircleService();
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _createController.dispose();
    _joinController.dispose();
    super.dispose();
  }

  void _onCreateCircle() async {
    print('[NoCircleView] Create button pressed');
    
    if (_isDisposed || !mounted) return;
    
    if (_createController.text.trim().isEmpty) {
      if (!_isDisposed && mounted) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Please enter a name for your circle.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }
    
    final circleName = _createController.text.trim();
    print('[NoCircleView] Creating circle: $circleName');
    
    try {
      await _service.createCircle(circleName);
      print('[NoCircleView] Circle created successfully');
      
      if (!_isDisposed && mounted) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Circle "$circleName" created!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Limpiar el controller de manera segura
        try {
          _createController.clear();
        } catch (e) {
          print('[NoCircleView] Controller already disposed: $e');
        }
      }
      
      // Forzar actualización del stream
      FirebaseCircleService.forceRefresh();
      print('[NoCircleView] Forced stream refresh');
      
      // La navegación se maneja automáticamente por el stream
      
    } catch (e) {
      print('[NoCircleView] Error creating circle: $e');
      if (!_isDisposed && mounted) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onJoinCircle() async {
    print('[NoCircleView] Join button pressed');
    
    if (_isDisposed || !mounted) return;
    
    if (_joinController.text.trim().isEmpty) {
      if (!_isDisposed && mounted) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Please enter an invitation code.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }
    
    final invitationCode = _joinController.text.trim();
    print('[NoCircleView] Joining circle with code: $invitationCode');
    
    try {
      await _service.joinCircle(invitationCode);
      print('[NoCircleView] Joined circle successfully');
      
      if (!_isDisposed && mounted) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Joined circle successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Limpiar el controller de manera segura
        try {
          _joinController.clear();
        } catch (e) {
          print('[NoCircleView] Controller already disposed: $e');
        }
      }
      
      // Forzar actualización del stream
      FirebaseCircleService.forceRefresh();
      print('[NoCircleView] Forced stream refresh after join');
      
      // La navegación se maneja automáticamente por el stream
      
    } catch (e) {
      print('[NoCircleView] Error joining circle: $e');
      if (!_isDisposed && mounted) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
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
    );
  }
}
