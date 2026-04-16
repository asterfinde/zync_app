// lib/core/services/emoji_service.dart
// Servicio para gestionar emojis predefinidos y personalizados

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zync_app/core/models/user_status.dart';
import 'dart:developer';

/// Servicio para cargar y gestionar estados/emojis desde Firebase
///
/// Responsabilidades:
/// - Cargar emojis predefinidos desde /predefinedEmojis
/// - Cargar emojis personalizados desde /circles/{id}/customEmojis
/// - Cache en memoria para performance
/// - Fallback a hardcoded si Firebase falla
class EmojiService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache en memoria para evitar lecturas repetidas
  static List<StatusType>? _cachedPredefined;
  static final Map<String, List<StatusType>> _cachedCustomByCircle = {};

  /// Obtiene todos los emojis predefinidos desde Firebase
  ///
  /// Carga desde /predefinedEmojis ordenados por 'order'
  /// Si falla, retorna lista hardcoded de fallback
  /// Cachea resultado en memoria para siguientes llamadas
  static Future<List<StatusType>> getPredefinedEmojis() async {
    // Retornar cache si existe
    if (_cachedPredefined != null) {
      log('[EmojiService] ✓ Predefinidos desde cache (${_cachedPredefined!.length})');
      return _cachedPredefined!;
    }

    try {
      log('[EmojiService] 📡 Cargando predefinidos desde Firebase...');

      final snapshot = await _firestore.collection('predefinedEmojis').orderBy('order').get();

      if (snapshot.docs.isEmpty) {
        log('[EmojiService] ⚠️ Firebase vacío, usando fallback hardcoded');
        _cachedPredefined = StatusType.fallbackPredefined;
        return _cachedPredefined!;
      }

      _cachedPredefined = snapshot.docs.map((doc) => StatusType.fromFirestore(doc)).toList();

      log('[EmojiService] ✓ ${_cachedPredefined!.length} predefinidos cargados desde Firebase');
      log('[DIAG-GRID] IDs en /predefinedEmojis: ${_cachedPredefined!.map((e) => e.id).toList()}');
      return _cachedPredefined!;
    } catch (e) {
      log('[EmojiService] ❌ Error cargando desde Firebase: $e');
      log('[EmojiService] 🔄 Usando fallback hardcoded');
      _cachedPredefined = StatusType.fallbackPredefined;
      return _cachedPredefined!;
    }
  }

  /// Obtiene emojis personalizados de un círculo específico
  ///
  /// Carga desde /circles/{circleId}/customEmojis
  /// Retorna lista vacía si no hay custom o si hay error
  static Future<List<StatusType>> getCustomEmojis(String circleId) async {
    // Retornar cache si existe
    if (_cachedCustomByCircle.containsKey(circleId)) {
      log('[EmojiService] ✓ Custom del círculo $circleId desde cache');
      return _cachedCustomByCircle[circleId]!;
    }

    try {
      log('[EmojiService] 📡 Cargando custom del círculo $circleId...');

      final snapshot = await _firestore
          .collection('circles')
          .doc(circleId)
          .collection('customEmojis')
          .orderBy('usageCount', descending: true) // Más usados primero
          .get();

      final customEmojis = snapshot.docs.map((doc) => StatusType.fromFirestore(doc)).toList();

      _cachedCustomByCircle[circleId] = customEmojis;

      log('[EmojiService] ✓ ${customEmojis.length} custom cargados');
      return customEmojis;
    } catch (e) {
      log('[EmojiService] ❌ Error cargando custom: $e');
      return [];
    }
  }

  /// Obtiene TODOS los emojis disponibles para un usuario
  /// (predefinidos + custom del círculo)
  ///
  /// Útil para modal de selección
  /// NUEVO: Filtra estados conflictivos si hay zonas predefinidas configuradas
  static Future<List<StatusType>> getAllEmojisForCircle(String circleId) async {
    final predefined = await getPredefinedEmojis();
    final custom = await getCustomEmojis(circleId);

    // Obtener zonas configuradas para filtrar estados conflictivos
    final configuredZones = await _getConfiguredPredefinedZones(circleId);

    // Si no hay zonas predefinidas, retornar todos los emojis
    if (configuredZones.isEmpty) {
      return [...predefined, ...custom];
    }

    // Filtrar estados manuales que conflictúan con zonas configuradas
    final filteredPredefined = predefined.where((status) {
      // home zone configurada → ocultar estado 'available' cuando sea representado por 🏠
      if (configuredZones.contains('home') && status.id == 'fine' && status.emoji == '🏠') {
        return false;
      }
      // school zone configurada → ocultar estado 'studying' cuando sea representado por 🏫
      if (configuredZones.contains('school') && status.id == 'studying' && status.emoji == '🏫') {
        return false;
      }
      // university zone configurada → ocultar estado 'studying' cuando sea representado por 🎓
      if (configuredZones.contains('university') && status.id == 'studying' && status.emoji == '🎓') {
        return false;
      }
      // work zone configurada → ocultar estado 'busy' cuando sea representado por 💼
      if (configuredZones.contains('work') && status.id == 'busy' && status.emoji == '💼') {
        return false;
      }
      return true;
    }).toList();

    return [...filteredPredefined, ...custom];
  }

  /// Helper: Obtiene tipos de zonas predefinidas configuradas en un círculo
  static Future<List<String>> _getConfiguredPredefinedZones(String circleId) async {
    try {
      final zonesSnapshot = await _firestore
          .collection('circles')
          .doc(circleId)
          .collection('zones')
          .where('isPredefined', isEqualTo: true)
          .get();

      return zonesSnapshot.docs
          .map((doc) => doc.data()['type'] as String?)
          .where((type) => type != null)
          .cast<String>()
          .toList();
    } catch (e) {
      log('[EmojiService] ❌ Error obteniendo zonas configuradas: $e');
      return [];
    }
  }

  /// Busca un emoji por ID en predefinidos
  ///
  /// Útil para convertir String guardado en Firebase → StatusType
  static Future<StatusType?> findPredefinedById(String id) async {
    final predefined = await getPredefinedEmojis();
    try {
      return predefined.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Busca un emoji por ID en custom de un círculo
  static Future<StatusType?> findCustomById(String circleId, String id) async {
    final custom = await getCustomEmojis(circleId);
    try {
      return custom.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Busca un emoji por ID en predefinidos O custom
  static Future<StatusType?> findById(String circleId, String id) async {
    // Buscar primero en predefinidos
    var emoji = await findPredefinedById(id);
    if (emoji != null) return emoji;

    // Si no está, buscar en custom del círculo
    return await findCustomById(circleId, id);
  }

  /// Crea un emoji personalizado para un círculo
  ///
  /// Retorna el StatusType creado o null si falla
  static Future<StatusType?> createCustomEmoji({
    required String circleId,
    required String emoji,
    required String label,
    required String createdBy,
  }) async {
    try {
      log('[EmojiService] 📝 Creando custom: $emoji $label');

      // Generar ID único (lowercase, sin espacios)
      final id = label.toLowerCase().replaceAll(' ', '_');

      final customEmoji = StatusType(
        id: id,
        emoji: emoji,
        label: label,
        shortLabel: label, // Custom usa mismo label para short
        category: 'custom',
        order: 999, // Custom al final
        isPredefined: false,
        canDelete: true,
      );

      // Guardar en Firebase
      await _firestore.collection('circles').doc(circleId).collection('customEmojis').doc(id).set({
        ...customEmoji.toFirestore(),
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'usageCount': 0,
        'lastUsed': null,
      });

      // Invalidar cache
      _cachedCustomByCircle.remove(circleId);

      log('[EmojiService] ✓ Custom creado: $id');
      return customEmoji;
    } catch (e) {
      log('[EmojiService] ❌ Error creando custom: $e');
      return null;
    }
  }

  /// Elimina un emoji personalizado (solo si canDelete = true)
  static Future<bool> deleteCustomEmoji({
    required String circleId,
    required String emojiId,
    required String userId,
  }) async {
    try {
      final doc = await _firestore.collection('circles').doc(circleId).collection('customEmojis').doc(emojiId).get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      final createdBy = data['createdBy'] as String;

      // Solo el creador puede eliminar
      if (createdBy != userId) {
        log('[EmojiService] ❌ Usuario $userId no puede eliminar (creado por $createdBy)');
        return false;
      }

      await doc.reference.delete();

      // Invalidar cache
      _cachedCustomByCircle.remove(circleId);

      log('[EmojiService] ✓ Custom $emojiId eliminado');
      return true;
    } catch (e) {
      log('[EmojiService] ❌ Error eliminando custom: $e');
      return false;
    }
  }

  /// Incrementa contador de uso de un emoji custom
  static Future<void> incrementUsageCount({
    required String circleId,
    required String emojiId,
  }) async {
    try {
      await _firestore.collection('circles').doc(circleId).collection('customEmojis').doc(emojiId).update({
        'usageCount': FieldValue.increment(1),
        'lastUsed': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('[EmojiService] ⚠️ Error incrementando usageCount: $e');
    }
  }

  /// Limpia cache (útil para testing o force refresh)
  static void clearCache() {
    _cachedPredefined = null;
    _cachedCustomByCircle.clear();
    log('[EmojiService] 🧹 Cache limpiado');
  }

  /// Fuerza recarga desde Firebase (invalida cache)
  static Future<List<StatusType>> reloadPredefinedEmojis() async {
    _cachedPredefined = null;
    return await getPredefinedEmojis();
  }
}
