import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/global_keys.dart';
import '../../../../services/circle_service.dart';
import '../../../../core/services/silent_functionality_coordinator.dart';
import '../../../../app/theme/design_tokens.dart';

class CreateCircleView extends ConsumerStatefulWidget {
  const CreateCircleView({super.key});

  @override
  ConsumerState<CreateCircleView> createState() => _CreateCircleViewState();
}

class _CreateCircleViewState extends ConsumerState<CreateCircleView> {
  final _createController = TextEditingController();
  final _focusNode = FocusNode();
  final _service = CircleService();
  bool _isFormValid = false;
  bool _focusListenerRegistered = false;

  @override
  void initState() {
    super.initState();
    _createController.addListener(_validateForm);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusListenerRegistered) return;
    _focusListenerRegistered = true;

    final animation = ModalRoute.of(context)?.animation;
    if (animation == null) {
      // Sin animación de ruta (ruta raíz): pedir foco directamente.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(_focusNode);
      });
      return;
    }

    // Esperar a que la animación de entrada del MaterialPageRoute termine
    // para que FocusManager no ignore la solicitud mientras la ruta no es "activa".
    if (animation.status == AnimationStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(_focusNode);
      });
    } else {
      void onRouteAnimationDone(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          animation.removeStatusListener(onRouteAnimationDone);
          if (mounted) FocusScope.of(context).requestFocus(_focusNode);
        }
      }
      animation.addStatusListener(onRouteAnimationDone);
    }
  }

  void _validateForm() {
    setState(() {
      _isFormValid = _createController.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
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
            backgroundColor: NkColors.danger,
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

      // Informar al coordinador que el usuario ya tiene círculo (síncrono, 0ms).
      // activateAfterLogin hacía 2 reads Firestore innecesarios aquí — ya
      // sabemos que el círculo existe porque acabamos de crearlo.
      SilentFunctionalityCoordinator.syncCircleState(hasCircle: true);

      if (mounted) {
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
            backgroundColor: NkColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NkColors.canvas,
      appBar: AppBar(
        backgroundColor: NkColors.canvas,
        foregroundColor: NkColors.onDark,
        title: const Text(
          'Crear Círculo',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: NkColors.onDark,
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
            const Text(
              "Crea tu propio círculo y comparte el código con tus contactos.",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w300,
                color: NkColors.fgMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 60),

            // Input para nombre del círculo
            TextFormField(
              key: const Key('field_circle_name'),
              controller: _createController,
              focusNode: _focusNode,
              onChanged: (_) => _validateForm(),
              style: const TextStyle(color: NkColors.onDark),
              decoration: InputDecoration(
                labelText: 'Nombre del Círculo',
                labelStyle: const TextStyle(color: NkColors.fgMuted),
                hintText: 'ej., Familia, Amigos Cercanos',
                hintStyle: const TextStyle(color: NkColors.fgHint),
                enabledBorder: OutlineInputBorder(
                  borderRadius: NkRadius.forInput,
                  borderSide: const BorderSide(color: NkColors.fgHint),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: NkRadius.forInput,
                  borderSide: const BorderSide(color: NkColors.mint, width: 2),
                ),
                filled: true,
                fillColor: NkColors.surface3,
              ),
            ),
            const SizedBox(height: 40),

            // Botón Crear Círculo
            ElevatedButton(
              key: const Key('btn_create_circle'),
              onPressed: _isFormValid ? _onCreateCircle : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFormValid ? NkColors.mint : NkColors.surface4,
                foregroundColor: _isFormValid ? NkColors.onMint : NkColors.fgHint,
                padding: const EdgeInsets.symmetric(vertical: NkSpacing.s),
                shape: RoundedRectangleBorder(
                  borderRadius: NkRadius.forInput,
                ),
                elevation: 0,
              ),
              child: Text(
                'Crear Círculo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _isFormValid ? NkColors.onMint : NkColors.fgHint,
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
