import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../contexts/identity/presentation/provider/auth_provider.dart';
import '../../../../contexts/identity/presentation/provider/auth_state.dart';
import '../../../../contexts/identity/presentation/pages/auth_final_page.dart';
import '../../../../core/services/silent_functionality_coordinator.dart'; // Point 1 SPEC
import '../../../../core/services/session_cache_service.dart'; // FIX: Para limpiar cache en logout
import '../../../../core/widgets/nk_dialog.dart';
import 'emoji_management_page.dart'; // Gestión de estados/emojis
import '../../../geofencing/presentation/pages/zones_page.dart'; // Gestión de zonas geográficas
import '../../../../services/circle_service.dart'; // Para obtener Circle object

// ===========================================================================
// SECCIÓN DE DISEÑO: Colores y Estilos basados en la pantalla de referencia
// ===========================================================================

/// Paleta de colores extraída del diseño de la pantalla de referencia (InCircleView).
class _AppColors {
  static const Color background    = NkColors.canvas;
  static const Color accent        = NkColors.mint;
  static const Color textPrimary   = NkColors.onDark;
  static const Color textSecondary = NkColors.fgSub;
  static const Color cardBackground = NkColors.surface2;
  static const Color cardBorder    = NkColors.surface4;
  static const Color sosRed        = NkColors.danger;
  static const Color inputFill     = NkColors.surface3;
}

/// Estilos de texto consistentes con el diseño de referencia.
class _AppTextStyles {
  static const TextStyle screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: _AppColors.textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: _AppColors.textPrimary,
  );

  static const TextStyle textBody = TextStyle(
    fontSize: 14,
    color: _AppColors.textSecondary,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle label = TextStyle(
    fontSize: 14,
    color: _AppColors.textSecondary,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle destructiveLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: _AppColors.sosRed,
  );
}

/// Pantalla de configuración del usuario
/// Permite cambiar nombre de usuario, nombre del círculo y salir del círculo
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> with SingleTickerProviderStateMixin {
  // --- INICIO DE LÓGICA (SIN CAMBIOS) ---
  final _userNameController = TextEditingController();
  final _circleNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isLoadingCircle = true;
  String? _userId;
  String? _circleId;
  String? _currentUserName; // nickname/displayName
  String? _currentCircleName;
  String? _userEmail; // email (solo lectura)

  // Tab controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    debugPrint('[SettingsPage] 🔧 Inicializando pantalla de configuración');
    _loadCurrentInfo();

    // Cargar datos de Firebase DESPUÉS del primer frame (no bloquear)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFirebaseDataInBackground();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userNameController.dispose();
    _circleNameController.dispose();
    super.dispose();
  }

  /// Carga la información actual del usuario y círculo (SÍNCRONO)
  void _loadCurrentInfo() {
    try {
      final authState = ref.read(authProvider);

      if (authState is Authenticated) {
        _userId = authState.user.uid;
        _userEmail = authState.user.email;
        _currentUserName =
            authState.user.nickname.isNotEmpty ? authState.user.nickname : authState.user.email.split('@')[0];
        _userNameController.text = _currentUserName ?? '';
        debugPrint('[SettingsPage] ⚡ Usuario cargado desde authProvider: nickname=[$_currentUserName]');
      } else {
        // authProvider puede estar en AuthInitial/AuthLoading si el stream aún no emitió.
        // FirebaseAuth.instance.currentUser es la fuente síncrona confiable en este caso.
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          _userId = fbUser.uid;
          _userEmail = fbUser.email;
          final displayName = fbUser.displayName;
          _currentUserName = (displayName != null && displayName.isNotEmpty)
              ? displayName
              : fbUser.email?.split('@')[0];
          _userNameController.text = _currentUserName ?? '';
          if (kDebugMode) {
            debugPrint('[SettingsPage] ⚡ Usuario cargado desde FirebaseAuth fallback: email=[$_userEmail]');
          }
        }
      }
    } catch (e) {
      debugPrint('[SettingsPage] ❌ Error cargando información: $e');
    }
  }

  /// Carga datos de Firebase en background (ASÍNCRONO - no bloquea UI)
  Future<void> _loadFirebaseDataInBackground() async {
    try {
      // Cargar datos de Firebase sin bloquear
      await _loadUserNickname();
      await _loadCircleInfo();
    } catch (e) {
      debugPrint('[SettingsPage] ❌ Error cargando datos de Firebase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error cargando datos: ${e.toString()}'),
            backgroundColor: _AppColors.sosRed,
          ),
        );
      }
    }
  }

  /// Carga el nickname del usuario desde Firestore
  Future<void> _loadUserNickname() async {
    if (_userId == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        // Prioridad: nickname > displayName > fallback al email split
        _currentUserName = userData['nickname'] as String? ??
            userData['displayName'] as String? ??
            _userEmail?.split('@')[0] ??
            'Usuario';

        if (mounted) {
          setState(() {
            _userNameController.text = _currentUserName ?? '';
          });
        }

        debugPrint('[SettingsPage] 🔧 Nickname cargado: $_currentUserName');
      }
    } catch (e) {
      debugPrint('[SettingsPage] ❌ Error cargando nickname: $e');
    }
  }

  /// Carga información del círculo desde Firebase
  Future<void> _loadCircleInfo() async {
    if (_userId == null) return;

    try {
      // Buscar el círculo del usuario
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_userId).get();

      if (userDoc.exists && userDoc.data()?['circleId'] != null) {
        _circleId = userDoc.data()!['circleId'] as String;

        // Obtener información del círculo
        final circleDoc = await FirebaseFirestore.instance.collection('circles').doc(_circleId).get();

        if (circleDoc.exists) {
          _currentCircleName = circleDoc.data()?['name'] as String?;
          debugPrint('[SettingsPage] 🔧 Círculo cargado: $_currentCircleName (ID: $_circleId)');
          if (mounted) {
            setState(() {
              _circleNameController.text = _currentCircleName ?? '';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[SettingsPage] Error cargando círculo: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCircle = false);
    }
  }

  /// Actualiza el nickname del usuario (NO el email que es credencial de auth)
  Future<void> _updateUserName() async {
    if (_userId == null || _userNameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final newNickname = _userNameController.text.trim();

      // CRÍTICO: Solo actualizar nickname/displayName, NUNCA el email

      // 1. Actualizar en Firebase Auth displayName
      await FirebaseAuth.instance.currentUser?.updateDisplayName(newNickname);

      // 2. Pre-warm Firestore WebSocket antes de escribir (puede estar frío al abrir Settings)
      try {
        await FirebaseFirestore.instance.enableNetwork().timeout(const Duration(seconds: 3));
      } catch (_) {}

      // 3. Actualizar nickname en Firestore (perfil del usuario)
      await FirebaseFirestore.instance.collection('users').doc(_userId).update({
        'nickname': newNickname,
        'displayName': newNickname, // Mantener ambos por compatibilidad
      });

      // 4. Actualizar variable local y notificar AuthNotifier para reactividad
      _currentUserName = newNickname;
      await ref.read(authProvider.notifier).refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Nickname actualizado correctamente'),
            backgroundColor: Colors.green, // <-- CAMBIO DE UI (Se mantiene verde para éxito)
          ),
        );
      }
    } catch (e) {
      debugPrint('[SettingsPage] Error actualizando nickname: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error actualizando nickname: ${e.toString()}'),
            backgroundColor: _AppColors.sosRed, // <-- CAMBIO DE UI
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Actualiza el nombre del círculo
  Future<void> _updateCircleName() async {
    if (_circleId == null || _circleNameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final newName = _circleNameController.text.trim();

      // Pre-warm Firestore WebSocket antes de escribir (puede estar frío al abrir Settings)
      try {
        await FirebaseFirestore.instance.enableNetwork().timeout(const Duration(seconds: 3));
      } catch (_) {}

      // Actualizar nombre del círculo en Firestore
      await FirebaseFirestore.instance.collection('circles').doc(_circleId).update({'name': newName});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Nombre del círculo actualizado'),
            backgroundColor: Colors.green, // <-- CAMBIO DE UI (Se mantiene verde para éxito)
          ),
        );
      }
    } catch (e) {
      debugPrint('[SettingsPage] Error actualizando círculo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: _AppColors.sosRed, // <-- CAMBIO DE UI
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Point 1 SPEC: Muestra diálogo de confirmación para eliminar cuenta
  void _showDeleteAccountDialog(BuildContext context) async {
    final confirmed = await NkDialog.confirm(
      context,
      title: 'Eliminar Cuenta',
      body: '¿Estás seguro? Esta acción es irreversible. Se eliminarán tu cuenta y todos tus datos.',
      confirmLabel: 'Eliminar Cuenta',
      confirmDestructive: true,
      barrierDismissible: false,
    );
    if (confirmed == true && mounted) {
      _executeDeleteAccount(this.context);
    }
  }

  Future<void> _executeDeleteAccount(BuildContext context) async {
    if (!mounted) return;

    final currentCircle = await CircleService().getUserCircle();
    final wasInCircle = currentCircle != null;

    if (!context.mounted) return;

    _showReauthDialog(context, wasInCircle: wasInCircle);
  }

  void _showReauthDialog(BuildContext context, {bool wasInCircle = false}) {
    final passwordController = TextEditingController();
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (sbContext, setDialogState) => AlertDialog(
          backgroundColor: _AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirmar identidad', style: TextStyle(color: _AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Por seguridad, ingresa tu contraseña para confirmar la eliminación.',
                style: TextStyle(color: _AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                style: const TextStyle(color: _AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  labelStyle: const TextStyle(color: _AppColors.textSecondary),
                  filled: true,
                  fillColor: _AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _AppColors.accent, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: _AppColors.textSecondary,
                    ),
                    onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (wasInCircle && context.mounted) {
                  _showCircleLostInfoDialog(context);
                }
              },
              child: const Text('Cancelar', style: TextStyle(color: _AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final sw = Stopwatch()..start();
                debugPrint('[DELETE][1] Confirmar presionado — cerrando diálogo de contraseña');
                Navigator.of(dialogContext).pop();
                debugPrint('[DELETE][2] Diálogo cerrado — context.mounted: ${context.mounted} | ${sw.elapsed}');
                if (!context.mounted) {
                  debugPrint('[DELETE][2x] context no montado — saliendo temprano');
                  return;
                }

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(NkColors.mint),
                    ),
                  ),
                );
                debugPrint('[DELETE][3] Spinner mostrado | ${sw.elapsed}');

                try {
                  debugPrint('[DELETE][4] Iniciando reauthenticateWithCredential... | ${sw.elapsed}');
                  final credential = EmailAuthProvider.credential(
                    email: email,
                    password: passwordController.text,
                  );
                  await FirebaseAuth.instance.currentUser!.reauthenticateWithCredential(credential);
                  debugPrint('[DELETE][5] Reautenticación exitosa | ${sw.elapsed}');

                  debugPrint('[DELETE][6] Iniciando deactivateAfterLogout() con timeout 10s... | ${sw.elapsed}');
                  await SilentFunctionalityCoordinator.deactivateAfterLogout().timeout(
                    const Duration(seconds: 10),
                    onTimeout: () {
                      debugPrint('[DELETE][6x] TIMEOUT en deactivateAfterLogout() | ${sw.elapsed}');
                    },
                  );
                  debugPrint('[DELETE][7] deactivateAfterLogout completado | ${sw.elapsed}');

                  debugPrint('[DELETE][8] Iniciando clearSession()... | ${sw.elapsed}');
                  await SessionCacheService.clearSession();
                  debugPrint('[DELETE][9] clearSession completado | ${sw.elapsed}');

                  // Cerrar spinner ANTES de deleteAccount() — el stream de Firestore
                  // desmonta el contexto durante la eliminación y el spinner quedaría colgado.
                  debugPrint('[DELETE][10] Cerrando spinner — context.mounted: ${context.mounted} | ${sw.elapsed}');
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                  debugPrint('[DELETE][11] Spinner cerrado | ${sw.elapsed}');

                  debugPrint('[DELETE][12] Iniciando deleteAccount() con timeout 30s... | ${sw.elapsed}');
                  await CircleService().deleteAccount().timeout(
                    const Duration(seconds: 30),
                    onTimeout: () {
                      debugPrint('[DELETE][12x] TIMEOUT en deleteAccount() | ${sw.elapsed}');
                      throw Exception('Timeout eliminando cuenta');
                    },
                  );
                  debugPrint('[DELETE][13] deleteAccount completado | ${sw.elapsed}');

                  // AuthWrapper navega al login vía authStateChanges cuando detecta
                  // que la cuenta fue eliminada. Este bloque es un respaldo.
                  debugPrint('[DELETE][14] Intentando navegar a AuthFinalPage — context.mounted: ${context.mounted} | ${sw.elapsed}');
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthFinalPage()),
                      (route) => false,
                    );
                    debugPrint('[DELETE][15] Navegación a AuthFinalPage ejecutada | ${sw.elapsed}');
                  } else {
                    debugPrint('[DELETE][14x] context no montado — navegación omitida (AuthWrapper tomará control) | ${sw.elapsed}');
                  }
                } on FirebaseAuthException catch (e) {
                  debugPrint('[DELETE][ERR-AUTH] FirebaseAuthException: ${e.code} | ${sw.elapsed}');
                  if (!context.mounted) return;
                  Navigator.of(context, rootNavigator: true).pop();
                  final msg = (e.code == 'wrong-password' || e.code == 'invalid-credential')
                      ? 'Contraseña incorrecta. Intenta de nuevo.'
                      : 'Error de autenticación. Intenta de nuevo.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg, style: const TextStyle(color: NkColors.onDark)),
                      backgroundColor: NkColors.danger,
                    ),
                  );
                } catch (e) {
                  debugPrint('[DELETE][ERR] Error genérico: $e | ${sw.elapsed}');
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al eliminar la cuenta: $e', style: const TextStyle(color: Colors.white)),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Confirmar', style: TextStyle(color: _AppColors.sosRed)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCircleLostInfoDialog(BuildContext context) {
    NkDialog.inform(
      context,
      title: 'Ya no estás en tu círculo',
      body: 'Al cancelar la eliminación saliste de tu círculo. Para volver, pídele a alguien del grupo que te comparta el código de invitación.',
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await NkDialog.confirm(
      context,
      title: 'Cerrar Sesión',
      body: '¿Estás seguro?',
      confirmLabel: 'Cerrar Sesión',
      barrierDismissible: false,
    );
    if (confirmed != true) return;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(NkColors.mint),
          ),
        ),
      );
    }

    try {
      print('🔴 [LOGOUT] Iniciando proceso de logout desde Settings...');
      print('🔴 [LOGOUT] Paso 1/3: Desactivando funcionalidad silenciosa...');
      await SilentFunctionalityCoordinator.deactivateAfterLogout().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⚠️ [LOGOUT] Timeout en deactivateAfterLogout, continuando...');
        },
      );
      print('🔴 [LOGOUT] Limpiando SessionCache...');
      await SessionCacheService.clearSession();
      print('🔴 [LOGOUT] Paso 2/3: Cerrando sesión de Firebase...');
      await FirebaseAuth.instance.signOut().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⚠️ [LOGOUT] Timeout en signOut, continuando...');
        },
      );
      print('🔴 [LOGOUT] Paso 3/3: Redirigiendo a login...');
    } catch (e) {
      print('❌ [LOGOUT] Error durante logout: $e');
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthFinalPage()),
          (route) => false,
        );
        print('✅ [LOGOUT] Logout completado exitosamente');
      }
    }
  }

  /// Sem9 Paso 8: confirma y ejecuta el cierre de sesión remota (revoke_own_sessions).
  /// Invalida los refresh tokens del propio uid en TODOS los dispositivos, incluido este.
  void _showRevokeSessionsDialog(BuildContext context) async {
    final confirmed = await NkDialog.confirm(
      context,
      title: 'Cerrar sesión en todos los dispositivos',
      body:
          'Esto cerrará tu sesión en TODOS los dispositivos donde hayas iniciado sesión con esta cuenta, incluido este. Tendrás que volver a iniciar sesión.',
      confirmLabel: 'Cerrar en todos',
      confirmDestructive: true,
      barrierDismissible: false,
    );
    if (confirmed != true) return;
    if (context.mounted) {
      await _executeRevokeSessions(context);
    }
  }

  Future<void> _executeRevokeSessions(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(NkColors.mint),
        ),
      ),
    );

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('revoke_own_sessions');
      await callable.call();

      await SilentFunctionalityCoordinator.deactivateAfterLogout().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[SettingsPage] ⚠️ Timeout en deactivateAfterLogout (revoke sessions)');
        },
      );
      await SessionCacheService.clearSession();
      await FirebaseAuth.instance.signOut();

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthFinalPage()),
          (route) => false,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[SettingsPage] ❌ Error revoke_own_sessions: ${e.code} — ${e.message}');
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message ?? e.code}'),
            backgroundColor: _AppColors.sosRed,
          ),
        );
      }
    } catch (e) {
      debugPrint('[SettingsPage] ❌ Error inesperado revoke_own_sessions: $e');
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cerrando sesión remota: $e'),
            backgroundColor: _AppColors.sosRed,
          ),
        );
      }
    }
  }

  /// Muestra diálogo de confirmación para salir del círculo actual.
  void _showLeaveCircleDialog(BuildContext context) async {
    final confirmed = await NkDialog.confirm(
      context,
      title: 'Salir del círculo',
      body:
          '¿Estás seguro de que quieres salir de "${_currentCircleName ?? 'tu círculo'}"? Esta acción no se puede deshacer.',
      confirmLabel: 'Salir del círculo',
      barrierDismissible: false,
    );
    if (confirmed != true) return;
    if (context.mounted) {
      await _leaveCircle(context);
    }
  }

  /// Sale del círculo actual vía CircleService.leaveCircle().
  /// Si el usuario es el Creador, el servicio promueve automáticamente
  /// al miembro más antiguo sobreviviente (sucesión silenciosa, sin diálogo).
  Future<void> _leaveCircle(BuildContext context) async {
    setState(() => _isLoadingCircle = true);
    try {
      await CircleService().leaveCircle();
      if (mounted) {
        setState(() {
          _circleId = null;
          _currentCircleName = null;
          _circleNameController.text = '';
          _isLoadingCircle = false;
        });
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saliste del círculo.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCircle = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al salir del círculo: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: _AppColors.sosRed,
          ),
        );
      }
    }
  }
  // --- FIN DE LÓGICA (SIN CAMBIOS) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        backgroundColor: _AppColors.background,
        foregroundColor: _AppColors.textPrimary,
        title: const Text(
          'Configuración',
          style: _AppTextStyles.screenTitle,
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _AppColors.accent,
          labelColor: _AppColors.accent,
          unselectedLabelColor: _AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Cuenta'),
            Tab(text: 'Círculo'),
            Tab(text: 'Estados'),
            Tab(text: 'Zonas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAccountTab(),
          _buildCircleTab(),
          _buildStatesTab(),
          _buildZonesTab(),
        ],
      ),
    );
  }

  Widget _buildAccountTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _AppColors.accent),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sección: Perfil del usuario
            _buildSectionCard(
              title: 'Tu perfil',
              children: [
                // Email (solo lectura)
                const Text(
                  'Email (no se puede cambiar)',
                  style: _AppTextStyles.label,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _AppColors.cardBorder, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email, color: _AppColors.textSecondary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _userEmail ?? 'Cargando...',
                          style: _AppTextStyles.textBody,
                        ),
                      ),
                      const Icon(Icons.lock, color: _AppColors.textSecondary, size: 16),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Nickname (editable)
                const Text(
                  'Nickname',
                  style: _AppTextStyles.label,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _userNameController,
                  style: const TextStyle(color: _AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Ingresa tu nickname',
                    hintStyle: const TextStyle(color: _AppColors.textSecondary),
                    filled: true,
                    fillColor: _AppColors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.person, color: _AppColors.textSecondary),
                    suffixIcon: IconButton(
                      onPressed: _updateUserName,
                      icon: const Icon(
                        Icons.check,
                        color: _AppColors.accent,
                      ),
                      tooltip: 'Guardar nickname',
                    ),
                  ),
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) {
                      return 'El nickname no puede estar vacío';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Este es el nombre que verán los miembros de tu círculo.',
                  style: _AppTextStyles.textBody.copyWith(fontSize: 12),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Point 1 SPEC: Sección Cerrar Sesión
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _AppColors.sosRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _AppColors.sosRed.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Sesión',
                    style: _AppTextStyles.destructiveLabel,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Cerrar sesión eliminará todas las notificaciones activas y te redirigirá al login.',
                    style: _AppTextStyles.textBody,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showLogoutDialog(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC401),
                      foregroundColor: NkColors.canvas,
                      padding: const EdgeInsets.symmetric(vertical: NkSpacing.s),
                      shape: RoundedRectangleBorder(
                        borderRadius: NkRadius.forInput,
                      ),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar Sesión', style: TextStyle(color: NkColors.canvas)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Zona de riesgo: eliminar cuenta, separado de "Sesión" para no
            // sentarlo junto a una acción rutinaria como Cerrar Sesión.
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _AppColors.sosRed.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Zona de riesgo',
                    style: _AppTextStyles.destructiveLabel,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Si perdiste acceso a un dispositivo con tu sesión abierta, ciérrala remotamente. Eliminar tu cuenta borra permanentemente tus datos personales — si estás en un círculo, sal de él primero.',
                    style: _AppTextStyles.textBody,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showRevokeSessionsDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AppColors.sosRed.withValues(alpha: 0.15),
                      foregroundColor: _AppColors.sosRed,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: _AppColors.sosRed.withValues(alpha: 0.5)),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.phonelink_erase_outlined),
                    label: const Text('Cerrar sesión en todos los dispositivos'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showDeleteAccountDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AppColors.sosRed.withValues(alpha: 0.15),
                      foregroundColor: _AppColors.sosRed,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: _AppColors.sosRed.withValues(alpha: 0.5)),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Eliminar Cuenta'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye una tarjeta de sección
  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _AppColors.cardBackground, // <-- CAMBIO DE UI
        borderRadius: BorderRadius.circular(16),
        // --- INICIO DE LA MEJORA ---
        // Se elimina el borde de las tarjetas principales
        // border: Border.all(
        //   color: _AppColors.cardBorder,
        //   width: 1,
        // ),
        // --- FIN DE LA MEJORA ---
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _AppTextStyles.cardTitle, // <-- CAMBIO DE UI
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // Tab 2: Configuración de círculo
  Widget _buildCircleTab() {
    if (_isLoading || _isLoadingCircle) {
      return const Center(
        child: CircularProgressIndicator(color: _AppColors.accent),
      );
    }

    if (_circleId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.group_off,
                size: 64,
                color: _AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'No estás en ningún círculo',
                style: TextStyle(
                  color: _AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionCard(
            title: 'Información del círculo',
            children: [
              const Text(
                'Nombre del círculo',
                style: _AppTextStyles.label,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _circleNameController,
                style: const TextStyle(color: _AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Nombre del círculo',
                  hintStyle: const TextStyle(color: _AppColors.textSecondary),
                  filled: true,
                  fillColor: _AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.group, color: _AppColors.textSecondary),
                  suffixIcon: IconButton(
                    onPressed: _updateCircleName,
                    icon: const Icon(
                      Icons.check,
                      color: _AppColors.accent,
                    ),
                    tooltip: 'Guardar nombre',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _AppColors.sosRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _AppColors.sosRed.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Salir del círculo',
                  style: _AppTextStyles.destructiveLabel,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Dejarás de compartir tu estado con este círculo. Si eres el Creador, otro miembro asumirá el rol automáticamente.',
                  style: _AppTextStyles.textBody,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showLeaveCircleDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _AppColors.sosRed.withValues(alpha: 0.15),
                    foregroundColor: _AppColors.sosRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _AppColors.sosRed.withValues(alpha: 0.5)),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Salir del círculo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tab 3: Estados/Emojis
  Widget _buildStatesTab() {
    if (_isLoadingCircle) {
      return const Center(
        child: CircularProgressIndicator(color: _AppColors.accent),
      );
    }

    if (_circleId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_emotions_outlined,
                size: 64,
                color: _AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Únete a un círculo para gestionar estados',
                style: TextStyle(
                  color: _AppColors.textSecondary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Navegar directamente a la página de gestión de emojis SIN botón intermedio
    return EmojiManagementPage(circleId: _circleId!);
  }

  // Tab 4: Zonas geográficas
  Widget _buildZonesTab() {
    if (_isLoadingCircle) {
      return const Center(
        child: CircularProgressIndicator(color: _AppColors.accent),
      );
    }

    if (_circleId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 64,
                color: _AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Únete a un círculo para gestionar zonas',
                style: TextStyle(
                  color: _AppColors.textSecondary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Cargar Circle desde Firestore y mostrar ZonesPage
    return FutureBuilder<Circle?>(
      future: FirebaseFirestore.instance.collection('circles').doc(_circleId).get().then((doc) {
        if (!doc.exists) return null;
        return Circle.fromFirestore(doc);
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _AppColors.accent),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: _AppColors.sosRed.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error al cargar el círculo',
                    style: TextStyle(
                      color: _AppColors.textSecondary,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ZonesPage(circle: snapshot.data!);
      },
    );
  }
}
