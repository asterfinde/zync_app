import 'dart:developer';
import 'package:flutter/material.dart';
import '../../../../core/services/silent_functionality_coordinator.dart';
import 'silent_mode_button.dart';

class InCircleFooter extends StatefulWidget {
  final VoidCallback onOk;

  const InCircleFooter({super.key, required this.onOk});

  @override
  State<InCircleFooter> createState() => _InCircleFooterState();
}

class _InCircleFooterState extends State<InCircleFooter> {
  bool _isUpdating = false;

  Future<void> _confirmAndActivateSilentMode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF1CE4B3).withValues(alpha: 0.4), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Activar Modo Silencio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text(
                  'La app se minimizará y quedará activa en segundo plano. '
                  'Podrás cambiar tu estado desde la notificación persistente.',
                  style: TextStyle(fontSize: 14, color: Color(0xCCFFFFFF)),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: TextButton.styleFrom(foregroundColor: Colors.white70),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: TextButton.styleFrom(foregroundColor: Color(0xFF1CE4B3)),
                      child: const Text('Activar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isUpdating = true);
      try {
        await SilentFunctionalityCoordinator.activateSilentMode(context);
      } catch (e) {
        log('[InCircleFooter] ⚠️ Error activando Modo Silencio: $e');
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SilentModeButton(
                    isActive: false,
                    onToggle: _isUpdating ? null : _confirmAndActivateSilentMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    key: const Key('btn_change_status'),
                    onPressed: _isUpdating ? null : widget.onOk,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1EE9A4),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isUpdating)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                            ),
                          )
                        else
                          const Icon(Icons.check_circle),
                        const SizedBox(width: 8),
                        Text(_isUpdating ? '...' : 'OK'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
