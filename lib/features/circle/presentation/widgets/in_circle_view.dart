// lib/features/circle/presentation/widgets/in_circle_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zync_app/features/circle/presentation/provider/circle_provider.dart';
import '../../domain/entities/circle.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/user_status.dart';

class InCircleView extends ConsumerWidget {
  final Circle circle;
  const InCircleView({super.key, required this.circle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    log('[InCircleView] invitationCode: "${circle.invitationCode}"');
    log('[InCircleView] Members hydrated: ${circle.members.map((e) => e.name)}');
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            circle.name,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: Text(
                circle.invitationCode,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              subtitle: const Text('Invitation Code'),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  if (circle.invitationCode.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: circle.invitationCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invitation code copied!')),
                    );
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Members (${circle.members.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Divider(),
          Expanded(
            child: circle.members.isEmpty
                ? const Center(
                    child: Text(
                      'Finding members...',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  )
                : ListView.builder(
                    itemCount: circle.members.length,
                    itemBuilder: (context, index) {
                      final User member = circle.members[index];
                      final status = circle.memberStatus[member.uid];
                      return ListTile(
                        leading: Text(
                          status?.statusType.emoji ?? '...',
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          (member.name.isNotEmpty)
                              ? member.name
                              : 'User: ${member.uid.substring(0, 6)}...',
                        ),
                        subtitle: Text(status?.statusType.description ?? "No status yet"),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              // CORRECCIÓN: Ahora que 'sendUserStatus' está restaurado en el provider, esta llamada funciona.
              onPressed: () {
                ref
                    .read(circleProvider.notifier)
                    .sendUserStatus(StatusType.fine);
              },
              child: const Text('Send "Fine" Status'),
            ),
          )
        ],
      ),
    );
  }
}