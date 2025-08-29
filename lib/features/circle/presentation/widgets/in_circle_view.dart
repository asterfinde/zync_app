// lib/features/circle/presentation/widgets/in_circle_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer';
// CORRECCIÓN: Imports necesarios para Riverpod y el provider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zync_app/features/circle/presentation/provider/circle_provider.dart';
import '../../domain/entities/circle.dart';
import '../../../auth/domain/entities/user.dart';

// CORRECCIÓN: Convertido a ConsumerWidget para poder usar Riverpod de forma segura
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
            child: ListView.builder(
              itemCount: circle.members.length,
              itemBuilder: (context, index) {
                final User member = circle.members[index];
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(
                    (member.name.isNotEmpty)
                        ? member.name
                        : 'User: ${member.uid.substring(0, 6)}...',
                  ),
                  subtitle: Text(member.email),
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
              // CORRECCIÓN: onPressed ahora es async y usa 'ref' para llamar al provider
              onPressed: () async {
                // TODO: Reemplazar 'emoji_de_prueba' con un selector de emojis
                await ref
                    .read(circleProvider.notifier)
                    .updateCircleStatus("emoji_de_prueba");
              },
              child: const Text('Update My Status'),
            ),
          )
        ],
      ),
    );
  }
}