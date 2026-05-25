import 'dart:async'; // Necesario para StreamSubscription
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nunakin_app/platform/persistence/native_keys.dart';
import 'package:url_launcher/url_launcher.dart';
// Asegúrate que las rutas de importación sean correctas para tu proyecto
import '../../../../services/circle_service.dart';
import '../../../../contexts/identity/presentation/provider/auth_provider.dart';
import '../../../../contexts/identity/presentation/provider/auth_state.dart';
// Asumo que emoji_modal.dart exporta la función showEmojiStatusBottomSheet
import '../../../../core/widgets/emoji_modal.dart';
import '../../../../core/services/gps_service.dart';
import '../../../../core/services/status_service.dart';
import '../../../../core/services/emoji_service.dart';
import '../../../../core/services/silent_functionality_coordinator.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../../core/models/user_status.dart';
import '../../../geofencing/services/geofencing_service.dart'; // Servicio de geofencing
import 'package:nunakin_app/app/di/injection_container.dart';
import 'package:nunakin_app/shared/events/domain_event_bus.dart';
// CACHE-FIRST: Importar caches
import '../../../../core/cache/in_memory_cache.dart';
import 'member_status_grid.dart';
import '../../../../core/cache/persistent_cache.dart';
import '../../../../core/services/native_state_bridge.dart';
import '../../../../core/services/emoji_cache_service.dart';
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
  static const Color textSecondary = Color(0xFF9E9E9E); // Gris para subtítulos y labels
  // static const Color cardBackground =
  //     Color(0xFF1C1C1E); // Gris oscuro para menús y diálogos (comentado: no usado actualmente)
  static const Color cardBorder = Color(0xFF3A3A3C); // Borde sutil para tarjetas y divider
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
  // ════════════════════════════════════════════════════════════
  // [FIX] Mostrar miembros inmediatamente con placeholder '...'
  // Fecha: 2026-05-14
  // PROBLEMA: true bloqueaba la lista completa con un spinner hasta que
  //   _refreshDataInBackground() completaba los getUserDoc() de red (~6s).
  // SOLUCIÓN: false desde el inicio. La lista renderiza con '...' y se
  //   actualiza cuando llegan los nicknames reales (setState en background).
  // ════════════════════════════════════════════════════════════
  bool _isLoadingNicknames = false;
  List<StatusType>? _predefinedEmojis;

  // ════════════════════════════════════════════════════════════
  // [FIX] Último estado conocido desde SharedPreferences (AUTH-20260513-001)
  // Fecha: 2026-05-13
  // PROBLEMA: El modal mostraba caption "loading" en cold start antes de que
  //   llegara el primer snapshot de Firestore.
  // SOLUCIÓN: Leer manual_status_id → current_status_id → 'fine' al inicio
  //   y usar ese valor como fallback en lugar del literal 'loading'.
  // ════════════════════════════════════════════════════════════
  String? _lastKnownStatusId;

  // --- INICIO DE LA MODIFICACIÓN ---
  // StreamSubscription para poder cancelarlo en dispose()
  StreamSubscription<DocumentSnapshot>? _circleListenerSubscription;
  StreamSubscription<QuerySnapshot>? _customEmojisListener;

  // Servicio de geofencing
  final GeofencingService _geofencingService = GeofencingService(bus: sl<DomainEventBus>());
  // --- FIN DE LA MODIFICACIÓN ---

  // Aprobación de ingreso
  final _circleService = CircleService();
  List<JoinRequest> _pendingRequests = [];
  StreamSubscription<List<JoinRequest>>? _joinRequestsSubscription;

  @override
  void initState() {
    super.initState();
    _loadPredefinedEmojis();
    _loadLastKnownStatusId(); // Leer último estado conocido desde SharedPreferences
    _listenToCustomEmojis(); // Escuchar cambios en emojis personalizados

    // ==================== CACHE-FIRST PATTERN ====================
    // PASO 1: Cargar cache PRIMERO (sin await, sincrónico desde memoria)
    // 🚀 LAZY: Solo cargar si cache está inicializado, si no, esperar postFrameCallback
    if (PersistentCache.isInitialized) {
      _loadFromCache();
    } else {
      // Cache NO inicializado aún, esperar postFrameCallback
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

    // PASO 4: Iniciar monitoreo de geofencing
    _startGeofencingMonitoring();

    // Sincronizar circleId real con Kotlin — garantiza que StatusUpdateWorker
    // tenga un circleId válido cuando la app esté cerrada (Silent Mode + BN).
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      NativeStateBridge.setUserId(
        userId: currentUser.uid,
        email: currentUser.email ?? '',
        circleId: widget.circle.id,
      ).catchError((e) {
        // Esperado en iOS o si el canal no está disponible
      });
    }

    // InCircleView solo renderiza cuando el usuario tiene círculo — siempre correcto.
    // Evita la race condition donde _userHasCircle queda false en cold start y
    // activateSilentMode dispara un getUserCircle() frío (~5-8s) al primer tap.
    SilentFunctionalityCoordinator.syncCircleState(hasCircle: true);

    // Sincronizar zonas configuradas a SharedPreferences para que EmojiDialogActivity
    // (modal BN) lea datos frescos. Se llama aquí porque en este punto el usuario
    // ya está autenticado y widget.circle.id está disponible — evita el cold-start
    // race donde main.dart llamaba sync antes de que Auth completara y escribía [].
    EmojiCacheService.syncEmojisToNativeCache();

    // PASO 5: Escuchar solicitudes de ingreso (solo si el usuario actual es el creador)
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null && currentUid == widget.circle.creatorId) {
      _joinRequestsSubscription = _circleService
          .getPendingJoinRequestsStream(widget.circle.id)
          .listen((requests) {
        if (mounted) {
          setState(() {
            _pendingRequests = requests;
          });
        }
      });
    }
    // =============================================================
  }

  @override
  void didUpdateWidget(InCircleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newMembers = widget.circle.members
        .where((id) => !_memberNicknamesCache.containsKey(id) || _memberNicknamesCache[id] == '...')
        .toList();
    if (newMembers.isNotEmpty) {
      _getAllMemberNicknames(newMembers).then((nicknames) {
        if (!mounted) return;
        setState(() => _memberNicknamesCache.addAll(nicknames));
        InMemoryCache.set('nicknames_${widget.circle.id}', _memberNicknamesCache);
        PersistentCache.saveNicknames(_memberNicknamesCache);
      });
    }
  }

  // --- INICIO DE LA MODIFICACIÓN ---
  @override
  void dispose() {
    // CACHE-FIRST: Guardar estado antes de dispose
    _saveToCache();

    // Cancelar la suscripción al listener de Firestore para evitar memory leaks
    _circleListenerSubscription?.cancel();
    _customEmojisListener?.cancel();
    _joinRequestsSubscription?.cancel();

    // Detener monitoreo de geofencing
    _stopGeofencingMonitoring();

    super.dispose();
  }
  // --- FIN DE LA MODIFICACIÓN ---

  /// Listener para detectar cuando se agregan nuevos emojis personalizados
  void _listenToCustomEmojis() {
    _customEmojisListener?.cancel();
    _customEmojisListener = FirebaseFirestore.instance
        .collection('circles')
        .doc(widget.circle.id)
        .collection('customEmojis')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      // Recargar la lista completa de emojis cuando hay cambios
      _loadPredefinedEmojis();
    }, onError: (error) {
      debugPrint('[InCircleView] Error en listener de emojis: $error');
    });
  }

  /// Iniciar monitoreo de geofencing para el círculo actual
  void _startGeofencingMonitoring() {
    _geofencingService.startMonitoring(widget.circle.id).catchError((error) {
      debugPrint('[InCircleView] Error iniciando geofencing: $error');
    });
  }

  /// Detener monitoreo de geofencing
  void _stopGeofencingMonitoring() {
    _geofencingService.stopMonitoring().catchError((error) {
      debugPrint('[InCircleView] Error deteniendo geofencing: $error');
    });
  }

  /// Lee el último estado conocido desde SharedPreferences para evitar mostrar
  /// 'loading' como caption del modal en cold start (AUTH-20260513-001).
  /// Orden de lectura: manual_status_id → current_status_id → 'fine'.
  Future<void> _loadLastKnownStatusId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final manualId = prefs.getString(NativeSharedKeys.manualStatusId);
      final currentId = prefs.getString(NativeSharedKeys.currentStatusId);
      final resolved = manualId ?? currentId ?? 'fine';
      if (mounted) {
        setState(() {
          _lastKnownStatusId = resolved;
        });
      }
    } catch (e) {
      // Ignorar — el fallback 'fine' se aplica en los puntos de uso
    }
  }

  /// Carga TODOS los emojis (predefinidos + personalizados) desde Firebase
  Future<void> _loadPredefinedEmojis() async {
    try {
      // Cargar predefinidos + personalizados del círculo
      final emojis = await EmojiService.getAllEmojisForCircle(widget.circle.id);
      if (mounted) {
        setState(() {
          _predefinedEmojis = emojis;
        });
        // NO llamar a _refreshMemberDataWithNewEmojis() porque sobrescribe emojis de zonas
        // Los emojis se actualizan correctamente a través del listener de Firebase
      }
    } catch (e) {
      debugPrint('[InCircleView] Error cargando emojis: $e');
      // Usar fallback si falla
      if (mounted) {
        setState(() {
          _predefinedEmojis = StatusType.fallbackPredefined;
        });
      }
    }
  }

  // ========================================================================
  // CACHE-FIRST: Métodos de cache
  // ========================================================================

  /// PASO 1: Cargar desde cache (sincrónico, instantáneo)
  void _loadFromCache() {
    // Intentar InMemoryCache primero (0ms)
    final memoryNicknames = InMemoryCache.get<Map<String, String>>('nicknames_${widget.circle.id}');
    final memoryMemberData = InMemoryCache.get<Map<String, Map<String, dynamic>>>('member_data_${widget.circle.id}');

    if (memoryNicknames != null && memoryMemberData != null) {
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
      setState(() {
        _memberNicknamesCache.addAll(diskNicknames);
        _memberDataCache.addAll(diskMemberData);
        _isLoadingNicknames = false;
      });

      // Guardar en memoria para próxima vez
      InMemoryCache.set('nicknames_${widget.circle.id}', diskNicknames);
      InMemoryCache.set('member_data_${widget.circle.id}', diskMemberData);
    }
  }

  /// PASO 3: Refrescar datos en background (sin bloquear UI)
  void _refreshDataInBackground() {

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

    }).catchError((error) {
      debugPrint('[InCircleView] Error refrescando nicknames: $error');
    });
  }

  /// Guardar estado a cache (llamado desde dispose)
  void _saveToCache() {
    InMemoryCache.set('nicknames_${widget.circle.id}', _memberNicknamesCache);
    InMemoryCache.set('member_data_${widget.circle.id}', _memberDataCache);
    PersistentCache.saveNicknames(_memberNicknamesCache);
    PersistentCache.saveMemberData(_memberDataCache);
  }

  // --- loadInitialData() ELIMINADO ---

  void _listenToStatusChanges() {
    // Guardar la suscripción para poder cancelarla después
    _circleListenerSubscription?.cancel(); // Cancelar anterior si existe
    _circleListenerSubscription =
        FirebaseFirestore.instance.collection('circles').doc(widget.circle.id).snapshots().listen((snapshot) {
      if (!mounted) return; // Verificar mounted al inicio

      if (!snapshot.exists || snapshot.data() == null) {
        return;
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

          InMemoryCache.set('member_data_${widget.circle.id}', _memberDataCache);
          PersistentCache.saveMemberData(_memberDataCache);
        }
      }
    }, onError: (error) {
      debugPrint('[InCircleView] Error en listener de círculo: $error');
    });
  }

  Map<String, dynamic> _parseMemberData(dynamic statusData) {
    if (statusData is! Map<String, dynamic>) {
      // Valor por defecto si la data está mal formada
      return {
        'emoji': '❓',
        'status': 'unknown',
        'hasGPS': false,
        'coordinates': null,
        'lastUpdate': null,
        'autoUpdated': false,
        'zoneName': null,
        'displayText': null,
        'showManualBadge': false,
        'locationInfo': null,
      };
    }

    final rawStatusType = statusData['statusType'] as String?;
    final statusType = _migrateOldStatus(rawStatusType);
    final autoUpdated = statusData['autoUpdated'] as bool? ?? false;
    final customEmoji = statusData['customEmoji'] as String?;
    final zoneName = statusData['zoneName'] as String?;
    final manualOverride = statusData['manualOverride'] as bool?;
    final locationUnknown = statusData['locationUnknown'] as bool?;

    String emoji = '😊'; // Default emoji
    String? displayText;
    bool showManualBadge = false;
    String? locationInfo;

    // CASO 1: Si es actualización automática y tiene customEmoji (entrada a zona)
    // PRIORIDAD MÁXIMA: Este caso debe ejecutarse SIEMPRE que haya customEmoji
    if (autoUpdated && customEmoji != null) {
      emoji = customEmoji; // Usar emoji de la zona (🏠, 🏫, 🎓, 💼, 📍, 🚗)
      displayText = zoneName; // "En Jaus", "En Torre Real", "En camino"
      showManualBadge = false; // Automático, sin badge
      locationInfo = null;
    }
    // CASO 1.5: Override manual mientras SIGUE dentro de una zona
    // (customEmoji/zoneName presentes, pero autoUpdated=false)
    else if (!autoUpdated && customEmoji != null) {
      try {
        final emojis = _predefinedEmojis ?? StatusType.fallbackPredefined;
        final statusEnum = emojis.firstWhere(
          (s) => s.id == statusType,
          orElse: () {
            debugPrint("⚠️ [InCircleView] Status '$statusType' no encontrado");
            _loadPredefinedEmojis();
            return emojis.firstWhere(
              (s) => s.id == 'fine',
              orElse: () => StatusType.fallbackPredefined.first,
            );
          },
        );
        emoji = statusEnum.emoji;
        displayText = statusEnum.label;
      } catch (e) {
        debugPrint('[InCircleView] Error parsing status enum (manual-in-zone): $e');
        emoji = '😊';
        displayText = 'Todo bien';
      }

      showManualBadge = manualOverride == true;
      locationInfo = locationUnknown == true ? '❓ Ubicación desconocida' : null;
    }
    // CASO 2: Estado manual (sin customEmoji, solo statusType)
    else if (customEmoji == null) {
      try {
        final emojis = _predefinedEmojis ?? StatusType.fallbackPredefined;
        final statusEnum = emojis.firstWhere(
          (s) => s.id == statusType,
          orElse: () {
            debugPrint("⚠️ [InCircleView] Status '$statusType' no encontrado");
            _loadPredefinedEmojis();
            return emojis.firstWhere(
              (s) => s.id == 'fine',
              orElse: () => StatusType.fallbackPredefined.first,
            );
          },
        );
        emoji = statusEnum.emoji;
        displayText = statusEnum.label;
      } catch (e) {
        debugPrint('[InCircleView] Error parsing status enum: $e');
        emoji = '😊';
        displayText = 'Todo bien';
      }

      // Estado manual: mostrar badge SOLO si el usuario sobre-escribe un estado automático (Geofencing)
      showManualBadge = manualOverride == true;

      // Caso 3.2: si salió de zona y estaba en manual override, mostrar ubicación desconocida
      locationInfo = locationUnknown == true ? '❓ Ubicación desconocida' : null;
    }

    final coordinates = statusData['coordinates'] as Map<String, dynamic>?;
    final timestamp = statusData['timestamp'];
    DateTime? lastUpdate;
    if (timestamp is Timestamp) {
      lastUpdate = timestamp.toDate();
    }

    final result = {
      'emoji': emoji,
      'status': statusType,
      'coordinates': coordinates,
      'hasGPS': coordinates != null && statusType == 'sos', // GPS solo relevante para SOS
      'lastUpdate': lastUpdate,
      'autoUpdated': autoUpdated, // 🆕 Flag para saber si es actualización automática
      'zoneName': zoneName, // 🆕 Nombre de la zona (opcional)
      'displayText': displayText, // 🆕 Texto a mostrar (zona o estado)
      'showManualBadge': showManualBadge, // 🆕 Mostrar badge ✋ Manual
      'locationInfo': locationInfo, // 🆕 Info de ubicación desconocida/última zona
    };

    return result;
  }

  bool _hasChanged(Map<String, dynamic>? oldData, Map<String, dynamic> newData) {
    if (oldData == null) return true; // Siempre cambia si no había data previa
    // Comparar campos relevantes (incluyendo emoji que cambia con customEmoji)
    return oldData['emoji'] != newData['emoji'] || // 🆕 Detecta cambio de emoji de zona
        oldData['status'] != newData['status'] ||
        oldData['autoUpdated'] != newData['autoUpdated'] || // 🆕 Detecta cambio manual ↔ automático
        oldData['zoneName'] != newData['zoneName'] || // 🆕 Detecta cambio de zona
        oldData['displayText'] != newData['displayText'] || // 🆕 Detecta cambio de texto
        oldData['showManualBadge'] != newData['showManualBadge'] || // 🆕 Detecta cambio de badge
        oldData['locationInfo'] != newData['locationInfo'] || // 🆕 Detecta cambio de ubicación
        oldData['lastUpdate']?.millisecondsSinceEpoch != newData['lastUpdate']?.millisecondsSinceEpoch ||
        oldData['coordinates']?.toString() != newData['coordinates']?.toString(); // Comparación simple para coordenadas
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
                      const Text('NunaKin', style: _AppTextStyles.screenTitle),
                      Text(
                        _getCurrentUserNickname(ref),
                        style: _AppTextStyles.userNickname,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  key: const Key('btn_settings'),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                            const Icon(Icons.hub, size: 28, color: _AppColors.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(circle.name, style: _AppTextStyles.cardTitle),
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
                        const Text('Código de Invitación', style: _AppTextStyles.cardSubtitle),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(circle.invitationCode, key: const Key('text_invite_code'), style: _AppTextStyles.invitationCode),
                            ),
                            IconButton(
                              onPressed: () => _copyToClipboard(context, circle.invitationCode),
                              icon: const Icon(Icons.copy, size: 24, color: _AppColors.accent),
                              tooltip: 'Copiar código',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // --- SOLICITUDES DE INGRESO (solo visible para el creador) ---
                  if (FirebaseAuth.instance.currentUser?.uid == widget.circle.creatorId &&
                      _pendingRequests.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.person_add_outlined,
                            size: 24, color: _AppColors.accent),
                        const SizedBox(width: 8),
                        Text(
                          'Solicitudes de ingreso (${_pendingRequests.length})',
                          style: _AppTextStyles.screenTitle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._pendingRequests.map((req) => _JoinRequestCard(
                          request: req,
                          onApprove: () => _approveRequest(req),
                        )),
                  ],

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Divider(color: _AppColors.cardBorder, thickness: 1),
                  ),

                  MemberStatusGrid(
                    sortedMemberIds: _getSortedMembers(circle.members),
                    nicknamesCache: _memberNicknamesCache,
                    memberDataCache: _memberDataCache,
                    isLoading: _isLoadingNicknames,
                    currentUserId: FirebaseAuth.instance.currentUser?.uid,
                    currentUserNickname: _getCurrentUserNickname(ref),
                    lastKnownStatusId: _lastKnownStatusId,
                    predefinedEmojis: _predefinedEmojis,
                    onTapStatus: (ctx, activeStatusId) {
                      if (ctx.mounted) {
                        showEmojiStatusBottomSheet(ctx, activeStatusId: activeStatusId);
                      }
                    },
                    onOpenMaps: _openGoogleMaps,
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

  /// PM3/PM4 FIX: Migrar estados del sistema viejo (enum) al nuevo (class)
  String _migrateOldStatus(String? oldStatus) {
    if (oldStatus == null) return 'fine';

    switch (oldStatus) {
      case 'available': // "Libre" en sistema viejo → "Todo bien" en nuevo
        return 'fine';
      case 'leave': // "Saliendo" en sistema viejo → "Ausente" en nuevo
        return 'away';
      case 'ready': // "Listo" en sistema viejo → "Todo bien" en nuevo
        return 'fine';
      case 'sad': // "Triste" en sistema viejo → "No molestar" en nuevo
        return 'do_not_disturb';
      default:
        return oldStatus; // Estados válidos pasan sin cambios
    }
  }

  /// Actualización rápida del estado a "fine" (✅)
  Future<void> _quickStatusUpdate() async {
    if (_predefinedEmojis == null || _predefinedEmojis!.isEmpty) {
      await _loadPredefinedEmojis();
    }
    final emojis = _predefinedEmojis ?? StatusType.fallbackPredefined;
    final defaultStatus = emojis.firstWhere(
      (s) => s.id == 'fine',
      orElse: () => StatusType.fallbackPredefined.first,
    );
    // Fire-and-forget: el stream de Firestore actualiza el emoji en <500ms.
    // Mismo patrón que StatusSelectorOverlay._handleStatusSelection().
    StatusService.updateUserStatus(defaultStatus);
  }

  Future<void> _approveRequest(JoinRequest request) async {
    try {
      await _circleService.approveJoinRequest(widget.circle.id, request.userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aprobar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Muestra dialog de confirmación antes de activar Modo Silencio.
  /// Fondo negro, borde menta, letras blancas — coherente con el resto del diseño.
  Future<void> _confirmAndActivateSilentMode(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF1CE4B3).withValues(alpha: 0.4), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Activar Modo Silencio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text(
                  'La app se minimizará y quedará activa en segundo plano. '
                  'Podrás cambiar tu estado desde la notificación persistente.',
                  style: TextStyle(fontSize: 14, color: Color(0xCCFFFFFF)),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: TextButton.styleFrom(foregroundColor: Colors.white70),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: TextButton.styleFrom(foregroundColor: Color(0xFF1CE4B3)),
                      child: const Text('Activar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true && context.mounted) {
      setState(() => _isUpdatingStatus = true);
      try {
        await SilentFunctionalityCoordinator.activateSilentMode(context);
      } catch (e) {
        log('[InCircleView] ⚠️ Error activando Modo Silencio: $e');
      } finally {
        if (mounted) setState(() => _isUpdatingStatus = false);
      }
    }
  }

  /// Construye el botón del footer
  Widget _buildFooterButton(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Botón secundario: Modo Silencio
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    key: const Key('btn_silent_mode'),
                    onPressed: _isUpdatingStatus
                        ? null
                        : () => _confirmAndActivateSilentMode(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _AppColors.accent,
                      disabledForegroundColor: _AppColors.textSecondary,
                      backgroundColor: Colors.black,
                      side: const BorderSide(color: _AppColors.accent),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    icon: const Icon(Icons.bedtime_outlined, size: 18),
                    label: const Text(
                      'Modo Silencio',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Botón primario: OK / Actualizar estado
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    key: const Key('btn_change_status'),
                    onPressed: _isUpdatingStatus ? null : () => _quickStatusUpdate(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AppColors.accent,
                      foregroundColor: _AppColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        Text(_isUpdatingStatus ? '...' : 'OK'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Obtiene el nickname del usuario actual desde Riverpod
  String _getCurrentUserNickname(WidgetRef ref) {
    final authState = ref.watch(authProvider); // Asume que authProvider está definido e importado
    if (authState is Authenticated) {
      return authState.user.nickname.isNotEmpty ? authState.user.nickname : authState.user.email.split('@')[0];
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
  Future<Map<String, String>> _getAllMemberNicknames(List<String> memberIds) async {
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
            finalNickname = '...';
          return MapEntry(uid, finalNickname);
        } else {
          return MapEntry(uid, '...');
        }
      } catch (e) {
        debugPrint('Error fetching nickname for $uid: $e');
        return MapEntry(uid, '...');
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
  void _openGoogleMaps(BuildContext context, Map<String, dynamic> coordinates, String memberName) async {
    try {
      final latitude = coordinates['latitude'] as double?;
      final longitude = coordinates['longitude'] as double?;
      if (latitude == null || longitude == null) {
        _showError(context, 'Coordenadas GPS no válidas');
        return;
      }
      // Asume que Coordinates existe o adapta la llamada
      final url = GPSService.generateSOSLocationUrl(
        Coordinates(latitude: latitude, longitude: longitude), // Adapta si es necesario
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
      debugPrint('Error opening Google Maps: $e');
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

} // Fin de _InCircleViewState

// ==============================================================================
// JOIN REQUEST CARD — Tarjeta de solicitud de ingreso (visible solo al creador)
// ==============================================================================
class _JoinRequestCard extends StatelessWidget {
  final JoinRequest request;
  final VoidCallback onApprove;

  const _JoinRequestCard({
    required this.request,
    required this.onApprove,
  });

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _AppColors.accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 20, color: _AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.nickname.isNotEmpty ? request.nickname : request.userId,
                  style: _AppTextStyles.memberNickname,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (request.requestedAt != null)
                Text(
                  _timeAgo(request.requestedAt),
                  style: const TextStyle(
                      fontSize: 12, color: _AppColors.textSecondary),
                ),
            ],
          ),
          if (request.email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              request.email,
              style: const TextStyle(
                  fontSize: 13, color: _AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: ValueKey('btn_approve_${request.userId}'),
              onPressed: onApprove,
              style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.accent,
                foregroundColor: _AppColors.background,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
              ),
              child: const Text('Aceptar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

