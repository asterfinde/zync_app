import 'dart:async'; // Necesario para StreamSubscription
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
// Asegúrate que las rutas de importación sean correctas para tu proyecto
import '../../../../services/circle_service.dart';
import '../../../auth/presentation/provider/auth_provider.dart';
import '../../../auth/presentation/provider/auth_state.dart';
// Asumo que emoji_modal.dart exporta la función showEmojiStatusBottomSheet
import '../../../../core/widgets/emoji_modal.dart';
import '../../../../core/services/gps_service.dart';
import '../../../../core/services/status_service.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../../core/models/user_status.dart';
// CACHE-FIRST: Importar caches
import '../../../../core/cache/in_memory_cache.dart';
import '../../../../core/cache/persistent_cache.dart';
// Asumo que tienes una clase Coordinates en gps_service.dart o similar
// import '../../../../core/services/gps_service.dart' show Coordinates;

// ===========================================================================
// SECCIÓN DE DISEÑO: Colores y Estilos basados en la pantalla de referencia
// ===========================================================================

/// Paleta de colores extraída del diseño de la pantalla de Login.
class _AppColors {
  static const Color background = Color(0xFF000000); // Negro puro
  static const Color accent = Color(0xFF1EE9A4); // Verde menta/turquesa
  static const Color textPrimary = Color(0xFFFFFFFF); // Blanco
  static const Color textSecondary =
      Color(0xFF9E9E9E); // Gris para subtítulos y labels
  // static const Color cardBackground =
  //     Color(0xFF1C1C1E); // Gris oscuro para menús y diálogos (comentado: no usado actualmente)
  static const Color cardBorder =
      Color(0xFF3A3A3C); // Borde sutil para tarjetas y divider
  static const Color sosRed = Color(0xFFD32F2F); // Rojo para alertas SOS
}

/// Estilos de texto consistentes con el diseño.
class _AppTextStyles {
  static const TextStyle screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: _AppColors.textPrimary,
    letterSpacing: 1.2,
  );

  static const TextStyle userNickname = TextStyle(
    fontSize: 16,
    color: _AppColors.textSecondary,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: _AppColors.textPrimary,
  );

  static const TextStyle cardSubtitle = TextStyle(
    color: _AppColors.textSecondary,
    fontSize: 14,
  );

  static const TextStyle invitationCode = TextStyle(
    fontFamily: 'monospace',
    fontWeight: FontWeight.bold,
    fontSize: 20,
    color: _AppColors.textPrimary,
    letterSpacing: 1.5,
  );

  static const TextStyle memberNickname = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: _AppColors.textPrimary,
  );

  static const TextStyle memberStatus = TextStyle(
    fontSize: 14,
    color: _AppColors.textSecondary,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle sosStatus = TextStyle(
    fontSize: 14,
    color: _AppColors.sosRed,
    fontWeight: FontWeight.bold,
  );
}

class InCircleView extends ConsumerStatefulWidget {
  final Circle circle;

  const InCircleView({super.key, required this.circle});

  @override
  ConsumerState<InCircleView> createState() => _InCircleViewState();
}

class _InCircleViewState extends ConsumerState<InCircleView> {
  final Map<String, Map<String, dynamic>> _memberDataCache = {};
  bool _isUpdatingStatus = false;
  final Map<String, String> _memberNicknamesCache = {};
  bool _isLoadingNicknames = true;

  // --- INICIO DE LA MODIFICACIÓN ---
  // StreamSubscription para poder cancelarlo en dispose()
  StreamSubscription<DocumentSnapshot>? _circleListenerSubscription;
  // --- FIN DE LA MODIFICACIÓN ---

  @override
  void initState() {
    super.initState();

    // ==================== CACHE-FIRST PATTERN ====================
    // PASO 1: Cargar cache PRIMERO (sin await, sincrónico desde memoria)
    // 🚀 LAZY: Solo cargar si cache está inicializado, si no, esperar postFrameCallback
    if (PersistentCache.isInitialized) {
      _loadFromCache();
    } else {
      // Cache NO inicializado aún, esperar postFrameCallback
      print('⏳ [InCircleView] Cache no listo, esperando inicialización...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (PersistentCache.isInitialized) {
          _loadFromCache();
        } else {
          // Reintentar después
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && PersistentCache.isInitialized) {
              _loadFromCache();
            }
          });
        }
      });
    }

    // PASO 2: Iniciar listeners de Firebase (no bloquean)
    _listenToStatusChanges();

    // PASO 3: Refrescar datos en background (Firebase, sin await)
    _refreshDataInBackground();
    // =============================================================
  }

  // --- INICIO DE LA MODIFICACIÓN ---
  @override
  void dispose() {
    // CACHE-FIRST: Guardar estado antes de dispose
    _saveToCache();

    // Cancelar la suscripción al listener de Firestore para evitar memory leaks
    _circleListenerSubscription?.cancel();
    print("[InCircleView] Listener de círculo cancelado.");
    super.dispose();
  }
  // --- FIN DE LA MODIFICACIÓN ---

  // ========================================================================
  // CACHE-FIRST: Métodos de cache
  // ========================================================================

  /// PASO 1: Cargar desde cache (sincrónico, instantáneo)
  void _loadFromCache() {
    print('⚡ [InCircleView] Cargando desde cache...');

    // Intentar InMemoryCache primero (0ms)
    final memoryNicknames =
        InMemoryCache.get<Map<String, String>>('nicknames_${widget.circle.id}');
    final memoryMemberData =
        InMemoryCache.get<Map<String, Map<String, dynamic>>>(
            'member_data_${widget.circle.id}');

    if (memoryNicknames != null && memoryMemberData != null) {
      print(
          '✅ [InCircleView] Cache en memoria encontrado (${memoryNicknames.length} nicknames)');
      setState(() {
        _memberNicknamesCache.addAll(memoryNicknames);
        _memberDataCache.addAll(memoryMemberData);
        _isLoadingNicknames = false;
      });
      return; // Ya tenemos datos en memoria, no necesitamos disco
    }

    // Si no hay memoria, intentar PersistentCache (disco, ~50-100ms)
    final diskNicknames = PersistentCache.loadNicknames();
    final diskMemberData = PersistentCache.loadMemberData();

    if (diskNicknames.isNotEmpty || diskMemberData.isNotEmpty) {
      print(
          '✅ [InCircleView] Cache en disco encontrado (${diskNicknames.length} nicknames)');
      setState(() {
        _memberNicknamesCache.addAll(diskNicknames);
        _memberDataCache.addAll(diskMemberData);
        _isLoadingNicknames = false;
      });

      // Guardar en memoria para próxima vez
      InMemoryCache.set('nicknames_${widget.circle.id}', diskNicknames);
      InMemoryCache.set('member_data_${widget.circle.id}', diskMemberData);
    } else {
      print('❌ [InCircleView] No hay cache disponible, esperando Firebase...');
    }
  }

  /// PASO 3: Refrescar datos en background (sin bloquear UI)
  void _refreshDataInBackground() {
    print('🔄 [InCircleView] Refrescando datos en background...');

    // Cargar nicknames sin await (no bloquea)
    _getAllMemberNicknames(widget.circle.members).then((nicknames) {
      if (!mounted) return;

      setState(() {
        _memberNicknamesCache.addAll(nicknames);
        _isLoadingNicknames = false;
      });

      // Actualizar ambos caches
      InMemoryCache.set('nicknames_${widget.circle.id}', _memberNicknamesCache);
      PersistentCache.saveNicknames(_memberNicknamesCache);

      print(
          '✅ [InCircleView] Nicknames actualizados (${nicknames.length} items)');
    }).catchError((error) {
      print('❌ [InCircleView] Error refrescando nicknames: $error');
    });
  }

  /// Guardar estado a cache (llamado desde dispose)
  void _saveToCache() {
    print('💾 [InCircleView] Guardando estado a cache...');

    // Guardar en ambos caches
    InMemoryCache.set('nicknames_${widget.circle.id}', _memberNicknamesCache);
    InMemoryCache.set('member_data_${widget.circle.id}', _memberDataCache);

    PersistentCache.saveNicknames(_memberNicknamesCache);
    PersistentCache.saveMemberData(_memberDataCache);

    print(
        '✅ [InCircleView] Estado guardado (${_memberNicknamesCache.length} nicknames, ${_memberDataCache.length} members)');
  }

  // --- loadInitialData() ELIMINADO ---

  void _listenToStatusChanges() {
    // Guardar la suscripción para poder cancelarla después
    _circleListenerSubscription?.cancel(); // Cancelar anterior si existe
    _circleListenerSubscription = FirebaseFirestore.instance
        .collection('circles')
        .doc(widget.circle.id)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return; // Verificar mounted al inicio

      if (!snapshot.exists || snapshot.data() == null) {
        print("[InCircleView] Snapshot no existe o data es null.");
        return; // Salir si no hay datos válidos
      }

      final data = snapshot.data()!;
      final memberStatus = data['memberStatus'] as Map<String, dynamic>?;

      if (memberStatus != null) {
        bool hasChanges = false;
        final Map<String, Map<String, dynamic>> updates = {};

        memberStatus.forEach((memberId, statusData) {
          final newData = _parseMemberData(statusData);
          final oldData = _memberDataCache[memberId];

          if (_hasChanged(oldData, newData)) {
            updates[memberId] = newData;
            hasChanges = true;
          }
        });

        // Asegurarse que mounted sigue siendo true antes de setState
        if (hasChanges && mounted) {
          setState(() {
            updates.forEach((memberId, newData) {
              _memberDataCache[memberId] = newData;
            });
          });

          // CACHE-FIRST: Actualizar caches cuando hay cambios
          InMemoryCache.set(
              'member_data_${widget.circle.id}', _memberDataCache);
          PersistentCache.saveMemberData(_memberDataCache);
          print('✅ [InCircleView] Cache actualizado con nuevos estados');
        }
      }
    }, onError: (error) {
      // <-- Añadir manejo de errores
      print("❌ Error en listener de círculo: $error");
      // Opcional: mostrar un mensaje al usuario si el error es crítico
    });
    print("[InCircleView] Listener de círculo iniciado.");
  }

  Map<String, dynamic> _parseMemberData(dynamic statusData) {
    if (statusData is! Map<String, dynamic>) {
      // Valor por defecto si la data está mal formada
      return {
        'emoji': '❓',
        'status': 'unknown',
        'hasGPS': false,
        'coordinates': null,
        'lastUpdate': null
      };
    }

    final statusType = statusData['statusType'] as String?;
    String emoji = '😊'; // Default emoji

    if (statusType != null) {
      try {
        final statusEnum = StatusType.values.firstWhere(
          (s) => s.name == statusType,
          orElse: () => StatusType.fine, // Fallback seguro
        );
        emoji = statusEnum.emoji;
      } catch (e) {
        print("Error parsing status enum: $e, using default emoji.");
        emoji = '😊'; // Mantener default si hay error
      }
    }

    final coordinates = statusData['coordinates'] as Map<String, dynamic>?;
    final timestamp = statusData['timestamp'];
    DateTime? lastUpdate;
    if (timestamp is Timestamp) {
      lastUpdate = timestamp.toDate();
    }

    return {
      'emoji': emoji,
      'status': statusType ?? 'fine', // Default status si es null
      'coordinates': coordinates,
      'hasGPS': coordinates != null &&
          statusType == 'sos', // GPS solo relevante para SOS
      'lastUpdate': lastUpdate,
    };
  }

  bool _hasChanged(
      Map<String, dynamic>? oldData, Map<String, dynamic> newData) {
    if (oldData == null) return true; // Siempre cambia si no había data previa
    // Comparar campos relevantes
    return oldData['status'] != newData['status'] ||
        oldData['lastUpdate']?.millisecondsSinceEpoch !=
            newData['lastUpdate']?.millisecondsSinceEpoch ||
        oldData['coordinates']?.toString() !=
            newData['coordinates']
                ?.toString(); // Comparación simple para coordenadas
  }

  @override
  Widget build(BuildContext context) {
    final circle = widget.circle;

    return Scaffold(
      backgroundColor: _AppColors.background,
      body: Column(
        children: [
          // --- HEADER ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            color: _AppColors.background,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Zync', style: _AppTextStyles.screenTitle),
                      Text(
                        _getCurrentUserNickname(ref),
                        style: _AppTextStyles.userNickname,
                      ),
                      // 🔧 DEBUG: Timestamp dinámico
                      Text(
                        'Build: ${DateTime.now().toString().substring(0, 16)} (v6 - DYNAMIC)',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1CE7E8),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Ajustes'),
                ),
              ],
            ),
          ),

          // --- BODY ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- CIRCLE INFO CARD ---
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.hub,
                                size: 28, color: _AppColors.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(circle.name,
                                      style: _AppTextStyles.cardTitle),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${circle.members.length} miembros', // Esto se actualizará si circle cambia
                                    style: _AppTextStyles.cardSubtitle,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text('Código de Invitación',
                            style: _AppTextStyles.cardSubtitle),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(circle.invitationCode,
                                  style: _AppTextStyles.invitationCode),
                            ),
                            IconButton(
                              onPressed: () => _copyToClipboard(
                                  context, circle.invitationCode),
                              icon: const Icon(Icons.copy,
                                  size: 24, color: _AppColors.accent),
                              tooltip: 'Copiar código',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Divider(color: _AppColors.cardBorder, thickness: 1),
                  ),

                  // --- MEMBERS HEADER ---
                  const Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 24, color: _AppColors.accent),
                      SizedBox(width: 8),
                      Text('Miembros', style: _AppTextStyles.screenTitle),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- MEMBER LIST ---
                  _isLoadingNicknames
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: _AppColors.accent))
                      : Column(
                          children: _getSortedMembers(circle.members)
                              .asMap()
                              .entries
                              .map((entry) {
                            final index = entry.key;
                            final memberId = entry.value;

                            // Obtener nickname del caché (ya no hay FutureBuilder)
                            final nickname = _memberNicknamesCache[memberId] ??
                                (memberId.length > 8
                                    ? memberId.substring(0, 8)
                                    : memberId);

                            final currentUser =
                                FirebaseAuth.instance.currentUser;
                            final isCurrentUser = currentUser?.uid == memberId;

                            // --- INICIO DE LA MODIFICACIÓN ---
                            // Obtener datos del caché. Si aún no ha llegado el primer snapshot,
                            // usa valores por defecto para evitar errores null.
                            final memberData = _memberDataCache[memberId] ??
                                {
                                  'emoji': '⏳', // Emoji de espera inicial
                                  'status': 'loading',
                                  'hasGPS': false,
                                  'coordinates': null,
                                  'lastUpdate': null,
                                };
                            final status = memberData['status'] ?? 'loading';
                            // --- FIN DE LA MODIFICACIÓN ---

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: _MemberListItem(
                                key: ValueKey('${memberId}_$status'),
                                memberId: memberId,
                                nickname: nickname,
                                isCurrentUser: isCurrentUser,
                                isFirst: index == 0,
                                memberData: memberData,
                                onTap: isCurrentUser
                                    ? () => showEmojiStatusBottomSheet(
                                        context) // Asume que esta función existe y es importada
                                    : null,
                                onOpenMaps: _openGoogleMaps,
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildFooterButton(context),
    );
  }

  // =========================================================================
  // === Métodos Auxiliares (sin cambios respecto a tu código original) ===
  // =========================================================================

  /// Actualización rápida del estado a "fine" (✅)
  Future<void> _quickStatusUpdate() async {
    if (_isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      print('[InCircleView] ✅ Enviando estado rápido: fine (Todo Bien)');
      final result = await StatusService.updateUserStatus(StatusType.fine);

      if (!result.isSuccess && mounted) {
        _showError(context, 'Error: ${result.errorMessage}');
      }
    } catch (e) {
      print('[InCircleView] Error en quickStatusUpdate: $e');
      if (mounted) {
        _showError(context, 'Error actualizando estado');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  /// Construye el botón del footer
  Widget _buildFooterButton(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _isUpdatingStatus ? null : () => _quickStatusUpdate(),
          style: ElevatedButton.styleFrom(
            backgroundColor: _AppColors.accent,
            foregroundColor: _AppColors.background,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isUpdatingStatus)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                  ),
                )
              else
                const Icon(Icons.check_circle),
              const SizedBox(width: 8),
              Text(_isUpdatingStatus ? 'Actualizando...' : 'Todo bien'),
            ],
          ),
        ),
      ),
    );
  }

  /// Obtiene el nickname del usuario actual desde Riverpod
  String _getCurrentUserNickname(WidgetRef ref) {
    final authState = ref.watch(
        authProvider); // Asume que authProvider está definido e importado
    if (authState is Authenticated) {
      return authState.user.nickname.isNotEmpty
          ? authState.user.nickname
          : authState.user.email.split('@')[0];
    }
    return 'Usuario';
  }

  /// Ordena los miembros: usuario actual primero, resto alfabéticamente
  List<String> _getSortedMembers(List<String> members) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return members;

    // Separar usuario actual del resto
    final currentUserList = members.where((id) => id == currentUserId).toList();
    final otherMembers = members.where((id) => id != currentUserId).toList();

    // Ordenar otros miembros alfabéticamente por nickname
    otherMembers.sort((a, b) {
      final nicknameA = _memberNicknamesCache[a] ?? a;
      final nicknameB = _memberNicknamesCache[b] ?? b;
      return nicknameA.toLowerCase().compareTo(nicknameB.toLowerCase());
    });

    // Usuario actual primero, luego el resto ordenado
    return [...currentUserList, ...otherMembers];
  }

  /// Obtiene todos los nicknames de los miembros (llamado desde _loadAllNicknames)
  Future<Map<String, String>> _getAllMemberNicknames(
      List<String> memberIds) async {
    final Map<String, String> nicknames = {};
    // Usar un servicio real si existe, o mantener la lógica directa
    final service = CircleService(); // Asume que esta clase existe

    final futures = memberIds.map((uid) async {
      try {
        final doc = await service.getUserDoc(uid); // Usa el método del servicio
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final nickname = data['nickname'] as String? ?? '';
          final email = data['email'] as String? ?? '';
          final name = data['name'] as String? ?? '';

          String finalNickname;
          if (nickname.isNotEmpty) {
            finalNickname = nickname;
          } else if (name.isNotEmpty)
            finalNickname = name;
          else if (email.isNotEmpty)
            finalNickname = email.split('@')[0];
          else
            finalNickname =
                uid.length > 8 ? uid.substring(0, 8) : uid; // Fallback
          return MapEntry(uid, finalNickname);
        } else {
          final fallback = uid.length > 8 ? uid.substring(0, 8) : uid;
          return MapEntry(uid, fallback); // Fallback si el doc no existe
        }
      } catch (e) {
        print("Error fetching nickname for $uid: $e");
        final fallback = uid.length > 8 ? uid.substring(0, 8) : uid;
        return MapEntry(uid, fallback); // Fallback en caso de error
      }
    });

    final results = await Future.wait(futures);
    for (final entry in results) {
      nicknames[entry.key] = entry.value;
    }
    return nicknames;
  }

  /// Copia texto al portapapeles
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Código copiado al portapapeles!'),
        duration: Duration(seconds: 2),
        backgroundColor: _AppColors.accent,
      ),
    );
  }

  /// Abre Google Maps con las coordenadas SOS
  void _openGoogleMaps(BuildContext context, Map<String, dynamic> coordinates,
      String memberName) async {
    try {
      final latitude = coordinates['latitude'] as double?;
      final longitude = coordinates['longitude'] as double?;
      if (latitude == null || longitude == null) {
        _showError(context, 'Coordenadas GPS no válidas');
        return;
      }
      // Asume que Coordinates existe o adapta la llamada
      final url = GPSService.generateSOSLocationUrl(
        Coordinates(
            latitude: latitude, longitude: longitude), // Adapta si es necesario
        memberName,
      );
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        HapticFeedback.lightImpact();
      } else {
        // ignore: use_build_context_synchronously
        _showError(context, 'No se pudo abrir la aplicación de mapas');
      }
    } catch (e) {
      print("Error opening Google Maps: $e");
      // ignore: use_build_context_synchronously
      _showError(context, 'Error al abrir la ubicación');
    }
  }

  /// Muestra un SnackBar de error
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _AppColors.sosRed,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Muestra diálogo de confirmación para salir del círculo
  // TODO: Usar cuando se active la opción de salir del círculo
  /* void _showLeaveCircleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Salir del Círculo', style: TextStyle(color: _AppColors.textPrimary)),
        content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: _AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar', style: TextStyle(color: _AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
               Navigator.of(context).pop(); // Cerrar diálogo primero
               try {
                  final service = CircleService(); // Asume que esta clase existe
                  await service.leaveCircle(); // Asume que este método existe
                  // La navegación debería manejarse por el StreamBuilder en HomePage al detectar circle == null
               } catch (e) {
                 print("Error leaving circle: $e");
                 if(mounted) {
                    _showError(context, "Error al salir del círculo");
                 }
               }
            },
            child: const Text('Salir', style: TextStyle(color: _AppColors.sosRed)),
          ),
        ],
      ),
    );
  } */
} // Fin de _InCircleViewState

// ==============================================================================
// MEMBER LIST ITEM - Widget individual con diseño ultra minimalista
// ==============================================================================
class _MemberListItem extends StatelessWidget {
  final String memberId;
  final String nickname;
  final bool isCurrentUser;
  final bool isFirst;
  final Map<String, dynamic> memberData;
  final VoidCallback? onTap;
  final Function(BuildContext, Map<String, dynamic>, String) onOpenMaps;

  const _MemberListItem({
    super.key,
    required this.memberId,
    required this.nickname,
    required this.isCurrentUser,
    required this.isFirst,
    required this.memberData,
    this.onTap,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    // Usar valores por defecto más explícitos si vienen del estado 'loading'
    final emoji = memberData['emoji'] as String? ?? '⏳';
    final status = memberData['status'] as String? ?? 'loading';
    final hasGPS = memberData['hasGPS'] as bool? ?? false;
    final coordinates = memberData['coordinates'] as Map<String, dynamic>?;
    final lastUpdate = memberData['lastUpdate'] as DateTime?;
    final isSOS = status == 'sos';

    return Material(
      color: _AppColors.background,
      child: InkWell(
        onTap: (status == 'loading') // No permitir taps mientras carga
            ? null
            : () {
                if (isCurrentUser && onTap != null) {
                  HapticFeedback.mediumImpact();
                  onTap!();
                } else if (hasGPS && coordinates != null) {
                  HapticFeedback.lightImpact();
                  onOpenMaps(context, coordinates, nickname);
                }
              },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Text(emoji,
                        key: ValueKey(status),
                        style: const TextStyle(fontSize: 32)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                                child: Text(nickname,
                                    style: _AppTextStyles.memberNickname,
                                    overflow: TextOverflow.ellipsis)),
                            if (isCurrentUser) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _AppColors.accent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'TÚ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _AppColors.background,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStatusLabel(
                              status), // Mostrará "Cargando..." si es necesario
                          style: isSOS
                              ? _AppTextStyles.sosStatus
                              : _AppTextStyles.memberStatus,
                        ),
                        if (isFirst &&
                            status !=
                                'loading') // No mostrar "Creador" si está cargando
                          Text(
                            'Creador',
                            style: TextStyle(
                              fontSize: 12,
                              color: _AppColors.accent.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (lastUpdate != null)
                    Text(
                      _getTimeAgo(lastUpdate),
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors
                              .grey[600]), // Mantener gris o usar textSecondary
                    ),
                ],
              ),
              // Mostrar sección SOS solo si el status NO es 'loading'
              if (hasGPS && coordinates != null && status != 'loading') ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4.0, vertical: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 20, color: _AppColors.sosRed),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Ubicación SOS compartida',
                          style: TextStyle(
                              fontSize: 13,
                              color: _AppColors.textPrimary,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.red[300]), // Mantener o usar sosRed
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- Método Helper _getStatusLabel ---
  String _getStatusLabel(String s) {
    if (s == 'loading') {
      return 'Cargando...'; // Texto para el estado inicial
    }
    // Mapeo de status a etiquetas legibles
    final labels = {
      'fine': 'Todo bien', 'sos': '¡Necesito ayuda!', 'meeting': 'En reunión',
      'ready': 'Listo',
      'leave': 'De salida', 'happy': 'Feliz', 'sad': 'Triste',
      'busy': 'Ocupado',
      'sleepy': 'Con sueño', 'excited': 'Emocionado', 'thinking': 'Pensando',
      'worried': 'Preocupado',
      'available': 'Disponible', 'away': 'Ausente', 'focus': 'Concentrado',
      'tired': 'Cansado',
      'stressed': 'Estresado', 'traveling': 'Viajando',
      'studying': 'Estudiando', 'eating': 'Comiendo',
      'unknown': 'Desconocido', // Añadir un label para el estado 'unknown'
    };
    return labels[s] ??
        s.capitalize(); // Fallback: capitalizar el status si no está en el mapa
  }

  // --- Método Helper _getTimeAgo ---
  String _getTimeAgo(DateTime dt) {
    final difference = DateTime.now().difference(dt);
    if (difference.inSeconds < 60) return 'Ahora'; // Más preciso
    if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Hace ${difference.inHours} h';
    return 'Hace ${difference.inDays} d';
  }
} // Fin de _MemberListItem

// Helper para capitalizar (si no lo tienes ya en otro sitio)
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}


////////////////////////////////////////////////

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../../services/firebase_circle_service.dart';
// import '../../../auth/presentation/provider/auth_provider.dart';
// import '../../../auth/presentation/provider/auth_state.dart';
// import '../../../../core/widgets/emoji_modal.dart';
// import '../../../../core/services/gps_service.dart';
// import '../../../../core/services/status_service.dart';
// import '../../../settings/presentation/pages/settings_page.dart';
// import '../../domain_old/entities/user_status.dart';

// // ===========================================================================
// // SECCIÓN DE DISEÑO: Colores y Estilos basados en la pantalla de referencia
// // ===========================================================================

// /// Paleta de colores extraída del diseño de la pantalla de Login.
// class _AppColors {
//   static const Color background = Color(0xFF000000); // Negro puro
//   static const Color accent = Color(0xFF1EE9A4); // Verde menta/turquesa
//   static const Color textPrimary = Color(0xFFFFFFFF); // Blanco
//   static const Color textSecondary = Color(0xFF9E9E9E); // Gris para subtítulos y labels
//   static const Color cardBackground = Color(0xFF1C1C1E); // Gris oscuro para menús y diálogos
//   static const Color cardBorder = Color(0xFF3A3A3C); // Borde sutil para tarjetas y divider
//   static const Color sosRed = Color(0xFFD32F2F); // Rojo para alertas SOS
// }

// /// Estilos de texto consistentes con el diseño.
// class _AppTextStyles {
//   static const TextStyle screenTitle = TextStyle(
//     fontSize: 20,
//     fontWeight: FontWeight.bold,
//     color: _AppColors.textPrimary,
//     letterSpacing: 1.2,
//   );

//   static const TextStyle userNickname = TextStyle(
//     fontSize: 16,
//     color: _AppColors.textSecondary,
//     fontWeight: FontWeight.w400,
//   );

//   static const TextStyle cardTitle = TextStyle(
//     fontSize: 22,
//     fontWeight: FontWeight.bold,
//     color: _AppColors.textPrimary,
//   );

//   static const TextStyle cardSubtitle = TextStyle(
//     color: _AppColors.textSecondary,
//     fontSize: 14,
//   );

//   static const TextStyle invitationCode = TextStyle(
//     fontFamily: 'monospace',
//     fontWeight: FontWeight.bold,
//     fontSize: 20,
//     color: _AppColors.textPrimary,
//     letterSpacing: 1.5,
//   );

//   static const TextStyle memberNickname = TextStyle(
//     fontSize: 18,
//     fontWeight: FontWeight.bold,
//     color: _AppColors.textPrimary,
//   );
  
//   static const TextStyle memberStatus = TextStyle(
//     fontSize: 14,
//     color: _AppColors.textSecondary,
//     fontWeight: FontWeight.normal,
//   );
  
//   static const TextStyle sosStatus = TextStyle(
//     fontSize: 14,
//     color: _AppColors.sosRed,
//     fontWeight: FontWeight.bold,
//   );
// }


// class InCircleView extends ConsumerStatefulWidget {
//   final Circle circle;

//   const InCircleView({super.key, required this.circle});

//   @override
//   ConsumerState<InCircleView> createState() => _InCircleViewState();
// }

// class _InCircleViewState extends ConsumerState<InCircleView> {
//   // === INICIO DE LA LÓGICA ORIGINAL (SIN CAMBIOS) ===
//   final Map<String, Map<String, dynamic>> _memberDataCache = {};
//   bool _isUpdatingStatus = false; // Para controlar el loading del botón "Todo Bien"

//   // --- INICIO DE LA REFACTORIZACIÓN ---
//   // Se añaden variables de estado para cachear los nicknames y controlar la carga
//   final Map<String, String> _memberNicknamesCache = {};
//   bool _isLoadingNicknames = true;
//   // --- FIN DE LA REFACTORIZACIÓN ---

//   @override
//   void initState() {
//     super.initState();
//     _loadInitialData();
//     _listenToStatusChanges();
//     // --- INICIO DE LA REFACTORIZACIÓN ---
//     _loadAllNicknames(); // Cargar los nicknames solo una vez al iniciar
//     // --- FIN DE LA REFACTORIZACIÓN ---
//   }

//   Future<void> _loadInitialData() async {
//     final snapshot = await FirebaseFirestore.instance
//         .collection('circles')
//         .doc(widget.circle.id)
//         .get();

//     if (snapshot.exists && snapshot.data() != null) {
//       final data = snapshot.data()!;
//       final memberStatus = data['memberStatus'] as Map<String, dynamic>?;

//       if (memberStatus != null && mounted) {
//         setState(() {
//           memberStatus.forEach((memberId, statusData) {
//             _memberDataCache[memberId] = _parseMemberData(statusData);
//           });
//         });
//       }
//     }
//   }

//   void _listenToStatusChanges() {
//     FirebaseFirestore.instance
//         .collection('circles')
//         .doc(widget.circle.id)
//         .snapshots()
//         .listen((snapshot) {
//       if (!mounted || !snapshot.exists || snapshot.data() == null) return;

//       final data = snapshot.data()!;
//       final memberStatus = data['memberStatus'] as Map<String, dynamic>?;

//       if (memberStatus != null) {
//         bool hasChanges = false;
//         final Map<String, Map<String, dynamic>> updates = {};

//         memberStatus.forEach((memberId, statusData) {
//           final newData = _parseMemberData(statusData);
//           final oldData = _memberDataCache[memberId];

//           if (_hasChanged(oldData, newData)) {
//             updates[memberId] = newData;
//             hasChanges = true;
//           }
//         });

//         if (hasChanges) {
//           setState(() {
//             updates.forEach((memberId, newData) {
//               _memberDataCache[memberId] = newData;
//             });
//           });
//         }
//       }
//     });
//   }

//   // --- INICIO DE LA REFACTORIZACIÓN ---
//   /// Carga los nicknames una sola vez y los guarda en el caché local.
//   Future<void> _loadAllNicknames() async {
//     // No es necesario un setState para poner _isLoadingNicknames = true, ya es el valor por defecto.
//     final nicknames = await _getAllMemberNicknames(widget.circle.members);
    
//     if (mounted) {
//       setState(() {
//         _memberNicknamesCache.addAll(nicknames);
//         _isLoadingNicknames = false; // Termina la carga
//       });
//     }
//   }
//   // --- FIN DE LA REFACTORIZACIÓN ---

//   Map<String, dynamic> _parseMemberData(dynamic statusData) {
//     if (statusData is! Map<String, dynamic>) {
//       return {'emoji': '😊', 'status': 'fine', 'hasGPS': false};
//     }

//     final statusType = statusData['statusType'] as String?;
//     String emoji = '😊';
    
//     if (statusType != null) {
//       try {
//         final statusEnum = StatusType.values.firstWhere(
//           (s) => s.name == statusType,
//           orElse: () => StatusType.fine,
//         );
//         emoji = statusEnum.emoji;
//       } catch (e) {
//         emoji = '😊';
//       }
//     }

//     final coordinates = statusData['coordinates'] as Map<String, dynamic>?;
//     final timestamp = statusData['timestamp'];
//     DateTime? lastUpdate;
//     if (timestamp is Timestamp) {
//       lastUpdate = timestamp.toDate();
//     }

//     return {
//       'emoji': emoji,
//       'status': statusType ?? 'fine',
//       'coordinates': coordinates,
//       'hasGPS': coordinates != null && statusType == 'sos',
//       'lastUpdate': lastUpdate,
//     };
//   }

//   bool _hasChanged(Map<String, dynamic>? oldData, Map<String, dynamic> newData) {
//     if (oldData == null) return true;
//     return oldData['status'] != newData['status'] ||
//            oldData['lastUpdate']?.toString() != newData['lastUpdate']?.toString() ||
//            oldData['coordinates']?.toString() != newData['coordinates']?.toString();
//   }
//   // === FIN DE LA LÓGICA ORIGINAL (SIN CAMBIOS) ===

//   @override
//   Widget build(BuildContext context) {
//     final circle = widget.circle;
//     // CAMBIO: Se envuelve en un Scaffold para poder añadir el footer de demostración.
//     return Scaffold(
//       backgroundColor: _AppColors.background,
//       body: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
//             color: _AppColors.background,
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text('Zync', style: _AppTextStyles.screenTitle),
//                       Text(
//                         _getCurrentUserNickname(ref),
//                         style: _AppTextStyles.userNickname,
//                       ),
//                     ],
//                   ),
//                 ),
//                 PopupMenuButton<String>(
//                   icon: const Icon(Icons.more_vert, color: _AppColors.textPrimary),
//                   color: _AppColors.cardBackground,
//                   onSelected: (value) {
//                     switch (value) {
//                       case 'leave_circle':
//                         _showLeaveCircleDialog(context);
//                         break;
//                       case 'logout':
//                         _showLogoutDialog(context, ref);
//                         break;
//                       case 'settings':
//                         Navigator.of(context).push(
//                           MaterialPageRoute(
//                             builder: (context) => const SettingsPage(),
//                           ),
//                         );
//                         break;
//                     }
//                   },
//                   itemBuilder: (context) => [
//                     _buildPopupMenuItem(
//                       value: 'logout', icon: Icons.logout, text: 'Cerrar Sesión',
//                       color: _AppColors.textSecondary,
//                     ),
//                     _buildPopupMenuItem(
//                       value: 'settings', icon: Icons.settings, text: 'Configuración',
//                       color: _AppColors.accent,
//                     ),
//                      _buildPopupMenuItem(
//                       value: 'leave_circle', icon: Icons.exit_to_app, text: 'Salir del Círculo',
//                       color: _AppColors.sosRed,
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
          
//           Expanded(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0), // Padding inferior reducido
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.all(4.0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           children: [
//                             const Icon(Icons.hub, size: 28, color: _AppColors.accent),
//                             const SizedBox(width: 12),
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(circle.name, style: _AppTextStyles.cardTitle),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     '${circle.members.length} miembros',
//                                     style: _AppTextStyles.cardSubtitle,
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 20),
                        
//                         const Text('Código de Invitación', style: _AppTextStyles.cardSubtitle),
//                         const SizedBox(height: 8),
//                         Row(
//                           children: [
//                             Expanded(
//                               child: Text(circle.invitationCode, style: _AppTextStyles.invitationCode),
//                             ),
//                             IconButton(
//                               onPressed: () => _copyToClipboard(context, circle.invitationCode),
//                               icon: const Icon(Icons.copy, size: 24, color: _AppColors.accent),
//                               tooltip: 'Copiar código',
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
                  
//                   const Padding(
//                     padding: EdgeInsets.symmetric(vertical: 24.0),
//                     child: Divider(color: _AppColors.cardBorder, thickness: 1),
//                   ),

//                   const Row(
//                     children: [
//                       Icon(Icons.people_outline, size: 24, color: _AppColors.accent),
//                       SizedBox(width: 8),
//                       Text('Miembros', style: _AppTextStyles.screenTitle),
//                     ],
//                   ),
//                   const SizedBox(height: 16),
                  
//                   // --- INICIO DE LA REFACTORIZACIÓN ---
//                   // Se reemplaza el FutureBuilder por un condicional que usa el estado de carga local.
//                   _isLoadingNicknames
//                     ? const Center(child: CircularProgressIndicator(color: _AppColors.accent,))
//                     : Column(
//                         // Esta es la lógica que antes estaba dentro del FutureBuilder.builder
//                         children: circle.members.asMap().entries.map((entry) {
//                           final index = entry.key;
//                           final memberId = entry.value;

//                           // Se usa el caché de nicknames en lugar de 'nicknameSnapshot.data'
//                           final nickname = _memberNicknamesCache[memberId] ?? 
//                               (memberId.length > 8 ? memberId.substring(0, 8) : memberId);
                              
//                           final currentUser = FirebaseAuth.instance.currentUser;
//                           final isCurrentUser = currentUser?.uid == memberId;
                          
//                           final memberData = _memberDataCache[memberId] ?? {
//                             'emoji': '😊', 'status': 'fine', 'hasGPS': false,
//                             'coordinates': null, 'lastUpdate': null,
//                           };
//                           final status = memberData['status'] ?? 'fine';

//                           return Padding(
//                             padding: const EdgeInsets.only(bottom: 8.0),
//                             child: _MemberListItem(
//                               key: ValueKey('${memberId}_$status'), // La key es vital para la actualización eficiente
//                               memberId: memberId, nickname: nickname, isCurrentUser: isCurrentUser,
//                               isFirst: index == 0, memberData: memberData,
//                               onTap: isCurrentUser 
//                                   ? () => showEmojiStatusBottomSheet(context)
//                                   : null,
//                               onOpenMaps: _openGoogleMaps,
//                             ),
//                           );
//                         }).toList(),
//                       ),
//                   // --- FIN DE LA REFACTORIZACIÓN ---
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//       // CAMBIO: Footer de demostración añadido
//       bottomNavigationBar: _buildFooterButton(context),
//     );
//   }

//   // === INICIO DE WIDGETS AUXILIARES Y LÓGICA ORIGINAL (SIN CAMBIOS) ===
  
//   /// Actualización rápida del estado a "fine" (✅) - Point 17
//   Future<void> _quickStatusUpdate() async {
//     if (_isUpdatingStatus) return;
    
//     setState(() {
//       _isUpdatingStatus = true;
//     });
    
//     try {
//       print('[InCircleView] ✅ Enviando estado rápido: fine (Todo Bien)');
      
//       final result = await StatusService.updateUserStatus(StatusType.fine);
      
//       // El cambio se refleja inmediatamente en el emoji del usuario
//       // No necesitamos SnackBar porque es visualmente directo
//       if (!result.isSuccess && mounted) {
//         // Solo mostrar error si algo salió mal
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error: ${result.errorMessage}'),
//             backgroundColor: Colors.red,
//             duration: const Duration(seconds: 2),
//           ),
//         );
//       }
//     } catch (e) {
//       print('[InCircleView] Error en quickStatusUpdate: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Error actualizando estado'),
//             backgroundColor: Colors.red,
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isUpdatingStatus = false;
//         });
//       }
//     }
//   }

//   /// CAMBIO: Widget para el botón del footer, estilizado como se desea.
//   Widget _buildFooterButton(BuildContext context) {
//     return SafeArea(
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: ElevatedButton(
//           // Actualiza el estado del usuario a "fine" (Todo Bien)
//           onPressed: _isUpdatingStatus ? null : () => _quickStatusUpdate(),
//           style: ElevatedButton.styleFrom(
//             backgroundColor: _AppColors.accent,
//             foregroundColor: _AppColors.background,
//             padding: const EdgeInsets.symmetric(vertical: 16),
//             textStyle: const TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//             // La clave para la forma del botón:
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12.0), // Bordes más cuadrados
//             ),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               if (_isUpdatingStatus)
//                 const SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
//                   ),
//                 )
//               else
//                 const Icon(Icons.check_circle),
//               const SizedBox(width: 8),
//               Text(_isUpdatingStatus ? 'Actualizando...' : 'Todo bien'),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   PopupMenuItem<String> _buildPopupMenuItem({
//     required String value, required IconData icon, required String text, required Color color,
//   }) {
//     return PopupMenuItem(
//       value: value,
//       child: Row(
//         children: [
//           Icon(icon, color: color),
//           const SizedBox(width: 12),
//           Text(text, style: TextStyle(color: _AppColors.textPrimary)),
//         ],
//       ),
//     );
//   }

//   String _getCurrentUserNickname(WidgetRef ref) {
//     final authState = ref.watch(authProvider);
//     if (authState is Authenticated) {
//       return authState.user.nickname.isNotEmpty 
//           ? authState.user.nickname 
//           : authState.user.email.split('@')[0];
//     }
//     return 'Usuario';
//   }

//   Future<Map<String, String>> _getAllMemberNicknames(List<String> memberIds) async {
//     final Map<String, String> nicknames = {};
//     final futures = memberIds.map((uid) async {
//       try {
//         final doc = await FirebaseCircleService().getUserDoc(uid);
//         if (doc.exists && doc.data() != null) {
//           final data = doc.data()!;
//           final nickname = data['nickname'] as String? ?? '';
//           final email = data['email'] as String? ?? '';
//           final name = data['name'] as String? ?? '';
          
//           String finalNickname;
//           if (nickname.isNotEmpty) {
//             finalNickname = nickname;
//           } else if (name.isNotEmpty) finalNickname = name;
//           else if (email.isNotEmpty) finalNickname = email.split('@')[0];
//           else finalNickname = uid.length > 8 ? uid.substring(0, 8) : uid;
//           return MapEntry(uid, finalNickname);
//         } else {
//           final fallback = uid.length > 8 ? uid.substring(0, 8) : uid;
//           return MapEntry(uid, fallback);
//         }
//       } catch (e) {
//         final fallback = uid.length > 8 ? uid.substring(0, 8) : uid;
//         return MapEntry(uid, fallback);
//       }
//     });
//     final results = await Future.wait(futures);
//     for (final entry in results) {
//       nicknames[entry.key] = entry.value;
//     }
//     return nicknames;
//   }

//   void _copyToClipboard(BuildContext context, String text) {
//     Clipboard.setData(ClipboardData(text: text));
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text('¡Código copiado al portapapeles!'),
//         duration: Duration(seconds: 2),
//         backgroundColor: _AppColors.accent,
//       ),
//     );
//   }

//   void _openGoogleMaps(BuildContext context, Map<String, dynamic> coordinates, String memberName) async {
//     try {
//       final latitude = coordinates['latitude'] as double?;
//       final longitude = coordinates['longitude'] as double?;
//       if (latitude == null || longitude == null) {
//         _showError(context, 'Coordenadas GPS no válidas');
//         return;
//       }
//       final url = GPSService.generateSOSLocationUrl(
//         Coordinates(latitude: latitude, longitude: longitude), memberName,
//       );
//       final uri = Uri.parse(url);
//       if (await canLaunchUrl(uri)) {
//         await launchUrl(uri, mode: LaunchMode.externalApplication);
//         HapticFeedback.lightImpact();
//       } else {
//         // ignore: use_build_context_synchronously
//         _showError(context, 'No se pudo abrir la aplicación de mapas');
//       }
//     } catch (e) {
//       // ignore: use_build_context_synchronously
//       _showError(context, 'Error al abrir la ubicación: $e');
//     }
//   }

//   void _showError(BuildContext context, String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: _AppColors.sosRed,
//         duration: const Duration(seconds: 3),
//       ),
//     );
//   }

//   void _showLogoutDialog(BuildContext context, WidgetRef ref) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: _AppColors.cardBackground,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Text('Cerrar Sesión', style: TextStyle(color: _AppColors.textPrimary)),
//         content: const Text('¿Estás seguro?', style: TextStyle(color: _AppColors.textSecondary)),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('Cancelar', style: TextStyle(color: _AppColors.textSecondary)),
//           ),
//           TextButton(
//             onPressed: () async {
//               Navigator.of(context).pop();
//               await FirebaseAuth.instance.signOut();
//             },
//             child: const Text('Cerrar Sesión', style: TextStyle(color: _AppColors.sosRed)),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showLeaveCircleDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: _AppColors.cardBackground,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Text('Salir del Círculo', style: TextStyle(color: _AppColors.textPrimary)),
//         content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: _AppColors.textSecondary)),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('Cancelar', style: TextStyle(color: _AppColors.textSecondary)),
//           ),
//           TextButton(
//             onPressed: () async {
//               Navigator.of(context).pop();
//               final service = FirebaseCircleService();
//               await service.leaveCircle();
//             },
//             child: const Text('Salir', style: TextStyle(color: _AppColors.sosRed)),
//           ),
//         ],
//       ),
//     );
//   }
// }
// // === FIN DE LA LÓGICA ORIGINAL (SIN CAMBIOS) ===


// // ==============================================================================
// // MEMBER LIST ITEM - Widget individual con diseño ultra minimalista
// // ==============================================================================
// class _MemberListItem extends StatelessWidget {
//   final String memberId;
//   final String nickname;
//   final bool isCurrentUser;
//   final bool isFirst;
//   final Map<String, dynamic> memberData;
//   final VoidCallback? onTap;
//   final Function(BuildContext, Map<String, dynamic>, String) onOpenMaps;

//   const _MemberListItem({
//     super.key,
//     required this.memberId,
//     required this.nickname,
//     required this.isCurrentUser,
//     required this.isFirst,
//     required this.memberData,
//     this.onTap,
//     required this.onOpenMaps,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final emoji = memberData['emoji'] as String? ?? '😊';
//     final status = memberData['status'] as String? ?? 'fine';
//     final hasGPS = memberData['hasGPS'] as bool? ?? false;
//     final coordinates = memberData['coordinates'] as Map<String, dynamic>?;
//     final lastUpdate = memberData['lastUpdate'] as DateTime?;
//     final isSOS = status == 'sos';
    
//     return Material(
//       color: _AppColors.background,
//       child: InkWell(
//         onTap: () {
//           if (isCurrentUser && onTap != null) {
//             HapticFeedback.mediumImpact();
//             onTap!();
//           } else if (hasGPS && coordinates != null) {
//             HapticFeedback.lightImpact();
//             onOpenMaps(context, coordinates, nickname);
//           }
//         },
//         borderRadius: BorderRadius.circular(12),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   AnimatedSwitcher(
//                     duration: const Duration(milliseconds: 150),
//                     child: Text(emoji, key: ValueKey(status), style: const TextStyle(fontSize: 32)),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           children: [
//                             Flexible(child: Text(nickname, style: _AppTextStyles.memberNickname, overflow: TextOverflow.ellipsis)),
//                             if (isCurrentUser) ...[
//                               const SizedBox(width: 8),
//                               Container(
//                                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                                 decoration: BoxDecoration(
//                                   color: _AppColors.accent,
//                                   borderRadius: BorderRadius.circular(4),
//                                 ),
//                                 child: const Text(
//                                   'TÚ',
//                                   style: TextStyle(
//                                     fontSize: 10, fontWeight: FontWeight.bold, color: _AppColors.background,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ],
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           _getStatusLabel(status),
//                           style: isSOS ? _AppTextStyles.sosStatus : _AppTextStyles.memberStatus,
//                         ),
//                         if (isFirst)
//                           Text(
//                             'Creador',
//                             style: TextStyle(
//                               fontSize: 12, color: _AppColors.accent.withOpacity(0.8), fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                   if (lastUpdate != null)
//                     Text(
//                       _getTimeAgo(lastUpdate),
//                       style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                     ),
//                 ],
//               ),
//               if (hasGPS && coordinates != null) ...[
//                 const SizedBox(height: 12),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
//                   child: Row(
//                     children: [
//                       const Icon(Icons.location_on, size: 20, color: _AppColors.sosRed),
//                       const SizedBox(width: 8),
//                       const Expanded(
//                         child: Text(
//                           'Ubicación SOS compartida',
//                           style: TextStyle(fontSize: 13, color: _AppColors.textPrimary, fontWeight: FontWeight.w500),
//                         ),
//                       ),
//                       Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red[300]),
//                     ],
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // === MÉTODOS HELPER ORIGINALES (SIN CAMBIOS) ===
//   String _getStatusLabel(String s) {
//     final labels = {
//       'fine': 'Todo bien', 'sos': '¡Necesito ayuda!', 'meeting': 'En reunión', 'ready': 'Listo',
//       'leave': 'De salida', 'happy': 'Feliz', 'sad': 'Triste', 'busy': 'Ocupado',
//       'sleepy': 'Con sueño', 'excited': 'Emocionado', 'thinking': 'Pensando', 'worried': 'Preocupado',
//       'available': 'Disponible', 'away': 'Ausente', 'focus': 'Concentrado', 'tired': 'Cansado',
//       'stressed': 'Estresado', 'traveling': 'Viajando', 'studying': 'Estudiando', 'eating': 'Comiendo',
//     };
//     return labels[s] ?? s;
//   }

//   String _getTimeAgo(DateTime dt) {
//     final difference = DateTime.now().difference(dt);
//     if (difference.inMinutes < 1) return 'Ahora';
//     if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min';
//     if (difference.inHours < 24) return 'Hace ${difference.inHours} h';
//     return 'Hace ${difference.inDays} d';
//   }
// }




///////////////////////////////////////////////

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../../services/firebase_circle_service.dart';
// import '../../../auth/presentation/provider/auth_provider.dart';
// import '../../../auth/presentation/provider/auth_state.dart';
// import '../../../../core/widgets/emoji_modal.dart';
// import '../../../../core/services/gps_service.dart';
// import '../../../../core/services/status_service.dart';
// import '../../../settings/presentation/pages/settings_page.dart';
// import '../../domain_old/entities/user_status.dart';

// // ===========================================================================
// // SECCIÓN DE DISEÑO: Colores y Estilos basados en la pantalla de referencia
// // ===========================================================================

// /// Paleta de colores extraída del diseño de la pantalla de Login.
// class _AppColors {
//   static const Color background = Color(0xFF000000); // Negro puro
//   static const Color accent = Color(0xFF1EE9A4); // Verde menta/turquesa
//   static const Color textPrimary = Color(0xFFFFFFFF); // Blanco
//   static const Color textSecondary = Color(0xFF9E9E9E); // Gris para subtítulos y labels
//   static const Color cardBackground = Color(0xFF1C1C1E); // Gris oscuro para menús y diálogos
//   static const Color cardBorder = Color(0xFF3A3A3C); // Borde sutil para tarjetas y divider
//   static const Color sosRed = Color(0xFFD32F2F); // Rojo para alertas SOS
// }

// /// Estilos de texto consistentes con el diseño.
// class _AppTextStyles {
//   static const TextStyle screenTitle = TextStyle(
//     fontSize: 20,
//     fontWeight: FontWeight.bold,
//     color: _AppColors.textPrimary,
//     letterSpacing: 1.2,
//   );

//   static const TextStyle userNickname = TextStyle(
//     fontSize: 16,
//     color: _AppColors.textSecondary,
//     fontWeight: FontWeight.w400,
//   );

//   static const TextStyle cardTitle = TextStyle(
//     fontSize: 22,
//     fontWeight: FontWeight.bold,
//     color: _AppColors.textPrimary,
//   );

//   static const TextStyle cardSubtitle = TextStyle(
//     color: _AppColors.textSecondary,
//     fontSize: 14,
//   );

//   static const TextStyle invitationCode = TextStyle(
//     fontFamily: 'monospace',
//     fontWeight: FontWeight.bold,
//     fontSize: 20,
//     color: _AppColors.textPrimary,
//     letterSpacing: 1.5,
//   );

//   static const TextStyle memberNickname = TextStyle(
//     fontSize: 18,
//     fontWeight: FontWeight.bold,
//     color: _AppColors.textPrimary,
//   );
  
//   static const TextStyle memberStatus = TextStyle(
//     fontSize: 14,
//     color: _AppColors.textSecondary,
//     fontWeight: FontWeight.normal,
//   );
  
//   static const TextStyle sosStatus = TextStyle(
//     fontSize: 14,
//     color: _AppColors.sosRed,
//     fontWeight: FontWeight.bold,
//   );
// }


// class InCircleView extends ConsumerStatefulWidget {
//   final Circle circle;

//   const InCircleView({super.key, required this.circle});

//   @override
//   ConsumerState<InCircleView> createState() => _InCircleViewState();
// }

// class _InCircleViewState extends ConsumerState<InCircleView> {
//   // === INICIO DE LA LÓGICA ORIGINAL (SIN CAMBIOS) ===
//   final Map<String, Map<String, dynamic>> _memberDataCache = {};
//   bool _isUpdatingStatus = false; // Para controlar el loading del botón "Todo Bien"

//   @override
//   void initState() {
//     super.initState();
//     _loadInitialData();
//     _listenToStatusChanges();
//   }

//   Future<void> _loadInitialData() async {
//     final snapshot = await FirebaseFirestore.instance
//         .collection('circles')
//         .doc(widget.circle.id)
//         .get();

//     if (snapshot.exists && snapshot.data() != null) {
//       final data = snapshot.data()!;
//       final memberStatus = data['memberStatus'] as Map<String, dynamic>?;

//       if (memberStatus != null && mounted) {
//         setState(() {
//           memberStatus.forEach((memberId, statusData) {
//             _memberDataCache[memberId] = _parseMemberData(statusData);
//           });
//         });
//       }
//     }
//   }

//   void _listenToStatusChanges() {
//     FirebaseFirestore.instance
//         .collection('circles')
//         .doc(widget.circle.id)
//         .snapshots()
//         .listen((snapshot) {
//       if (!mounted || !snapshot.exists || snapshot.data() == null) return;

//       final data = snapshot.data()!;
//       final memberStatus = data['memberStatus'] as Map<String, dynamic>?;

//       if (memberStatus != null) {
//         bool hasChanges = false;
//         final Map<String, Map<String, dynamic>> updates = {};

//         memberStatus.forEach((memberId, statusData) {
//           final newData = _parseMemberData(statusData);
//           final oldData = _memberDataCache[memberId];

//           if (_hasChanged(oldData, newData)) {
//             updates[memberId] = newData;
//             hasChanges = true;
//           }
//         });

//         if (hasChanges) {
//           setState(() {
//             updates.forEach((memberId, newData) {
//               _memberDataCache[memberId] = newData;
//             });
//           });
//         }
//       }
//     });
//   }

//   Map<String, dynamic> _parseMemberData(dynamic statusData) {
//     if (statusData is! Map<String, dynamic>) {
//       return {'emoji': '😊', 'status': 'fine', 'hasGPS': false};
//     }

//     final statusType = statusData['statusType'] as String?;
//     String emoji = '😊';
    
//     if (statusType != null) {
//       try {
//         final statusEnum = StatusType.values.firstWhere(
//           (s) => s.name == statusType,
//           orElse: () => StatusType.fine,
//         );
//         emoji = statusEnum.emoji;
//       } catch (e) {
//         emoji = '😊';
//       }
//     }

//     final coordinates = statusData['coordinates'] as Map<String, dynamic>?;
//     final timestamp = statusData['timestamp'];
//     DateTime? lastUpdate;
//     if (timestamp is Timestamp) {
//       lastUpdate = timestamp.toDate();
//     }

//     return {
//       'emoji': emoji,
//       'status': statusType ?? 'fine',
//       'coordinates': coordinates,
//       'hasGPS': coordinates != null && statusType == 'sos',
//       'lastUpdate': lastUpdate,
//     };
//   }

//   bool _hasChanged(Map<String, dynamic>? oldData, Map<String, dynamic> newData) {
//     if (oldData == null) return true;
//     return oldData['status'] != newData['status'] ||
//            oldData['lastUpdate']?.toString() != newData['lastUpdate']?.toString() ||
//            oldData['coordinates']?.toString() != newData['coordinates']?.toString();
//   }
//   // === FIN DE LA LÓGICA ORIGINAL (SIN CAMBIOS) ===

//   @override
//   Widget build(BuildContext context) {
//     final circle = widget.circle;
//     // CAMBIO: Se envuelve en un Scaffold para poder añadir el footer de demostración.
//     return Scaffold(
//       backgroundColor: _AppColors.background,
//       body: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
//             color: _AppColors.background,
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text('Zync', style: _AppTextStyles.screenTitle),
//                       Text(
//                         _getCurrentUserNickname(ref),
//                         style: _AppTextStyles.userNickname,
//                       ),
//                     ],
//                   ),
//                 ),
//                 PopupMenuButton<String>(
//                   icon: const Icon(Icons.more_vert, color: _AppColors.textPrimary),
//                   color: _AppColors.cardBackground,
//                   onSelected: (value) {
//                     switch (value) {
//                       case 'leave_circle':
//                         _showLeaveCircleDialog(context);
//                         break;
//                       case 'logout':
//                         _showLogoutDialog(context, ref);
//                         break;
//                       case 'settings':
//                         Navigator.of(context).push(
//                           MaterialPageRoute(
//                             builder: (context) => const SettingsPage(),
//                           ),
//                         );
//                         break;
//                     }
//                   },
//                   itemBuilder: (context) => [
//                     _buildPopupMenuItem(
//                       value: 'logout', icon: Icons.logout, text: 'Cerrar Sesión',
//                       color: _AppColors.textSecondary,
//                     ),
//                     _buildPopupMenuItem(
//                       value: 'settings', icon: Icons.settings, text: 'Configuración',
//                       color: _AppColors.accent,
//                     ),
//                      _buildPopupMenuItem(
//                       value: 'leave_circle', icon: Icons.exit_to_app, text: 'Salir del Círculo',
//                       color: _AppColors.sosRed,
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
          
//           Expanded(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0), // Padding inferior reducido
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.all(4.0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           children: [
//                             const Icon(Icons.hub, size: 28, color: _AppColors.accent),
//                             const SizedBox(width: 12),
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(circle.name, style: _AppTextStyles.cardTitle),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     '${circle.members.length} miembros',
//                                     style: _AppTextStyles.cardSubtitle,
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 20),
                        
//                         const Text('Código de Invitación', style: _AppTextStyles.cardSubtitle),
//                         const SizedBox(height: 8),
//                         Row(
//                           children: [
//                             Expanded(
//                               child: Text(circle.invitationCode, style: _AppTextStyles.invitationCode),
//                             ),
//                             IconButton(
//                               onPressed: () => _copyToClipboard(context, circle.invitationCode),
//                               icon: const Icon(Icons.copy, size: 24, color: _AppColors.accent),
//                               tooltip: 'Copiar código',
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
                  
//                   const Padding(
//                     padding: EdgeInsets.symmetric(vertical: 24.0),
//                     child: Divider(color: _AppColors.cardBorder, thickness: 1),
//                   ),

//                   const Row(
//                     children: [
//                       Icon(Icons.people_outline, size: 24, color: _AppColors.accent),
//                       SizedBox(width: 8),
//                       Text('Miembros', style: _AppTextStyles.screenTitle),
//                     ],
//                   ),
//                   const SizedBox(height: 16),
                  
//                   FutureBuilder<Map<String, String>>(
//                     future: _getAllMemberNicknames(circle.members),
//                     builder: (context, nicknameSnapshot) {
//                       if (nicknameSnapshot.connectionState == ConnectionState.waiting) {
//                         return const Center(child: CircularProgressIndicator(color: _AppColors.accent,));
//                       }
                      
//                       final nicknames = nicknameSnapshot.data ?? {};
//                       final currentUser = FirebaseAuth.instance.currentUser;
                      
//                       return Column(
//                         children: circle.members.asMap().entries.map((entry) {
//                           final index = entry.key;
//                           final memberId = entry.value;
//                           final nickname = nicknames[memberId] ?? 
//                             (memberId.length > 8 ? memberId.substring(0, 8) : memberId);
//                           final isCurrentUser = currentUser?.uid == memberId;
//                           final memberData = _memberDataCache[memberId] ?? {
//                             'emoji': '😊', 'status': 'fine', 'hasGPS': false,
//                             'coordinates': null, 'lastUpdate': null,
//                           };
//                           final status = memberData['status'] ?? 'fine';

//                           return Padding(
//                             padding: const EdgeInsets.only(bottom: 8.0),
//                             child: _MemberListItem(
//                               key: ValueKey('${memberId}_$status'),
//                               memberId: memberId, nickname: nickname, isCurrentUser: isCurrentUser,
//                               isFirst: index == 0, memberData: memberData,
//                               onTap: isCurrentUser 
//                                   ? () => showEmojiStatusBottomSheet(context)
//                                   : null,
//                               onOpenMaps: _openGoogleMaps,
//                             ),
//                           );
//                         }).toList(),
//                       );
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//       // CAMBIO: Footer de demostración añadido
//       bottomNavigationBar: _buildFooterButton(context),
//     );
//   }

//   // === INICIO DE WIDGETS AUXILIARES Y LÓGICA ORIGINAL (SIN CAMBIOS) ===
  
//   /// Actualización rápida del estado a "fine" (✅) - Point 17
//   Future<void> _quickStatusUpdate() async {
//     if (_isUpdatingStatus) return;
    
//     setState(() {
//       _isUpdatingStatus = true;
//     });
    
//     try {
//       print('[InCircleView] ✅ Enviando estado rápido: fine (Todo Bien)');
      
//       final result = await StatusService.updateUserStatus(StatusType.fine);
      
//       // El cambio se refleja inmediatamente en el emoji del usuario
//       // No necesitamos SnackBar porque es visualmente directo
//       if (!result.isSuccess && mounted) {
//         // Solo mostrar error si algo salió mal
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error: ${result.errorMessage}'),
//             backgroundColor: Colors.red,
//             duration: const Duration(seconds: 2),
//           ),
//         );
//       }
//     } catch (e) {
//       print('[InCircleView] Error en quickStatusUpdate: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Error actualizando estado'),
//             backgroundColor: Colors.red,
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isUpdatingStatus = false;
//         });
//       }
//     }
//   }

//   /// CAMBIO: Widget para el botón del footer, estilizado como se desea.
//   Widget _buildFooterButton(BuildContext context) {
//     return SafeArea(
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: ElevatedButton(
//           // Actualiza el estado del usuario a "fine" (Todo Bien)
//           onPressed: _isUpdatingStatus ? null : () => _quickStatusUpdate(),
//           style: ElevatedButton.styleFrom(
//             backgroundColor: _AppColors.accent,
//             foregroundColor: _AppColors.background,
//             padding: const EdgeInsets.symmetric(vertical: 16),
//             textStyle: const TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//             // La clave para la forma del botón:
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12.0), // Bordes más cuadrados
//             ),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               if (_isUpdatingStatus)
//                 const SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
//                   ),
//                 )
//               else
//                 const Icon(Icons.check_circle),
//               const SizedBox(width: 8),
//               Text(_isUpdatingStatus ? 'Actualizando...' : 'Todo bien'),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   PopupMenuItem<String> _buildPopupMenuItem({
//     required String value, required IconData icon, required String text, required Color color,
//   }) {
//     return PopupMenuItem(
//       value: value,
//       child: Row(
//         children: [
//           Icon(icon, color: color),
//           const SizedBox(width: 12),
//           Text(text, style: TextStyle(color: _AppColors.textPrimary)),
//         ],
//       ),
//     );
//   }

//   String _getCurrentUserNickname(WidgetRef ref) {
//     final authState = ref.watch(authProvider);
//     if (authState is Authenticated) {
//       return authState.user.nickname.isNotEmpty 
//           ? authState.user.nickname 
//           : authState.user.email.split('@')[0];
//     }
//     return 'Usuario';
//   }

//   Future<Map<String, String>> _getAllMemberNicknames(List<String> memberIds) async {
//     final Map<String, String> nicknames = {};
//     final futures = memberIds.map((uid) async {
//       try {
//         final doc = await FirebaseCircleService().getUserDoc(uid);
//         if (doc.exists && doc.data() != null) {
//           final data = doc.data()!;
//           final nickname = data['nickname'] as String? ?? '';
//           final email = data['email'] as String? ?? '';
//           final name = data['name'] as String? ?? '';
          
//           String finalNickname;
//           if (nickname.isNotEmpty) {
//             finalNickname = nickname;
//           } else if (name.isNotEmpty) finalNickname = name;
//           else if (email.isNotEmpty) finalNickname = email.split('@')[0];
//           else finalNickname = uid.length > 8 ? uid.substring(0, 8) : uid;
//           return MapEntry(uid, finalNickname);
//         } else {
//           final fallback = uid.length > 8 ? uid.substring(0, 8) : uid;
//           return MapEntry(uid, fallback);
//         }
//       } catch (e) {
//         final fallback = uid.length > 8 ? uid.substring(0, 8) : uid;
//         return MapEntry(uid, fallback);
//       }
//     });
//     final results = await Future.wait(futures);
//     for (final entry in results) {
//       nicknames[entry.key] = entry.value;
//     }
//     return nicknames;
//   }

//   void _copyToClipboard(BuildContext context, String text) {
//     Clipboard.setData(ClipboardData(text: text));
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text('¡Código copiado al portapapeles!'),
//         duration: Duration(seconds: 2),
//         backgroundColor: _AppColors.accent,
//       ),
//     );
//   }

//   void _openGoogleMaps(BuildContext context, Map<String, dynamic> coordinates, String memberName) async {
//     try {
//       final latitude = coordinates['latitude'] as double?;
//       final longitude = coordinates['longitude'] as double?;
//       if (latitude == null || longitude == null) {
//         _showError(context, 'Coordenadas GPS no válidas');
//         return;
//       }
//       final url = GPSService.generateSOSLocationUrl(
//         Coordinates(latitude: latitude, longitude: longitude), memberName,
//       );
//       final uri = Uri.parse(url);
//       if (await canLaunchUrl(uri)) {
//         await launchUrl(uri, mode: LaunchMode.externalApplication);
//         HapticFeedback.lightImpact();
//       } else {
//         // ignore: use_build_context_synchronously
//         _showError(context, 'No se pudo abrir la aplicación de mapas');
//       }
//     } catch (e) {
//       // ignore: use_build_context_synchronously
//       _showError(context, 'Error al abrir la ubicación: $e');
//     }
//   }

//   void _showError(BuildContext context, String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: _AppColors.sosRed,
//         duration: const Duration(seconds: 3),
//       ),
//     );
//   }

//   void _showLogoutDialog(BuildContext context, WidgetRef ref) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: _AppColors.cardBackground,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Text('Cerrar Sesión', style: TextStyle(color: _AppColors.textPrimary)),
//         content: const Text('¿Estás seguro?', style: TextStyle(color: _AppColors.textSecondary)),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('Cancelar', style: TextStyle(color: _AppColors.textSecondary)),
//           ),
//           TextButton(
//             onPressed: () async {
//               Navigator.of(context).pop();
//               await FirebaseAuth.instance.signOut();
//             },
//             child: const Text('Cerrar Sesión', style: TextStyle(color: _AppColors.sosRed)),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showLeaveCircleDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: _AppColors.cardBackground,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Text('Salir del Círculo', style: TextStyle(color: _AppColors.textPrimary)),
//         content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: _AppColors.textSecondary)),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('Cancelar', style: TextStyle(color: _AppColors.textSecondary)),
//           ),
//           TextButton(
//             onPressed: () async {
//               Navigator.of(context).pop();
//               final service = FirebaseCircleService();
//               await service.leaveCircle();
//             },
//             child: const Text('Salir', style: TextStyle(color: _AppColors.sosRed)),
//           ),
//         ],
//       ),
//     );
//   }
// }
// // === FIN DE LA LÓGICA ORIGINAL (SIN CAMBIOS) ===


// // ==============================================================================
// // MEMBER LIST ITEM - Widget individual con diseño ultra minimalista
// // ==============================================================================
// class _MemberListItem extends StatelessWidget {
//   final String memberId;
//   final String nickname;
//   final bool isCurrentUser;
//   final bool isFirst;
//   final Map<String, dynamic> memberData;
//   final VoidCallback? onTap;
//   final Function(BuildContext, Map<String, dynamic>, String) onOpenMaps;

//   const _MemberListItem({
//     super.key,
//     required this.memberId,
//     required this.nickname,
//     required this.isCurrentUser,
//     required this.isFirst,
//     required this.memberData,
//     this.onTap,
//     required this.onOpenMaps,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final emoji = memberData['emoji'] as String? ?? '😊';
//     final status = memberData['status'] as String? ?? 'fine';
//     final hasGPS = memberData['hasGPS'] as bool? ?? false;
//     final coordinates = memberData['coordinates'] as Map<String, dynamic>?;
//     final lastUpdate = memberData['lastUpdate'] as DateTime?;
//     final isSOS = status == 'sos';
    
//     return Material(
//       color: _AppColors.background,
//       child: InkWell(
//         onTap: () {
//           if (isCurrentUser && onTap != null) {
//             HapticFeedback.mediumImpact();
//             onTap!();
//           } else if (hasGPS && coordinates != null) {
//             HapticFeedback.lightImpact();
//             onOpenMaps(context, coordinates, nickname);
//           }
//         },
//         borderRadius: BorderRadius.circular(12),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   AnimatedSwitcher(
//                     duration: const Duration(milliseconds: 150),
//                     child: Text(emoji, key: ValueKey(status), style: const TextStyle(fontSize: 32)),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           children: [
//                             Flexible(child: Text(nickname, style: _AppTextStyles.memberNickname, overflow: TextOverflow.ellipsis)),
//                             if (isCurrentUser) ...[
//                               const SizedBox(width: 8),
//                               Container(
//                                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                                 decoration: BoxDecoration(
//                                   color: _AppColors.accent,
//                                   borderRadius: BorderRadius.circular(4),
//                                 ),
//                                 child: const Text(
//                                   'TÚ',
//                                   style: TextStyle(
//                                     fontSize: 10, fontWeight: FontWeight.bold, color: _AppColors.background,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ],
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           _getStatusLabel(status),
//                           style: isSOS ? _AppTextStyles.sosStatus : _AppTextStyles.memberStatus,
//                         ),
//                         if (isFirst)
//                            Text(
//                              'Creador',
//                              style: TextStyle(
//                                fontSize: 12, color: _AppColors.accent.withOpacity(0.8), fontWeight: FontWeight.w500,
//                              ),
//                            ),
//                       ],
//                     ),
//                   ),
//                   if (lastUpdate != null)
//                     Text(
//                       _getTimeAgo(lastUpdate),
//                       style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                     ),
//                 ],
//               ),
//               if (hasGPS && coordinates != null) ...[
//                 const SizedBox(height: 12),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
//                   child: Row(
//                     children: [
//                       const Icon(Icons.location_on, size: 20, color: _AppColors.sosRed),
//                       const SizedBox(width: 8),
//                       const Expanded(
//                         child: Text(
//                           'Ubicación SOS compartida',
//                           style: TextStyle(fontSize: 13, color: _AppColors.textPrimary, fontWeight: FontWeight.w500),
//                         ),
//                       ),
//                       Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red[300]),
//                     ],
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // === MÉTODOS HELPER ORIGINALES (SIN CAMBIOS) ===
//   String _getStatusLabel(String s) {
//     final labels = {
//       'fine': 'Todo bien', 'sos': '¡Necesito ayuda!', 'meeting': 'En reunión', 'ready': 'Listo',
//       'leave': 'De salida', 'happy': 'Feliz', 'sad': 'Triste', 'busy': 'Ocupado',
//       'sleepy': 'Con sueño', 'excited': 'Emocionado', 'thinking': 'Pensando', 'worried': 'Preocupado',
//       'available': 'Disponible', 'away': 'Ausente', 'focus': 'Concentrado', 'tired': 'Cansado',
//       'stressed': 'Estresado', 'traveling': 'Viajando', 'studying': 'Estudiando', 'eating': 'Comiendo',
//     };
//     return labels[s] ?? s;
//   }

//   String _getTimeAgo(DateTime dt) {
//     final difference = DateTime.now().difference(dt);
//     if (difference.inMinutes < 1) return 'Ahora';
//     if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min';
//     if (difference.inHours < 24) return 'Hace ${difference.inHours} h';
//     return 'Hace ${difference.inDays} d';
//   }
// }

// ////////////////////////////////////////////

