import 'dart:developer';
import 'package:flutter/material.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/services/silent_functionality_coordinator.dart';
import '../../../../core/widgets/nk_dialog.dart';
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
    final confirmed = await NkDialog.confirm(
      context,
      title: 'Silencio',
      body: 'La app se minimizará y quedará activa en segundo plano. '
          'Podrás cambiar tu estado desde la notificación persistente.',
      confirmLabel: 'Activar',
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
        padding: const EdgeInsets.all(NkSpacing.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: SilentModeButton(
                    isActive: false,
                    onToggle: _isUpdating ? null : _confirmAndActivateSilentMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    key: const Key('btn_change_status'),
                    onPressed: _isUpdating ? null : widget.onOk,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NkColors.mint,
                      foregroundColor: NkColors.onMint,
                      padding: const EdgeInsets.symmetric(vertical: NkSpacing.s),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: NkRadius.forInput),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isUpdating)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(NkColors.onMint.withValues(alpha: 0.54)),
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
