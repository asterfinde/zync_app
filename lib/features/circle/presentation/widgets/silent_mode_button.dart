import 'package:flutter/material.dart';
import '../../../../app/theme/design_tokens.dart';

class SilentModeButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback? onToggle;

  const SilentModeButton({
    super.key,
    required this.isActive,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('btn_silent_mode'),
      onPressed: onToggle,
      style: OutlinedButton.styleFrom(
        foregroundColor: NkColors.mint,
        disabledForegroundColor: NkColors.fgSub,
        backgroundColor: NkColors.canvas,
        side: const BorderSide(color: NkColors.mint),
        padding: const EdgeInsets.symmetric(vertical: NkSpacing.s),
        shape: RoundedRectangleBorder(borderRadius: NkRadius.forInput),
      ),
      icon: const Icon(Icons.bedtime_outlined, size: 18),
      label: const Text(
        'Modo Silencio',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}
