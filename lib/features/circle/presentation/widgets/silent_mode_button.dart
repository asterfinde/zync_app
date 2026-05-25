import 'package:flutter/material.dart';

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
        foregroundColor: const Color(0xFF1EE9A4),
        disabledForegroundColor: const Color(0xFF9E9E9E),
        backgroundColor: Colors.black,
        side: const BorderSide(color: Color(0xFF1EE9A4)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
      icon: const Icon(Icons.bedtime_outlined, size: 18),
      label: const Text(
        'Modo Silencio',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}
