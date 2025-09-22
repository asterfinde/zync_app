import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zync_app/features/circle/domain/entities/user_status.dart';
import 'package:zync_app/features/circle/domain/usecases/send_user_status.dart';
import 'package:zync_app/features/auth/presentation/provider/auth_provider.dart';
import 'package:zync_app/features/auth/presentation/provider/auth_state.dart';
import 'package:zync_app/features/circle/presentation/provider/circle_provider.dart';
import 'package:zync_app/features/circle/presentation/provider/circle_state.dart';
import 'package:zync_app/core/di/injection_container.dart' as di;

class EmojiModal extends ConsumerStatefulWidget {
  const EmojiModal({super.key});

  @override
  ConsumerState<EmojiModal> createState() => _EmojiModalState();
}

class _EmojiModalState extends ConsumerState<EmojiModal> {
  bool _showCheck = false;
  bool _isSending = false;

  // Mapear emojis del modal con StatusType existentes
  final List<StatusType> emojis = const [
    StatusType.fine,     // 😊 Feliz -> Bien
    StatusType.sad,      // 😢 Triste
    StatusType.worried,  // 😡 -> Preocupado (más cercano a enojado)
    StatusType.thinking, // 🤔 Pensativo
    StatusType.sos,      // 🆘 SOS
    StatusType.busy,     // 🔥 Ocupado
  ];

  Future<void> _onStatusTap(StatusType status) async {
    final authState = ref.read(authProvider);
    final circleState = ref.read(circleProvider);
    
    final userId = authState is Authenticated ? authState.user.uid : null;
    String? circleId;
    if (circleState is CircleLoaded) {
      circleId = circleState.circle.id;
    }

    if (userId != null && circleId != null && !_isSending) {
      setState(() => _isSending = true);
      try {
        final sendUserStatus = di.sl<SendUserStatus>();
        await sendUserStatus(SendUserStatusParams(
          circleId: circleId,
          statusType: status,
        ));
        setState(() => _showCheck = true);
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        // Si hay error, mostrar mensaje pero cerrar modal
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350, maxHeight: 400),
        padding: const EdgeInsets.all(20.0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(
              opacity: _showCheck ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 250),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🎯 ¡FUNCIONÓ! Modal desde notificación',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: emojis.length,
                      itemBuilder: (context, index) {
                        final emoji = emojis[index];
                        return GestureDetector(
                          onTap: () => _onStatusTap(emoji),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  emoji.emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(height: 4),
                                Flexible(
                                  child: Text(
                                    emoji.description,
                                    style: const TextStyle(fontSize: 10),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
            AnimatedScale(
              scale: _showCheck ? 1.0 : 0.7,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: _showCheck ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Icon(Icons.check_circle_rounded, color: Colors.green[700], size: 56),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}