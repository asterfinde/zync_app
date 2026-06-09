import 'package:flutter/material.dart';
import '../../../../app/theme/design_tokens.dart';

class CircleInfoCard extends StatelessWidget {
  final String circleName;
  final int memberCount;
  final String invitationCode;
  final VoidCallback onCopyCode;

  const CircleInfoCard({
    super.key,
    required this.circleName,
    required this.memberCount,
    required this.invitationCode,
    required this.onCopyCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NkSpacing.s5),
      decoration: BoxDecoration(
        color: const Color(0x18FFFFFF),
        border: Border.all(color: NkColors.surfaceBorder),
        borderRadius: NkRadius.forCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub, size: 28, color: NkColors.mint),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      circleName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: NkColors.onDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$memberCount miembros',
                      style: NkTextStyle.meta,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Código de Invitación',
            style: NkTextStyle.meta,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  invitationCode,
                  key: const Key('text_invite_code'),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: NkColors.onDark,
                    letterSpacing: 8,
                  ),
                ),
              ),
              IconButton(
                onPressed: onCopyCode,
                icon: const Icon(Icons.copy, size: 24, color: NkColors.mint),
                tooltip: 'Copiar código',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
