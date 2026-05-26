import 'package:flutter/material.dart';
import '../../../../services/circle_service.dart';

class JoinRequestsBanner extends StatelessWidget {
  final List<JoinRequest> requests;
  final bool isOwner;
  final void Function(JoinRequest) onApprove;

  const JoinRequestsBanner({
    super.key,
    required this.requests,
    required this.isOwner,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwner || requests.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.person_add_outlined, size: 24, color: Color(0xFF1EE9A4)),
            const SizedBox(width: 8),
            Text(
              'Solicitudes de ingreso (${requests.length})',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...requests.map((req) => _JoinRequestCard(
              request: req,
              onApprove: () => onApprove(req),
            )),
      ],
    );
  }
}

class _JoinRequestCard extends StatelessWidget {
  final JoinRequest request;
  final VoidCallback onApprove;

  const _JoinRequestCard({required this.request, required this.onApprove});

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1EE9A4).withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 20, color: Color(0xFF1EE9A4)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.nickname.isNotEmpty ? request.nickname : request.userId,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (request.requestedAt != null)
                Text(
                  _timeAgo(request.requestedAt),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                ),
            ],
          ),
          if (request.email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              request.email,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: ValueKey('btn_approve_${request.userId}'),
              onPressed: onApprove,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1EE9A4),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
              ),
              child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
