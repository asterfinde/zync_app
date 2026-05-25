import 'package:flutter/material.dart';

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
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub, size: 28, color: Color(0xFF1EE9A4)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      circleName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$memberCount miembros',
                      style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Código de Invitación',
            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
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
                    fontSize: 20,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              IconButton(
                onPressed: onCopyCode,
                icon: const Icon(Icons.copy, size: 24, color: Color(0xFF1EE9A4)),
                tooltip: 'Copiar código',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
