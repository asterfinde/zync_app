import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'emoji_service.dart';
import 'package:flutter/foundation.dart';

/// Servicio para sincronizar emojis de Firebase a cache nativo (SharedPreferences)
/// Esto permite que EmojiDialogActivity (Kotlin) lea los emojis sin depender de Flutter
class EmojiCacheService {
  static const _cacheKey = 'predefined_emojis';

  static const _zonesCacheKey = 'configured_zone_types';

  /// Sincroniza emojis desde Firebase a SharedPreferences para acceso nativo
  /// Incluye tanto predefinidos como personalizados del círculo del usuario
  static Future<void> syncEmojisToNativeCache() async {
    try {
      debugPrint('[EmojiCacheService] 🔄 Sincronizando emojis a cache nativo...');

      // Cargar emojis predefinidos
      final predefinedEmojis = await EmojiService.getPredefinedEmojis();

      // Intentar cargar emojis personalizados del círculo del usuario
      List<dynamic> allEmojis = [];
      String? foundCircleId;

      try {
        // Obtener circleId del usuario actual
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

          final circleId = userDoc.data()?['circleId'] as String?;
          if (circleId != null) {
            foundCircleId = circleId;
            // Cargar emojis personalizados del círculo
            final customEmojis = await EmojiService.getCustomEmojis(circleId);

            // Combinar predefinidos + personalizados
            allEmojis = [...predefinedEmojis, ...customEmojis];
            debugPrint(
                '[EmojiCacheService] 📦 Cargados ${predefinedEmojis.length} predefinidos + ${customEmojis.length} personalizados');
          } else {
            allEmojis = predefinedEmojis;
            debugPrint('[EmojiCacheService] ⚠️ Usuario sin círculo, solo predefinidos');
          }
        } else {
          allEmojis = predefinedEmojis;
          debugPrint('[EmojiCacheService] ⚠️ Usuario no autenticado, solo predefinidos');
        }
      } catch (e) {
        // Si falla la carga de personalizados, usar solo predefinidos
        allEmojis = predefinedEmojis;
        debugPrint('[EmojiCacheService] ⚠️ Error cargando personalizados: $e');
      }

      // Convertir a JSON simple que Kotlin pueda parsear
      final jsonList = allEmojis
          .map((emoji) => {
                'id': emoji.id,
                'emoji': emoji.emoji,
                'shortLabel': emoji.shortLabel,
              })
          .toList();

      final jsonString = jsonEncode(jsonList);

      // Guardar en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonString);

      debugPrint('[EmojiCacheService] ✅ ${allEmojis.length} emojis sincronizados a cache nativo');

      // Sincronizar zonas configuradas para que EmojiDialogActivity pueda bloquearlas
      await _syncZoneTypesToNativeCache(foundCircleId);
    } catch (e) {
      debugPrint('[EmojiCacheService] ❌ Error sincronizando: $e');
    }
  }

  /// Sincroniza los tipos de zona configurados del círculo a SharedPreferences
  static Future<void> _syncZoneTypesToNativeCache(String? circleId) async {
    try {
      final configuredTypes = <String>[];

      if (circleId != null) {
        final zonesSnapshot = await FirebaseFirestore.instance
            .collection('circles')
            .doc(circleId)
            .collection('zones')
            .get();

        for (final doc in zonesSnapshot.docs) {
          final type = doc.data()['type'] as String?;
          if (type != null && ['home', 'school', 'university', 'work'].contains(type)) {
            configuredTypes.add(type);
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_zonesCacheKey, jsonEncode(configuredTypes));
      debugPrint('[EmojiCacheService] ✅ ${configuredTypes.length} zona(s) configurada(s) sincronizada(s): $configuredTypes');
    } catch (e) {
      debugPrint('[EmojiCacheService] ❌ Error sincronizando zonas: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_zonesCacheKey, '[]');
      } catch (_) {}
    }
  }

  /// Limpia el cache nativo
  static Future<void> clearNativeCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    debugPrint('[EmojiCacheService] 🗑️ Cache nativo limpiado');
  }
}
