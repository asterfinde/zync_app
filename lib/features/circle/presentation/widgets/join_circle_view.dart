import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/global_keys.dart';
import '../../../../services/circle_service.dart';
import '../../../../app/theme/design_tokens.dart';

class JoinCircleView extends ConsumerStatefulWidget {
  const JoinCircleView({super.key});

  @override
  ConsumerState<JoinCircleView> createState() => _JoinCircleViewState();
}

class _JoinCircleViewState extends ConsumerState<JoinCircleView> {
  final _joinController = TextEditingController();
  final _service = CircleService();
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
    if (!mounted) return;

    if (_joinController.text.trim().isEmpty) {
      if (mounted) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Por favor ingresa un código de invitación.'),
            backgroundColor: NkColors.danger,
          ),
        );
      }
      return;
    }

    final invitationCode = _joinController.text.trim();

    try {
      await _service.requestToJoinCircle(invitationCode);

      if (mounted) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Solicitud enviada. Esperando aprobación del creador.'),
            backgroundColor: NkColors.mint,
          ),
        );
        _joinController.clear();
        Navigator.of(context).pop();
      }
    } catch (e) {
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
          'Unirse a Círculo',
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
              "Ingresa el código de invitación que recibiste para unirte al círculo.",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w300,
                color: NkColors.fgMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 60),

            // Input para código de invitación
            TextFormField(
              key: const Key('field_invite_code'),
              controller: _joinController,
              onChanged: (_) => _validateForm(),
              style: const TextStyle(color: NkColors.onDark),
              decoration: InputDecoration(
                labelText: 'Código de Invitación',
                labelStyle: const TextStyle(color: NkColors.fgMuted),
                hintText: 'ej., ABC123',
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

            // Botón Unirse a Círculo
            ElevatedButton(
              key: const Key('btn_join_circle'),
              onPressed: _isFormValid ? _onJoinCircle : null,
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
                'Unirse al Círculo',
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
