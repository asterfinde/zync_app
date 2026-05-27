import 'package:flutter/foundation.dart';
import '../../../../core/cache/in_memory_cache.dart';
import '../../../../core/cache/persistent_cache.dart';
import '../../../../services/circle_service.dart';

/// Capa de acceso a datos de miembros (nicknames + memberData).
/// Encapsula InMemoryCache + PersistentCache + CircleService.
/// Extraído de in_circle_view.dart en Sem 5 Día 5.
class MemberDataRepository {
  final String circleId;
  final CircleService _service;

  MemberDataRepository({required this.circleId, CircleService? service})
      : _service = service ?? CircleService();

  String get _nicknamesKey => 'nicknames_$circleId';
  String get _memberDataKey => 'member_data_$circleId';

  /// True si la capa de cache persistente está lista para leer/escribir.
  bool get isPersistentCacheReady => PersistentCache.isInitialized;

  /// Carga inicial sincrónica desde cache (memoria primero, luego disco).
  /// Retorna null si no hay nada cacheado.
  ({Map<String, String> nicknames, Map<String, Map<String, dynamic>> memberData})?
      loadFromCache() {
    final memNicknames =
        InMemoryCache.get<Map<String, String>>(_nicknamesKey);
    final memData =
        InMemoryCache.get<Map<String, Map<String, dynamic>>>(_memberDataKey);

    if (memNicknames != null && memData != null) {
      return (nicknames: memNicknames, memberData: memData);
    }

    final diskNicknames = PersistentCache.loadNicknames();
    final diskData = PersistentCache.loadMemberData();
    if (diskNicknames.isNotEmpty || diskData.isNotEmpty) {
      // Promote disk → memory.
      InMemoryCache.set(_nicknamesKey, diskNicknames);
      InMemoryCache.set(_memberDataKey, diskData);
      return (nicknames: diskNicknames, memberData: diskData);
    }
    return null;
  }

  void saveNicknames(Map<String, String> nicknames) {
    InMemoryCache.set(_nicknamesKey, nicknames);
    PersistentCache.saveNicknames(nicknames);
  }

  void saveMemberData(Map<String, Map<String, dynamic>> data) {
    InMemoryCache.set(_memberDataKey, data);
    PersistentCache.saveMemberData(data);
  }

  void saveAll(
    Map<String, String> nicknames,
    Map<String, Map<String, dynamic>> data,
  ) {
    saveNicknames(nicknames);
    saveMemberData(data);
  }

  /// Carga los nicknames desde Firestore (con fallback a '...' si falla).
  Future<Map<String, String>> fetchNicknames(List<String> memberIds) async {
    final futures = memberIds.map((uid) async {
      try {
        final doc = await _service.getUserDoc(uid);
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final nickname = data['nickname'] as String? ?? '';
          final email = data['email'] as String? ?? '';
          final name = data['name'] as String? ?? '';
          String finalNickname;
          if (nickname.isNotEmpty) {
            finalNickname = nickname;
          } else if (name.isNotEmpty) {
            finalNickname = name;
          } else if (email.isNotEmpty) {
            finalNickname = email.split('@')[0];
          } else {
            finalNickname = '...';
          }
          return MapEntry(uid, finalNickname);
        }
        return MapEntry(uid, '...');
      } catch (e) {
        debugPrint('[MemberDataRepository] Error fetching nickname for $uid: $e');
        return MapEntry(uid, '...');
      }
    });
    final results = await Future.wait(futures);
    return Map.fromEntries(results);
  }
}
