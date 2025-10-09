import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zync_app/features/circle/domain_old/entities/user_status.dart';
import '../../notifications/notification_service.dart';
import 'app_badge_service.dart';
import 'dart:async';
import 'dart:developer';

/// Servicio centralizado para actualizar estados de usuario
/// Extraído de EmojiStatusBottomSheet para reutilización en widgets
class StatusService {
  static StreamSubscription<DocumentSnapshot>? _circleStatusListener;
  
  /// Inicializar el listener de cambios de estado para badge
  static Future<void> initializeStatusListener() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Obtener el circleId del usuario
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
          
      final circleId = userDoc.data()?['circleId'] as String?;
      if (circleId == null) return;
      
      // Cancelar listener anterior si existe
      await _circleStatusListener?.cancel();
      
      // Escuchar cambios en memberStatus del círculo
      _circleStatusListener = FirebaseFirestore.instance
          .collection('circles')
          .doc(circleId)
          .snapshots()
          .listen(_handleCircleStatusChange);
          
      log('[StatusService] Status listener initialized for circle: $circleId');
    } catch (e) {
      log('[StatusService] Error initializing status listener: $e');
    }
  }
  
  /// Manejar cambios de estado en el círculo
  static void _handleCircleStatusChange(DocumentSnapshot snapshot) {
    try {
      if (!snapshot.exists) return;
      
      final data = snapshot.data() as Map<String, dynamic>?;
      final memberStatus = data?['memberStatus'] as Map<String, dynamic>?;
      
      if (memberStatus == null) return;
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      // Verificar cambios de otros miembros (no del usuario actual)
      memberStatus.forEach((userId, statusData) {
        if (userId != currentUser.uid && statusData is Map<String, dynamic>) {
          final timestamp = statusData['timestamp'] as Timestamp?;
          final statusType = statusData['statusType'] as String?;
          
          if (timestamp != null && statusType != null) {
            // Procesar cambio de estado para badge
            AppBadgeService.handleStatusChange(
              userId: userId,
              newStatus: statusType,
              changeTime: timestamp.toDate(),
            );
          }
        }
      });
    } catch (e) {
      log('[StatusService] Error handling circle status change: $e');
    }
  }
  
  /// Detener el listener de cambios de estado
  static Future<void> disposeStatusListener() async {
    await _circleStatusListener?.cancel();
    _circleStatusListener = null;
    log('[StatusService] Status listener disposed');
  }
  /// Actualiza el estado del usuario actual en su círculo
  /// 
  /// Throws [Exception] si:
  /// - Usuario no está autenticado
  /// - Usuario no pertenece a ningún círculo
  /// - Error en Firebase
  static Future<StatusUpdateResult> updateUserStatus(StatusType newStatus) async {
    try {
      log('[StatusService] Actualizando estado a: ${newStatus.description} ${newStatus.emoji}');
      
      // Actualización directa a Firestore sin capas intermedias complejas
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener el circleId del usuario
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
          
      final circleId = userDoc.data()?['circleId'] as String?;
      if (circleId == null) {
        throw Exception('Usuario no está en ningún círculo');
      }

      // Actualizar el estado en el círculo
      final batch = FirebaseFirestore.instance.batch();
      
      // Actualizar memberStatus en el documento del círculo
      final statusData = {
        'userId': user.uid,
        'statusType': newStatus.name,
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      batch.update(
        FirebaseFirestore.instance.collection('circles').doc(circleId),
        {'memberStatus.${user.uid}': statusData}
      );
      
      // Crear evento en historial (opcional, si existe)
      final historyRef = FirebaseFirestore.instance
          .collection('circles')
          .doc(circleId)
          .collection('statusEvents')
          .doc();
          
      batch.set(historyRef, {
        'uid': user.uid,
        'statusType': newStatus.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      log('[StatusService] ✅ Estado actualizado exitosamente');
      
      // Actualizar notificación persistente con nuevo estado
      await _updatePersistentNotification(newStatus);
      
      return StatusUpdateResult.success(newStatus);
      
    } catch (e) {
      log('[StatusService] Error actualizando estado: $e');
      return StatusUpdateResult.error(e.toString());
    }
  }

  /// Actualiza la notificación persistente con el nuevo estado
  static Future<void> _updatePersistentNotification(StatusType status) async {
    try {
      await NotificationService.showQuickActionNotification(currentStatus: status);
    } catch (e) {
      log('[StatusService] Error actualizando notificación persistente: $e');
      // No lanzamos la excepción para no afectar el flujo principal
    }
  }
}

/// Resultado de la actualización de estado
class StatusUpdateResult {
  final bool isSuccess;
  final StatusType? status;
  final String? errorMessage;

  StatusUpdateResult._({
    required this.isSuccess,
    this.status,
    this.errorMessage,
  });

  factory StatusUpdateResult.success(StatusType status) {
    return StatusUpdateResult._(
      isSuccess: true,
      status: status,
    );
  }

  factory StatusUpdateResult.error(String message) {
    return StatusUpdateResult._(
      isSuccess: false,
      errorMessage: message,
    );
  }
}