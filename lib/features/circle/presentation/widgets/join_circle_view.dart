import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/global_keys.dart';
import '../../services/firebase_circle_service.dart';

class JoinCircleView extends ConsumerStatefulWidget {
  const JoinCircleView({super.key});

  @override
  ConsumerState<JoinCircleView> createState() => _JoinCircleViewState();
}

class _JoinCircleViewState extends ConsumerState<JoinCircleView> {
  final _joinController = TextEditingController();
  final _service = FirebaseCircleService();
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _joinController.addListener(_validateForm);
  }

  void _validateForm() {
    setState(() {
      _isFormValid = _joinController.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _joinController.dispose();
    super.dispose();
  }

  void _onJoinCircle() async {
    print('[JoinCircleView] Join button pressed');
    
    if (!mounted) return;
    
    if (_joinController.text.trim().isEmpty) {
      if (mounted) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Por favor ingresa un código de invitación.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }
    
    final invitationCode = _joinController.text.trim();
    print('[JoinCircleView] Joining circle with code: $invitationCode');
    
    try {
      await _service.joinCircle(invitationCode);
      print('[JoinCircleView] Joined circle successfully');
      
      if (mounted) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('¡Te uniste al círculo exitosamente!'),
            backgroundColor: Color(0xFF1CE4B3),
          ),
        );
        
        // Limpiar el controller
        _joinController.clear();
      }
      
      // Forzar actualización del stream
      FirebaseCircleService.forceRefresh();
      print('[JoinCircleView] Forced stream refresh after join');
      
      // Navegar de vuelta
      if (mounted) {
        Navigator.of(context).pop();
      }
      
    } catch (e) {
      print('[JoinCircleView] Error joining circle: $e');
      if (mounted) {
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Unirse a Círculo',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            
            // Mensaje principal
            Text(
              "Ingresa el código de invitación que recibiste para unirte al círculo.",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w300,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 60),
            
            // Input para código de invitación
            TextFormField(
              controller: _joinController,
              onChanged: (_) => _validateForm(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Código de Invitación',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                hintText: 'ej., ABC123',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1CE4B3), width: 2),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
            ),
            const SizedBox(height: 40),
            
            // Botón Unirse a Círculo
            ElevatedButton(
              onPressed: _isFormValid ? _onJoinCircle : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFormValid 
                    ? const Color(0xFF1CE4B3) 
                    : Colors.grey[700],
                foregroundColor: _isFormValid ? Colors.black : Colors.grey[400],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Unirse al Círculo',
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w500,
                  color: _isFormValid ? Colors.black : Colors.grey[500],
                ),
              ),
            ),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}