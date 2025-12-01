// lib/core/services/emoji_management_service.dart
// Servicio para CRUD de emojis personalizados

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';
import 'emoji_service.dart';
import 'emoji_cache_service.dart';

/// Servicio para crear, actualizar y eliminar emojis personalizados
///
/// Responsabilidades:
/// - Crear custom emojis con validaciones
/// - Eliminar custom emojis (solo si eres el creador)
/// - Validar límites (10 custom máx por círculo)
/// - Validar duplicados
class EmojiManagementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Límite freemium de custom emojis por círculo
  static const int maxCustomEmojis = 10;

  /// Crea un nuevo emoji personalizado
  ///
  /// Validaciones:
  /// - Máximo 10 custom emojis por círculo
  /// - Nombre 2-30 caracteres
  /// - No emoji+label duplicado
  ///
  /// Retorna el ID del emoji creado o null si falla
  static Future<String?> createCustomEmoji({
    required String circleId,
    required String userId,
    required String emoji,
    required String label,
  }) async {
    try {
      log('[EmojiMgmt] 📝 Creando custom emoji: $emoji $label');

      // Validación 1: Nombre apropiado
      final trimmedLabel = label.trim();
      if (trimmedLabel.length < 2 || trimmedLabel.length > 30) {
        log('[EmojiMgmt] ❌ Label inválido (debe ser 2-30 chars)');
        throw Exception('El nombre debe tener entre 2 y 30 caracteres');
      }

      // Validación 2: Verificar límite de 10 custom emojis
      final existingCustoms = await _firestore.collection('circles').doc(circleId).collection('customEmojis').get();

      if (existingCustoms.docs.length >= maxCustomEmojis) {
        log('[EmojiMgmt] ❌ Límite alcanzado (${existingCustoms.docs.length}/$maxCustomEmojis)');
        throw Exception(
            'Has alcanzado el límite de estados personalizados ($maxCustomEmojis). Borra alguno para crear uno nuevo.');
      }

      // Validación 3: No duplicar emoji + label
      final isDuplicate = existingCustoms.docs.any((doc) {
        final data = doc.data();
        return data['emoji'] == emoji && data['label'] == trimmedLabel;
      });

      if (isDuplicate) {
        log('[EmojiMgmt] ❌ Emoji+label duplicado');
        throw Exception('Ya existe un estado con ese emoji y nombre');
      }

      // Crear el custom emoji
      final customEmojiRef = _firestore.collection('circles').doc(circleId).collection('customEmojis').doc();

      final now = DateTime.now();
      final customEmojiData = {
        'id': customEmojiRef.id,
        'emoji': emoji,
        'label': trimmedLabel,
        'shortLabel': trimmedLabel.length > 6 ? '${trimmedLabel.substring(0, 6)}.' : trimmedLabel,
        'category': 'custom', // Categoría para custom emojis
        'order': 999, // Order alto para que aparezcan al final
        'isPredefined': false,
        'canDelete': true,
        'createdBy': userId,
        'createdAt': Timestamp.fromDate(now),
        'usageCount': 0,
        'lastUsed': null,
      };

      await customEmojiRef.set(customEmojiData);

      // Limpiar caché para que se recarguen los custom emojis
      EmojiService.clearCache();

      // Sincronizar cache nativo para que el modal de Kotlin muestre el nuevo emoji
      await EmojiCacheService.syncEmojisToNativeCache();

      log('[EmojiMgmt] ✅ Custom emoji creado: ${customEmojiRef.id}');
      return customEmojiRef.id;
    } catch (e) {
      log('[EmojiMgmt] ❌ Error creando custom emoji: $e');
      rethrow;
    }
  }

  /// Elimina un emoji personalizado
  ///
  /// Solo el creador puede borrar su emoji
  /// Si alguien del círculo lo está usando, cambia su estado a "available"
  ///
  /// Retorna true si se borró correctamente
  static Future<bool> deleteCustomEmoji({
    required String circleId,
    required String userId,
    required String emojiId,
  }) async {
    try {
      log('[EmojiMgmt] 🗑️ Borrando custom emoji: $emojiId');

      final customEmojiRef = _firestore.collection('circles').doc(circleId).collection('customEmojis').doc(emojiId);

      final customEmojiDoc = await customEmojiRef.get();

      if (!customEmojiDoc.exists) {
        log('[EmojiMgmt] ❌ Emoji no existe');
        throw Exception('El estado no existe');
      }

      final createdBy = customEmojiDoc.data()?['createdBy'] as String?;

      // Validación: Solo el creador puede borrar
      if (createdBy != userId) {
        log('[EmojiMgmt] ❌ Usuario no es el creador');
        throw Exception('Solo el creador puede borrar este estado');
      }

      // Buscar miembros que estén usando este emoji
      final membersRef = _firestore.collection('circles').doc(circleId).collection('members');

      final membersSnapshot = await membersRef.where('currentState.emojiId', isEqualTo: emojiId).get();

      // Cambiar estado a "available" para miembros que lo usan
      final batch = _firestore.batch();

      for (final memberDoc in membersSnapshot.docs) {
        log('[EmojiMgmt] 🔄 Cambiando estado de ${memberDoc.id} a "available"');
        batch.update(memberDoc.reference, {
          'currentState': {
            'emojiId': 'available',
            'emoji': '🟢',
            'label': 'Disponible',
            'shortLabel': 'Libre',
            'source': 'auto', // Auto-change por borrado
            'priority': 4,
            'updatedAt': Timestamp.now(),
          }
        });
      }

      // Borrar el emoji
      batch.delete(customEmojiRef);

      await batch.commit();

      // Limpiar caché para que se recarguen los custom emojis
      EmojiService.clearCache();

      // Sincronizar cache nativo para que el modal de Kotlin se actualice
      await EmojiCacheService.syncEmojisToNativeCache();

      log('[EmojiMgmt] ✅ Custom emoji borrado, ${membersSnapshot.docs.length} usuarios afectados');
      return true;
    } catch (e) {
      log('[EmojiMgmt] ❌ Error borrando custom emoji: $e');
      rethrow;
    }
  }

  /// Obtiene el conteo actual de custom emojis del círculo
  static Future<int> getCustomEmojiCount(String circleId) async {
    try {
      final snapshot = await _firestore.collection('circles').doc(circleId).collection('customEmojis').get();

      return snapshot.docs.length;
    } catch (e) {
      log('[EmojiMgmt] ❌ Error obteniendo conteo: $e');
      return 0;
    }
  }

  /// Verifica si el usuario puede borrar un emoji específico
  static Future<bool> canDeleteEmoji({
    required String circleId,
    required String userId,
    required String emojiId,
  }) async {
    try {
      final customEmojiDoc =
          await _firestore.collection('circles').doc(circleId).collection('customEmojis').doc(emojiId).get();

      if (!customEmojiDoc.exists) return false;

      final createdBy = customEmojiDoc.data()?['createdBy'] as String?;
      return createdBy == userId;
    } catch (e) {
      log('[EmojiMgmt] ❌ Error verificando permisos: $e');
      return false;
    }
  }

  /// Obtiene información sobre el uso de un emoji en el círculo
  /// Retorna un mapa con:
  /// - usageCount: cuántos lo han usado en total
  /// - currentUsers: lista de nombres de usuarios que lo usan ahora
  static Future<Map<String, dynamic>> getEmojiUsageInfo({
    required String circleId,
    required String emojiId,
  }) async {
    try {
      final membersSnapshot = await _firestore
          .collection('circles')
          .doc(circleId)
          .collection('members')
          .where('currentState.emojiId', isEqualTo: emojiId)
          .get();

      final currentUsers = membersSnapshot.docs.map((doc) {
        return doc.data()['nickname'] as String? ?? 'Usuario';
      }).toList();

      return {
        'currentUsers': currentUsers,
        'currentUsersCount': currentUsers.length,
      };
    } catch (e) {
      log('[EmojiMgmt] ❌ Error obteniendo info de uso: $e');
      return {
        'currentUsers': [],
        'currentUsersCount': 0,
      };
    }
  }
}
