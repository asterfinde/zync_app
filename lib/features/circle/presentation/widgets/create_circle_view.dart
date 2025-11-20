import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/global_keys.dart';
import '../../../../services/circle_service.dart';

class CreateCircleView extends ConsumerStatefulWidget {
  const CreateCircleView({super.key});

  @override
  ConsumerState<CreateCircleView> createState() => _CreateCircleViewState();
}

class _CreateCircleViewState extends ConsumerState<CreateCircleView> {
  final _createController = TextEditingController();
  final _service = CircleService();
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _createController.addListener(_validateForm);
  }

  void _validateForm() {
    setState(() {
      _isFormValid = _createController.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _createController.dispose();
    super.dispose();
  }

  void _onCreateCircle() async {
    print('[CreateCircleView] Create button pressed');
    
    if (!mounted) return;
    
    if (_createController.text.trim().isEmpty) {
      if (mounted) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Por favor ingresa un nombre para tu círculo.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }
    
    final circleName = _createController.text.trim();
    print('[CreateCircleView] Creating circle: $circleName');
    
    try {
      await _service.createCircle(circleName);
      print('[CreateCircleView] Circle created successfully');
      
      if (mounted) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('¡Círculo "$circleName" creado!'),
            backgroundColor: const Color(0xFF1CE4B3),
          ),
        );
        
        // Limpiar el controller de manera segura
        _createController.clear();
      }
      
      // Forzar actualización del stream
      CircleService.forceRefresh();
      print('[CreateCircleView] Forced stream refresh');
      
      // Navegar de vuelta
      if (mounted) {
        Navigator.of(context).pop();
      }
      
    } catch (e) {
      print('[CreateCircleView] Error creating circle: $e');
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
          'Crear Círculo',
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
              "Crea tu propio círculo y comparte el código con tus contactos.",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w300,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 60),
            
            // Input para nombre del círculo
            TextFormField(
              controller: _createController,
              onChanged: (_) => _validateForm(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nombre del Círculo',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                hintText: 'ej., Familia, Amigos Cercanos',
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
            
            // Botón Crear Círculo
            ElevatedButton(
              onPressed: _isFormValid ? _onCreateCircle : null,
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
                'Crear Círculo',
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