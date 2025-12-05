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

  /// Sincroniza emojis desde Firebase a SharedPreferences para acceso nativo
  /// Incluye tanto predefinidos como personalizados del círculo del usuario
  static Future<void> syncEmojisToNativeCache() async {
    try {
      debugPrint('[EmojiCacheService] 🔄 Sincronizando emojis a cache nativo...');

      // Cargar emojis predefinidos
      final predefinedEmojis = await EmojiService.getPredefinedEmojis();

      // Intentar cargar emojis personalizados del círculo del usuario
      List<dynamic> allEmojis = [];

      try {
        // Obtener circleId del usuario actual
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

          final circleId = userDoc.data()?['circleId'] as String?;
          if (circleId != null) {
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
    } catch (e) {
      debugPrint('[EmojiCacheService] ❌ Error sincronizando: $e');
    }
  }

  /// Limpia el cache nativo
  static Future<void> clearNativeCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    debugPrint('[EmojiCacheService] 🗑️ Cache nativo limpiado');
  }
}
