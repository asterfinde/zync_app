import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'emoji_service.dart';
import 'package:flutter/foundation.dart';

/// Servicio para sincronizar emojis de Firebase a cache nativo (SharedPreferences)
/// Esto permite que EmojiDialogActivity (Kotlin) lea los emojis sin depender de Flutter
class EmojiCacheService {
  static const _cacheKey = 'predefined_emojis';

  /// Sincroniza emojis desde Firebase a SharedPreferences para acceso nativo
  static Future<void> syncEmojisToNativeCache() async {
    try {
      debugPrint(
          '[EmojiCacheService] 🔄 Sincronizando emojis a cache nativo...');

      // Cargar emojis desde Firebase
      final emojis = await EmojiService.getPredefinedEmojis();

      // Convertir a JSON simple que Kotlin pueda parsear
      final jsonList = emojis
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

      debugPrint(
          '[EmojiCacheService] ✅ ${emojis.length} emojis sincronizados a cache nativo');
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
