// lib/core/widgets/emoji_modal.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zync_app/core/models/user_status.dart';
import 'package:zync_app/core/services/status_service.dart';
import 'package:zync_app/core/services/emoji_service.dart';
import 'package:zync_app/core/widgets/status_widget.dart';
import 'package:zync_app/widgets/status_selector_overlay.dart';

/// Bottom Sheet con grid de emojis para cambiar estado del usuario
/// REFACTORED: Ahora carga emojis dinámicamente desde Firebase
class EmojiStatusBottomSheet extends ConsumerStatefulWidget {
  const EmojiStatusBottomSheet({super.key});

  @override
  ConsumerState<EmojiStatusBottomSheet> createState() => _EmojiStatusBottomSheetState();
}

class _EmojiStatusBottomSheetState extends ConsumerState<EmojiStatusBottomSheet> {
  bool _isUpdating = false;
  StatusType? _currentStatus;
  List<StatusType>? _availableStatuses;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController(); // Controller para scrollbar

  @override
  void initState() {
    super.initState();
    _loadAvailableStatuses();
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Limpiar controller
    super.dispose();
  }

  /// Carga los emojis predefinidos + personalizados desde Firebase
  Future<void> _loadAvailableStatuses() async {
    try {
      // Obtener circleId del usuario actual
      final user = await FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      final circleId = userDoc.data()?['circleId'] as String?;
      if (circleId == null) throw Exception('Usuario sin círculo');

      // Cargar predefinidos + personalizados
      final statuses = await EmojiService.getAllEmojisForCircle(circleId);
      setState(() {
        _availableStatuses = statuses;
        _isLoading = false;
      });
    } catch (e) {
      // Usar fallback si Firebase falla
      setState(() {
        _availableStatuses = StatusType.fallbackPredefined;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(StatusType newStatus) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
      _currentStatus = newStatus;
    });

    // Usar el servicio extraído - MISMA lógica, diferente ubicación
    final result = await StatusService.updateUserStatus(newStatus);

    if (result.isSuccess) {
      // Notify the widget service about the status change
      await StatusWidgetService.onStatusChanged(
        status: newStatus,
        circleId: 'active', // We'll track the active circle later
      );

      // Pequeña pausa para mostrar feedback visual
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.of(context).pop();

        // Point 16: Mensaje especial para SOS con GPS
        if (newStatus.id == 'sos' && result.coordinates != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.sos, color: Colors.white),
                  const SizedBox(width: 8),
                  const Icon(Icons.location_on, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '🆘 SOS enviado con ubicación GPS a tu círculo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (newStatus.id == 'sos') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.sos, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '🆘 SOS enviado (sin ubicación GPS disponible)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          // Mostrar confirmación sutil para otros estados
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(newStatus.emoji),
                  const SizedBox(width: 8),
                  Text('Estado actualizado: ${newStatus.description}'),
                ],
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green[700],
            ),
          );
        }
      }
    } else {
      // Manejar error - MISMA UX que antes
      setState(() {
        _isUpdating = false;
        _currentStatus = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${result.errorMessage ?? 'Error desconocido'}'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75, // Máximo 75% de la pantalla
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle visual para indicar que es draggable
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          // Grid de estados (diseño minimalista) - SCROLLABLE
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(color: Color(0xFF1CE4B3)),
              ),
            )
          else
            Flexible(
              child: Scrollbar(
                controller: _scrollController, // Controller explícito
                thumbVisibility: true,
                thickness: 6, // Más grueso para mejor visibilidad
                radius: const Radius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 16.0),
                  child: GridView.builder(
                    controller: _scrollController, // Mismo controller
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _availableStatuses!.length,
                    itemBuilder: (context, index) {
                      final status = _availableStatuses![index];
                      final isSelected = _currentStatus == status;
                      final isUpdating = _isUpdating && isSelected;

                      return GestureDetector(
                        onTap: () => _updateStatus(status),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1CE4B3).withOpacity(0.15) : const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF1CE4B3) : Colors.grey[700]!,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF1CE4B3).withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isUpdating) ...[
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1CE4B3)),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  status.emoji,
                                  style: const TextStyle(fontSize: 32),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                status.description,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? const Color(0xFF1CE4B3) : Colors.grey[300],
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          // Padding bottom para safe area (más compacto)
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

/// Función helper para mostrar el modal unificado
void showEmojiStatusBottomSheet(BuildContext context) {
  // Usar el mismo modal que las notificaciones para consistencia
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false, // Permite transparencia
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatusSelectorOverlay(
          onClose: () {
            print('[EmojiModal] Modal cerrado por usuario');
          },
        );
      },
    ),
  );
}

// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:zync_app/features/circle/domain/entities/user_status.dart';
// import 'package:zync_app/features/circle/domain/usecases/send_user_status.dart';
// import 'package:zync_app/features/auth/presentation/provider/auth_provider.dart';
// import 'package:zync_app/features/auth/presentation/provider/auth_state.dart';
// import 'package:zync_app/features/circle/presentation/provider/circle_provider.dart';
// import 'package:zync_app/features/circle/presentation/provider/circle_state.dart';
// import 'package:zync_app/core/di/injection_container.dart' as di;

// class EmojiModal extends ConsumerStatefulWidget {
//   const EmojiModal({super.key});

//   @override
//   ConsumerState<EmojiModal> createState() => _EmojiModalState();
// }

// class _EmojiModalState extends ConsumerState<EmojiModal> {
//   bool _showCheck = false;
//   bool _isSending = false;

//   // Mapear emojis del modal con StatusType existentes
//   final List<StatusType> emojis = const [
//     StatusType.leave,    // 🚶‍♂️ Saliendo
//     StatusType.busy,     // 🔥 Ocupado
//     StatusType.fine,     // 😊 Bien
//     StatusType.sad,      // 😢 Mal
//     StatusType.ready,    // ✅ Listo
//     StatusType.sos,      // 🆘 SOS
//   ];

//   Future<void> _onStatusTap(StatusType status) async {
//     final authState = ref.read(authProvider);
//     final circleState = ref.read(circleProvider);
    
//     final userId = authState is Authenticated ? authState.user.uid : null;
//     String? circleId;
//     if (circleState is CircleLoaded) {
//       circleId = circleState.circle.id;
//     }

//     if (userId != null && circleId != null && !_isSending) {
//       setState(() => _isSending = true);
//       try {
//         final sendUserStatus = di.sl<SendUserStatus>();
//         await sendUserStatus(SendUserStatusParams(
//           circleId: circleId,
//           statusType: status,
//         ));
//         setState(() => _showCheck = true);
//         await Future.delayed(const Duration(milliseconds: 900));
//         if (mounted) Navigator.of(context).pop();
//       } catch (e) {
//         // Si hay error, mostrar mensaje pero cerrar modal
//         if (mounted) {
//           Navigator.of(context).pop();
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('❌ Error: $e'),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       }
//     } else {
//       if (mounted) Navigator.of(context).pop();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       backgroundColor: Colors.white,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       child: Container(
//         constraints: const BoxConstraints(maxWidth: 350, maxHeight: 400),
//         padding: const EdgeInsets.all(20.0),
//         child: Stack(
//           alignment: Alignment.center,
//           children: [
//             AnimatedOpacity(
//               opacity: _showCheck ? 0.0 : 1.0,
//               duration: const Duration(milliseconds: 250),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const SizedBox(height: 10),
//                   Flexible(
//                     child: GridView.builder(
//                       shrinkWrap: true,
//                       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                         crossAxisCount: 3,
//                         crossAxisSpacing: 12,
//                         mainAxisSpacing: 12,
//                         childAspectRatio: 1,
//                       ),
//                       itemCount: emojis.length,
//                       itemBuilder: (context, index) {
//                         final emoji = emojis[index];
//                         return GestureDetector(
//                           onTap: () => _onStatusTap(emoji),
//                           child: Container(
//                             decoration: BoxDecoration(
//                               color: Colors.grey[100],
//                               borderRadius: BorderRadius.circular(12),
//                               border: Border.all(color: Colors.grey[300]!),
//                             ),
//                             child: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Text(
//                                   emoji.emoji,
//                                   style: const TextStyle(fontSize: 24),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Flexible(
//                                   child: Text(
//                                     emoji.description,
//                                     style: const TextStyle(fontSize: 10),
//                                     textAlign: TextAlign.center,
//                                     maxLines: 1,
//                                     overflow: TextOverflow.ellipsis,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   TextButton(
//                     onPressed: () => Navigator.of(context).pop(),
//                     child: const Text('Cerrar'),
//                   ),
//                 ],
//               ),
//             ),
//             AnimatedScale(
//               scale: _showCheck ? 1.0 : 0.7,
//               duration: const Duration(milliseconds: 350),
//               curve: Curves.easeOutBack,
//               child: AnimatedOpacity(
//                 opacity: _showCheck ? 1.0 : 0.0,
//                 duration: const Duration(milliseconds: 250),
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.green[100],
//                     shape: BoxShape.circle,
//                   ),
//                   padding: const EdgeInsets.all(24),
//                   child: Icon(Icons.check_circle_rounded, color: Colors.green[700], size: 56),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:zync_app/features/circle/domain/entities/user_status.dart';
// import 'package:zync_app/features/circle/domain/usecases/send_user_status.dart';
// import 'package:zync_app/features/auth/presentation/provider/auth_provider.dart';
// import 'package:zync_app/features/auth/presentation/provider/auth_state.dart';
// import 'package:zync_app/features/circle/presentation/provider/circle_provider.dart';
// import 'package:zync_app/features/circle/presentation/provider/circle_state.dart';
// import 'package:zync_app/core/di/injection_container.dart' as di;

// class EmojiModal extends ConsumerStatefulWidget {
//   const EmojiModal({super.key});

//   @override
//   ConsumerState<EmojiModal> createState() => _EmojiModalState();
// }

// class _EmojiModalState extends ConsumerState<EmojiModal> {
//   bool _showCheck = false;
//   bool _isSending = false;

//   // Mapear emojis del modal con StatusType existentes
//   final List<StatusType> emojis = const [
//     StatusType.leave,    // 🚶‍♂️ Saliendo
//     StatusType.busy,     // 🔥 Ocupado
//     StatusType.fine,     // 😊 Bien
//     StatusType.sad,      // 😢 Mal
//     StatusType.ready,    // ✅ Listo
//     StatusType.sos,      // 🆘 SOS
//   ];

//   Future<void> _onStatusTap(StatusType status) async {
//     final authState = ref.read(authProvider);
//     final circleState = ref.read(circleProvider);
    
//     final userId = authState is Authenticated ? authState.user.uid : null;
//     String? circleId;
//     if (circleState is CircleLoaded) {
//       circleId = circleState.circle.id;
//     }

//     if (userId != null && circleId != null && !_isSending) {
//       setState(() => _isSending = true);
//       try {
//         final sendUserStatus = di.sl<SendUserStatus>();
//         await sendUserStatus(SendUserStatusParams(
//           circleId: circleId,
//           statusType: status,
//         ));
//         setState(() => _showCheck = true);
//         await Future.delayed(const Duration(milliseconds: 900));
//         if (mounted) Navigator.of(context).pop();
//       } catch (e) {
//         // Si hay error, mostrar mensaje pero cerrar modal
//         if (mounted) {
//           Navigator.of(context).pop();
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('❌ Error: $e'),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       }
//     } else {
//       if (mounted) Navigator.of(context).pop();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       backgroundColor: Colors.white,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       child: Container(
//         constraints: const BoxConstraints(maxWidth: 350, maxHeight: 400),
//         padding: const EdgeInsets.all(20.0),
//         child: Stack(
//           alignment: Alignment.center,
//           children: [
//             AnimatedOpacity(
//               opacity: _showCheck ? 0.0 : 1.0,
//               duration: const Duration(milliseconds: 250),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const Text(
//                     '🎯 ¡FUNCIONÓ! Modal desde notificación',
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
//                     textAlign: TextAlign.center,
//                   ),
//                   const SizedBox(height: 20),
//                   Flexible(
//                     child: GridView.builder(
//                       shrinkWrap: true,
//                       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                         crossAxisCount: 3,
//                         crossAxisSpacing: 12,
//                         mainAxisSpacing: 12,
//                         childAspectRatio: 1,
//                       ),
//                       itemCount: emojis.length,
//                       itemBuilder: (context, index) {
//                         final emoji = emojis[index];
//                         return GestureDetector(
//                           onTap: () => _onStatusTap(emoji),
//                           child: Container(
//                             decoration: BoxDecoration(
//                               color: Colors.grey[100],
//                               borderRadius: BorderRadius.circular(12),
//                               border: Border.all(color: Colors.grey[300]!),
//                             ),
//                             child: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Text(
//                                   emoji.emoji,
//                                   style: const TextStyle(fontSize: 24),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Flexible(
//                                   child: Text(
//                                     emoji.description,
//                                     style: const TextStyle(fontSize: 10),
//                                     textAlign: TextAlign.center,
//                                     maxLines: 1,
//                                     overflow: TextOverflow.ellipsis,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   TextButton(
//                     onPressed: () => Navigator.of(context).pop(),
//                     child: const Text('Cerrar'),
//                   ),
//                 ],
//               ),
//             ),
//             AnimatedScale(
//               scale: _showCheck ? 1.0 : 0.7,
//               duration: const Duration(milliseconds: 350),
//               curve: Curves.easeOutBack,
//               child: AnimatedOpacity(
//                 opacity: _showCheck ? 1.0 : 0.0,
//                 duration: const Duration(milliseconds: 250),
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.green[100],
//                     shape: BoxShape.circle,
//                   ),
//                   padding: const EdgeInsets.all(24),
//                   child: Icon(Icons.check_circle_rounded, color: Colors.green[700], size: 56),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }