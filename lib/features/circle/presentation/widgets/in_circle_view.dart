import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nunakin_app/platform/persistence/native_keys.dart';
// Asegúrate que las rutas de importación sean correctas para tu proyecto
import '../../../../services/circle_service.dart';
import '../../../../contexts/identity/presentation/provider/auth_provider.dart';
import '../../../../contexts/identity/presentation/provider/auth_state.dart';
import '../../../../core/widgets/emoji_modal.dart';
import '../../../../core/services/status_service.dart';
import '../../../../core/services/emoji_service.dart';
import '../../../../core/services/silent_functionality_coordinator.dart';
import '../../../../core/models/user_status.dart';
import '../../../geofencing/services/geofencing_service.dart';
import 'package:nunakin_app/app/di/injection_container.dart';
import 'package:nunakin_app/shared/events/domain_event_bus.dart';
import 'member_status_grid.dart';
import 'in_circle_header.dart';
import 'circle_info_card.dart';
import 'join_requests_banner.dart';
import 'in_circle_footer.dart';
import 'member_data_parser.dart';
import 'member_data_repository.dart';
import 'circle_actions.dart';
import '../../../../core/services/native_state_bridge.dart';
import '../../../../core/services/emoji_cache_service.dart';
import '../../../../app/theme/design_tokens.dart';
// Asumo que tienes una clase Coordinates en gps_service.dart o similar
// import '../../../../core/services/gps_service.dart' show Coordinates;


class InCircleView extends ConsumerStatefulWidget {
  final Circle circle;

  const InCircleView({super.key, required this.circle});

  @override
  ConsumerState<InCircleView> createState() => _InCircleViewState();
}

class _InCircleViewState extends ConsumerState<InCircleView> {
  final Map<String, Map<String, dynamic>> _memberDataCache = {};
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
  late final MemberDataRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = MemberDataRepository(
      circleId: widget.circle.id,
      service: _circleService,
    );
    _loadPredefinedEmojis();
    _loadLastKnownStatusId(); // Leer último estado conocido desde SharedPreferences
    _listenToCustomEmojis(); // Escuchar cambios en emojis personalizados

    // ==================== CACHE-FIRST PATTERN ====================
    // Si cache persistente está listo, carga inmediata; si no, espera postFrame.
    if (_repo.isPersistentCacheReady) {
      _loadFromCache();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_repo.isPersistentCacheReady) {
          _loadFromCache();
        } else {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _repo.isPersistentCacheReady) _loadFromCache();
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
      _repo.fetchNicknames(newMembers).then((nicknames) {
        if (!mounted) return;
        setState(() => _memberNicknamesCache.addAll(nicknames));
        _repo.saveNicknames(_memberNicknamesCache);
      });
    }
  }

  @override
  void dispose() {
    _repo.saveAll(_memberNicknamesCache, _memberDataCache);
    _circleListenerSubscription?.cancel();
    _customEmojisListener?.cancel();
    _joinRequestsSubscription?.cancel();
    _stopGeofencingMonitoring();
    super.dispose();
  }

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
      // Usar el snapshot directamente evita la race: EmojiService.clearCache()
      // limpia _cachedCustomByCircle al crear/borrar un emoji, y getCustomEmojis()
      // puede consultar el servidor antes de que confirme el write nuevo.
      // El snapshot del listener siempre incluye el write local de Firestore.
      _rebuildFromCustomSnapshot(snapshot);
    }, onError: (error) {
      debugPrint('[InCircleView] Error en listener de emojis: $error');
    });
  }

  Future<void> _rebuildFromCustomSnapshot(QuerySnapshot snapshot) async {
    try {
      final predefined = await EmojiService.getPredefinedEmojis();
      final custom = snapshot.docs
          .map((doc) => StatusType.fromFirestore(doc))
          .toList();
      if (mounted) {
        setState(() => _predefinedEmojis = [...predefined, ...custom]);
      }
    } catch (e) {
      debugPrint('[InCircleView] Error reconstruyendo desde snapshot: $e');
      _loadPredefinedEmojis(); // fallback al camino legacy
    }
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

  /// Cache-first: carga sincrónica desde memoria → disco.
  void _loadFromCache() {
    final cached = _repo.loadFromCache();
    if (cached == null) return;
    setState(() {
      _memberNicknamesCache.addAll(cached.nicknames);
      _memberDataCache.addAll(cached.memberData);
      _isLoadingNicknames = false;
    });
  }

  /// Refresca nicknames desde Firestore en background (sin bloquear UI).
  void _refreshDataInBackground() {
    _repo.fetchNicknames(widget.circle.members).then((nicknames) {
      if (!mounted) return;
      setState(() {
        _memberNicknamesCache.addAll(nicknames);
        _isLoadingNicknames = false;
      });
      _repo.saveNicknames(_memberNicknamesCache);
    }).catchError((error) {
      debugPrint('[InCircleView] Error refrescando nicknames: $error');
    });
  }

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

          if (MemberDataParser.hasChanged(oldData, newData)) {
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

          _repo.saveMemberData(_memberDataCache);
        }
      }
    }, onError: (error) {
      debugPrint('[InCircleView] Error en listener de círculo: $error');
    });
  }

  Map<String, dynamic> _parseMemberData(dynamic statusData) {
    final parser = MemberDataParser(
      predefinedEmojis: _predefinedEmojis,
      onMissingEmoji: _loadPredefinedEmojis,
    );
    return parser.parse(statusData);
  }

  @override
  Widget build(BuildContext context) {
    final circle = widget.circle;

    return Scaffold(
      backgroundColor: NkColors.canvas,
      body: Column(
        children: [
          // --- HEADER ---
          InCircleHeader(nickname: _getCurrentUserNickname(ref)),

          // --- BODY ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleInfoCard(
                    circleName: circle.name,
                    memberCount: circle.members.length,
                    invitationCode: circle.invitationCode,
                    onCopyCode: () => CircleActions.copyToClipboard(context, circle.invitationCode),
                  ),
                  JoinRequestsBanner(
                    requests: _pendingRequests,
                    isOwner: FirebaseAuth.instance.currentUser?.uid == widget.circle.creatorId,
                    onApprove: _approveRequest,
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Divider(color: NkColors.surface4, thickness: 1),
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
                    onOpenMaps: CircleActions.openGoogleMaps,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: InCircleFooter(onOk: _quickStatusUpdate),
    );
  }

  // =========================================================================
  // === Métodos Auxiliares (sin cambios respecto a tu código original) ===
  // =========================================================================

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

  /// Obtiene el nickname del usuario actual desde Riverpod.
  /// Fallback síncrono: usa displayName de FirebaseAuth (disponible en frío)
  /// mientras authProvider completa su primer read a Firestore.
  String _getCurrentUserNickname(WidgetRef ref) {
    final authState = ref.watch(authProvider);
    if (authState is Authenticated) {
      return authState.user.nickname.isNotEmpty
          ? authState.user.nickname
          : authState.user.email.split('@')[0];
    }
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser != null) {
      final dn = fbUser.displayName;
      if (dn != null && dn.isNotEmpty) return dn;
      return fbUser.email?.split('@')[0] ?? '...';
    }
    return '...';
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

}

