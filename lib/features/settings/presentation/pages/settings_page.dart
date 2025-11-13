import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../features/auth/presentation/provider/auth_provider.dart';
import '../../../../features/auth/presentation/provider/auth_state.dart';
import '../../../../features/auth/presentation/pages/auth_final_page.dart';
import '../../../../notifications/notification_service.dart';
import '../../../../core/widgets/quick_actions_config_widget.dart';
import '../../../../core/services/silent_functionality_coordinator.dart'; // Point 1 SPEC

// ===========================================================================
// SECCIÓN DE DISEÑO: Colores y Estilos basados en la pantalla de referencia
// ===========================================================================

/// Paleta de colores extraída del diseño de la pantalla de referencia (InCircleView).
class _AppColors {
  static const Color background = Color(0xFF000000); // Negro puro
  static const Color accent = Color(0xFF1EE9A4); // Verde menta/turquesa
  static const Color textPrimary = Color(0xFFFFFFFF); // Blanco
  static const Color textSecondary = Color(0xFF9E9E9E); // Gris para subtítulos y labels
  static const Color cardBackground = Color(0xFF1C1C1E); // Gris oscuro para menús y diálogos
  static const Color cardBorder = Color(0xFF3A3A3C); // Borde sutil para tarjetas y divider
  static const Color sosRed = Color(0xFFD32F2F); // Rojo para alertas SOS
  static const Color inputFill = Color(0xFF2C2C2E); // Relleno de inputs
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

  static const TextStyle destructiveButton = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: _AppColors.textPrimary,
  );
}


/// Pantalla de configuración del usuario
/// Permite cambiar nombre de usuario, nombre del círculo y salir del círculo
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // --- INICIO DE LÓGICA (SIN CAMBIOS) ---
  final _userNameController = TextEditingController();
  final _circleNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  String? _userId;
  String? _circleId;
  String? _currentUserName; // nickname/displayName
  String? _currentCircleName;
  String? _userEmail; // email (solo lectura)

  @override
  void initState() {
    super.initState();
    debugPrint('[SettingsPage] 🔧 Inicializando pantalla de configuración');
    _loadCurrentInfo();
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _circleNameController.dispose();
    super.dispose();
  }

  /// Carga la información actual del usuario y círculo
  void _loadCurrentInfo() async {
    try {
      final authState = ref.read(authProvider);
      
      if (authState is Authenticated) {
        _userId = authState.user.uid;
        _userEmail = authState.user.email;
        
        // Obtener nickname desde Firestore (NO desde email)
        await _loadUserNickname();
        
        debugPrint('[SettingsPage] 🔧 Usuario cargado: nickname=[$_currentUserName], email=[$_userEmail] (ID: $_userId)');
        
        // Obtener información del círculo directamente de Firebase
        await _loadCircleInfo();
      }
    } catch (e) {
      debugPrint('[SettingsPage] ❌ Error cargando información: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error cargando datos: ${e.toString()}'),
            backgroundColor: _AppColors.sosRed, // <-- CAMBIO DE UI
          ),
        );
      }
    }
  }

  /// Carga el nickname del usuario desde Firestore
  Future<void> _loadUserNickname() async {
    if (_userId == null) return;
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        // Prioridad: nickname > displayName > fallback al email split
        _currentUserName = userData['nickname'] as String? ?? 
                           userData['displayName'] as String? ?? 
                           _userEmail?.split('@')[0] ?? 'Usuario';
        
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
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();
      
      if (userDoc.exists && userDoc.data()?['circleId'] != null) {
        _circleId = userDoc.data()!['circleId'] as String;
        
        // Obtener información del círculo
        final circleDoc = await FirebaseFirestore.instance
            .collection('circles')
            .doc(_circleId)
            .get();
        
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
      
      // 2. Actualizar nickname en Firestore (perfil del usuario)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .update({
            'nickname': newNickname,
            'displayName': newNickname, // Mantener ambos por compatibilidad
          });
      
      // 3. Actualizar también en el documento del círculo si existe
      if (_circleId != null) {
        await FirebaseFirestore.instance
            .collection('circles')
            .doc(_circleId)
            .collection('members')
            .doc(_userId)
            .update({
              'nickname': newNickname,
              'displayName': newNickname,
            });
      }
      
      // 4. Actualizar variable local
      _currentUserName = newNickname;
      
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
      
      // Actualizar nombre del círculo en Firestore
      await FirebaseFirestore.instance
          .collection('circles')
          .doc(_circleId)
          .update({'name': newName});
      
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

  /// Muestra diálogo de confirmación para salir del círculo
  void _showLeaveCircleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _AppColors.cardBackground, // <-- CAMBIO DE UI
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // <-- CAMBIO DE UI
        title: Text(
          'Salir del círculo',
          style: _AppTextStyles.cardTitle.copyWith(color: _AppColors.sosRed), // <-- CAMBIO DE UI
        ),
        content: Text(
          '¿Estás seguro de que quieres salir del círculo "${_currentCircleName ?? 'actual'}"?\n\nEsta acción no se puede deshacer.',
          style: _AppTextStyles.textBody, // <-- CAMBIO DE UI
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: _AppColors.textSecondary), // <-- CAMBIO DE UI
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveCircle();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.sosRed, // <-- CAMBIO DE UI
              foregroundColor: _AppColors.textPrimary, // <-- CAMBIO DE UI
            ),
            child: const Text('Salir del círculo'),
          ),
        ],
      ),
    );
  }

  /// Sale del círculo actual
  Future<void> _leaveCircle() async {
    if (_userId == null || _circleId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      // CRÍTICO: Cancelar notificaciones antes de salir del círculo
      // Esto previene inconsistencias donde el usuario ya no está en el círculo
      // pero las notificaciones permiten actualizaciones de estado inválidas
      await NotificationService.cancelQuickActionNotification();
      
      // Remover usuario del círculo
      await FirebaseFirestore.instance
          .collection('circles')
          .doc(_circleId)
          .collection('members')
          .doc(_userId)
          .delete();
      
      // Actualizar el perfil del usuario para remover circleId
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .update({'circleId': FieldValue.delete()});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Has salido del círculo'),
            backgroundColor: Colors.green, // <-- CAMBIO DE UI (Se mantiene verde para éxito)
          ),
        );
        
        // Navegar de vuelta a la pantalla principal
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthFinalPage()),
          (route) => false,
        );
      }
      
    } catch (e) {
      debugPrint('[SettingsPage] Error saliendo del círculo: $e');
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

  /// Point 1 SPEC: Muestra diálogo de confirmación para cerrar sesión
  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false, // Evitar cerrar el diálogo accidentalmente durante el proceso
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar Sesión', style: TextStyle(color: _AppColors.textPrimary)),
        content: const Text('¿Estás seguro?', style: TextStyle(color: _AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar', style: TextStyle(color: _AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              // 1. Cerrar el diálogo PRIMERO
              Navigator.of(dialogContext).pop();
              
              // 2. Mostrar indicador de carga
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1EE9A4)),
                    ),
                  ),
                );
              }
              
              try {
                // 3. Limpiar notificaciones y servicios (Point 1.1 - paso 2 y 3)
                print('🔴 [LOGOUT] Iniciando proceso de logout desde Settings...');
                print('🔴 [LOGOUT] Paso 1/3: Desactivando funcionalidad silenciosa...');
                
                await SilentFunctionalityCoordinator.deactivateAfterLogout().timeout(
                  const Duration(seconds: 10),
                  onTimeout: () {
                    print('⚠️ [LOGOUT] Timeout en deactivateAfterLogout, continuando...');
                  },
                );
                
                print('🔴 [LOGOUT] Paso 2/3: Cerrando sesión de Firebase...');
                
                // 4. Invalidar sesión (Point 1.1 - paso 1)
                await FirebaseAuth.instance.signOut().timeout(
                  const Duration(seconds: 10),
                  onTimeout: () {
                    print('⚠️ [LOGOUT] Timeout en signOut, continuando...');
                  },
                );
                
                print('🔴 [LOGOUT] Paso 3/3: Redirigiendo a login...');
                
              } catch (e) {
                print('❌ [LOGOUT] Error durante logout: $e');
                // Continuar con navegación incluso si hay error
              } finally {
                // 5. SIEMPRE navegar a login (Point 1.1 - paso 4)
                // Garantizar que la navegación ocurra sin importar errores anteriores
                if (context.mounted) {
                  // Cerrar indicador de carga si existe
                  Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
                  
                  // Navegar a AuthFinalPage
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthFinalPage()),
                    (route) => false,
                  );
                  
                  print('✅ [LOGOUT] Logout completado exitosamente');
                }
              }
            },
            child: const Text('Cerrar Sesión', style: TextStyle(color: _AppColors.sosRed)),
          ),
        ],
      ),
    );
  }
  // --- FIN DE LÓGICA (SIN CAMBIOS) ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.background, // <-- CAMBIO DE UI
      appBar: AppBar(
        backgroundColor: _AppColors.background, // <-- CAMBIO DE UI
        foregroundColor: _AppColors.textPrimary, // <-- CAMBIO DE UI
        title: const Text(
          'Configuración',
          style: _AppTextStyles.screenTitle, // <-- CAMBIO DE UI
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _AppColors.accent)) // <-- CAMBIO DE UI
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0), // <-- CAMBIO DE UI
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sección: Perfil del usuario
                    _buildSectionCard(
                      title: 'Tu perfil', // <-- CAMBIO DE UI (Emoji quitado)
                      children: [
                        // Email (solo lectura)
                        const Text(
                          'Email (no se puede cambiar)',
                          style: _AppTextStyles.label, // <-- CAMBIO DE UI
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _AppColors.cardBackground, // <-- CAMBIO DE UI
                            borderRadius: BorderRadius.circular(12),
                            // El borde se quitó de aquí, pero se mantiene en el input de solo lectura
                            border: Border.all(color: _AppColors.cardBorder, width: 1), 
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.email, color: _AppColors.textSecondary, size: 18), // <-- CAMBIO DE UI
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _userEmail ?? 'Cargando...',
                                  style: _AppTextStyles.textBody, // <-- CAMBIO DE UI
                                ),
                              ),
                              Icon(Icons.lock, color: _AppColors.textSecondary, size: 16), // <-- CAMBIO DE UI
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Nickname (editable)
                        const Text(
                          'Nickname',
                          style: _AppTextStyles.label, // <-- CAMBIO DE UI
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _userNameController,
                          style: const TextStyle(color: _AppColors.textPrimary), // <-- CAMBIO DE UI
                          decoration: InputDecoration(
                            hintText: 'Ingresa tu nickname',
                            hintStyle: const TextStyle(color: _AppColors.textSecondary), // <-- CAMBIO DE UI
                            filled: true,
                            fillColor: _AppColors.inputFill, // <-- CAMBIO DE UI
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.person, color: _AppColors.textSecondary), // <-- CAMBIO DE UI
                            suffixIcon: IconButton(
                              onPressed: _updateUserName,
                              icon: const Icon(
                                Icons.check,
                                color: _AppColors.accent, // <-- CAMBIO DE UI
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
                          style: _AppTextStyles.textBody.copyWith(fontSize: 12), // <-- CAMBIO DE UI
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Sección: Quick Actions (Point 14)
                    // Pásame el código de este widget para aplicarle los estilos
                    const QuickActionsConfigWidget(),

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
                              backgroundColor: _AppColors.sosRed,
                              foregroundColor: _AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.logout),
                            label: const Text(
                              'Cerrar Sesión',
                              style: _AppTextStyles.destructiveButton,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sección: Círculo
                    if (_circleId != null) ...[
                      _buildSectionCard(
                        title: 'Círculo', // <-- CAMBIO DE UI (Emoji quitado)
                        children: [
                          const Text(
                            'Nombre del círculo',
                            style: _AppTextStyles.label, // <-- CAMBIO DE UI
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _circleNameController,
                            style: const TextStyle(color: _AppColors.textPrimary), // <-- CAMBIO DE UI
                            decoration: InputDecoration(
                              hintText: 'Nombre del círculo',
                              hintStyle: const TextStyle(color: _AppColors.textSecondary), // <-- CAMBIO DE UI
                              filled: true,
                              fillColor: _AppColors.inputFill, // <-- CAMBIO DE UI
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: IconButton(
                                onPressed: _updateCircleName,
                                icon: const Icon(
                                  Icons.check,
                                  color: _AppColors.accent, // <-- CAMBIO DE UI
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value?.trim().isEmpty ?? true) {
                                return 'El nombre del círculo no puede estar vacío';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Cualquier miembro del círculo puede cambiar este nombre.',
                            style: _AppTextStyles.textBody.copyWith(fontSize: 12), // <-- CAMBIO DE UI
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Botón: Salir del círculo
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _AppColors.sosRed.withOpacity(0.1), // <-- CAMBIO DE UI
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _AppColors.sosRed.withOpacity(0.3), // <-- CAMBIO DE UI
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Zona peligrosa',
                              style: _AppTextStyles.destructiveLabel, // <-- CAMBIO DE UI
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Una vez que salgas del círculo, tendrás que ser invitado nuevamente para volver a unirte.',
                              style: _AppTextStyles.textBody, // <-- CAMBIO DE UI
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showLeaveCircleDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _AppColors.sosRed, // <-- CAMBIO DE UI
                                foregroundColor: _AppColors.textPrimary, // <-- CAMBIO DE UI
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.exit_to_app),
                              label: const Text(
                                'Salir del círculo',
                                style: _AppTextStyles.destructiveButton, // <-- CAMBIO DE UI
                              ),
                            ),
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
}

/////////////////////////////////////////////////////////

// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../../../../features/auth/presentation/provider/auth_provider.dart';
// import '../../../../features/auth/presentation/provider/auth_state.dart';
// import '../../../../features/auth/presentation/pages/auth_final_page.dart';
// import '../../../../notifications/notification_service.dart';
// import '../../../../core/widgets/quick_actions_config_widget.dart';

// // ===========================================================================
// // SECCIÓN DE DISEÑO: Colores y Estilos basados en la pantalla de referencia
// // ===========================================================================

// /// Paleta de colores extraída del diseño de la pantalla de referencia (InCircleView).
// class _AppColors {
//   static const Color background = Color(0xFF000000); // Negro puro
//   static const Color accent = Color(0xFF1EE9A4); // Verde menta/turquesa
//   static const Color textPrimary = Color(0xFFFFFFFF); // Blanco
//   static const Color textSecondary = Color(0xFF9E9E9E); // Gris para subtítulos y labels
//   static const Color cardBackground = Color(0xFF1C1C1E); // Gris oscuro para menús y diálogos
//   static const Color cardBorder = Color(0xFF3A3A3C); // Borde sutil para tarjetas y divider
//   static const Color sosRed = Color(0xFFD32F2F); // Rojo para alertas SOS
//   static const Color inputFill = Color(0xFF2C2C2E); // Relleno de inputs
// }

// /// Estilos de texto consistentes con el diseño de referencia.
// class _AppTextStyles {
//   static const TextStyle screenTitle = TextStyle(
//     fontSize: 20,
//     fontWeight: FontWeight.bold,
//     color: _AppColors.textPrimary,
//   );

//   static const TextStyle cardTitle = TextStyle(
//     fontSize: 18,
//     fontWeight: FontWeight.bold,
//     color: _AppColors.textPrimary,
//   );
  
//   static const TextStyle textBody = TextStyle(
//     fontSize: 14,
//     color: _AppColors.textSecondary,
//     fontWeight: FontWeight.normal,
//   );

//   static const TextStyle label = TextStyle(
//     fontSize: 14,
//     color: _AppColors.textSecondary,
//     fontWeight: FontWeight.w500,
//   );

//   static const TextStyle destructiveLabel = TextStyle(
//     fontSize: 16,
//     fontWeight: FontWeight.bold,
//     color: _AppColors.sosRed,
//   );

//   static const TextStyle destructiveButton = TextStyle(
//     fontSize: 16,
//     fontWeight: FontWeight.w600,
//     color: _AppColors.textPrimary,
//   );
// }


// /// Pantalla de configuración del usuario
// /// Permite cambiar nombre de usuario, nombre del círculo y salir del círculo
// class SettingsPage extends ConsumerStatefulWidget {
//   const SettingsPage({super.key});

//   @override
//   ConsumerState<SettingsPage> createState() => _SettingsPageState();
// }

// class _SettingsPageState extends ConsumerState<SettingsPage> {
//   // --- INICIO DE LÓGICA (SIN CAMBIOS) ---
//   final _userNameController = TextEditingController();
//   final _circleNameController = TextEditingController();
//   final _formKey = GlobalKey<FormState>();
  
//   bool _isLoading = false;
//   String? _userId;
//   String? _circleId;
//   String? _currentUserName; // nickname/displayName
//   String? _currentCircleName;
//   String? _userEmail; // email (solo lectura)

//   @override
//   void initState() {
//     super.initState();
//     debugPrint('[SettingsPage] 🔧 Inicializando pantalla de configuración');
//     _loadCurrentInfo();
//   }

//   @override
//   void dispose() {
//     _userNameController.dispose();
//     _circleNameController.dispose();
//     super.dispose();
//   }

//   /// Carga la información actual del usuario y círculo
//   void _loadCurrentInfo() async {
//     try {
//       final authState = ref.read(authProvider);
      
//       if (authState is Authenticated) {
//         _userId = authState.user.uid;
//         _userEmail = authState.user.email;
        
//         // Obtener nickname desde Firestore (NO desde email)
//         await _loadUserNickname();
        
//         debugPrint('[SettingsPage] 🔧 Usuario cargado: nickname=[$_currentUserName], email=[$_userEmail] (ID: $_userId)');
        
//         // Obtener información del círculo directamente de Firebase
//         await _loadCircleInfo();
//       }
//     } catch (e) {
//       debugPrint('[SettingsPage] ❌ Error cargando información: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('❌ Error cargando datos: ${e.toString()}'),
//             backgroundColor: _AppColors.sosRed, // <-- CAMBIO DE UI
//           ),
//         );
//       }
//     }
//   }

//   /// Carga el nickname del usuario desde Firestore
//   Future<void> _loadUserNickname() async {
//     if (_userId == null) return;
    
//     try {
//       final userDoc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(_userId)
//           .get();
      
//       if (userDoc.exists) {
//         final userData = userDoc.data()!;
//         // Prioridad: nickname > displayName > fallback al email split
//         _currentUserName = userData['nickname'] as String? ?? 
//                            userData['displayName'] as String? ?? 
//                            _userEmail?.split('@')[0] ?? 'Usuario';
        
//         if (mounted) {
//           setState(() {
//             _userNameController.text = _currentUserName ?? '';
//           });
//         }
        
//         debugPrint('[SettingsPage] 🔧 Nickname cargado: $_currentUserName');
//       }
//     } catch (e) {
//       debugPrint('[SettingsPage] ❌ Error cargando nickname: $e');
//     }
//   }

//   /// Carga información del círculo desde Firebase
//   Future<void> _loadCircleInfo() async {
//     if (_userId == null) return;
    
//     try {
//       // Buscar el círculo del usuario
//       final userDoc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(_userId)
//           .get();
      
//       if (userDoc.exists && userDoc.data()?['circleId'] != null) {
//         _circleId = userDoc.data()!['circleId'] as String;
        
//         // Obtener información del círculo
//         final circleDoc = await FirebaseFirestore.instance
//             .collection('circles')
//             .doc(_circleId)
//             .get();
        
//         if (circleDoc.exists) {
//           _currentCircleName = circleDoc.data()?['name'] as String?;
//           debugPrint('[SettingsPage] 🔧 Círculo cargado: $_currentCircleName (ID: $_circleId)');
//           if (mounted) {
//             setState(() {
//               _circleNameController.text = _currentCircleName ?? '';
//             });
//           }
//         }
//       }
//     } catch (e) {
//       debugPrint('[SettingsPage] Error cargando círculo: $e');
//     }
//   }

//   /// Actualiza el nickname del usuario (NO el email que es credencial de auth)
//   Future<void> _updateUserName() async {
//     if (_userId == null || _userNameController.text.trim().isEmpty) return;
    
//     setState(() => _isLoading = true);
    
//     try {
//       final newNickname = _userNameController.text.trim();
      
//       // CRÍTICO: Solo actualizar nickname/displayName, NUNCA el email
      
//       // 1. Actualizar en Firebase Auth displayName
//       await FirebaseAuth.instance.currentUser?.updateDisplayName(newNickname);
      
//       // 2. Actualizar nickname en Firestore (perfil del usuario)
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(_userId)
//           .update({
//             'nickname': newNickname,
//             'displayName': newNickname, // Mantener ambos por compatibilidad
//           });
      
//       // 3. Actualizar también en el documento del círculo si existe
//       if (_circleId != null) {
//         await FirebaseFirestore.instance
//             .collection('circles')
//             .doc(_circleId)
//             .collection('members')
//             .doc(_userId)
//             .update({
//               'nickname': newNickname,
//               'displayName': newNickname,
//             });
//       }
      
//       // 4. Actualizar variable local
//       _currentUserName = newNickname;
      
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('✅ Nickname actualizado correctamente'),
//             backgroundColor: Colors.green, // <-- CAMBIO DE UI (Se mantiene verde para éxito)
//           ),
//         );
//       }
      
//     } catch (e) {
//       debugPrint('[SettingsPage] Error actualizando nickname: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('❌ Error actualizando nickname: ${e.toString()}'),
//             backgroundColor: _AppColors.sosRed, // <-- CAMBIO DE UI
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   /// Actualiza el nombre del círculo
//   Future<void> _updateCircleName() async {
//     if (_circleId == null || _circleNameController.text.trim().isEmpty) return;
    
//     setState(() => _isLoading = true);
    
//     try {
//       final newName = _circleNameController.text.trim();
      
//       // Actualizar nombre del círculo en Firestore
//       await FirebaseFirestore.instance
//           .collection('circles')
//           .doc(_circleId)
//           .update({'name': newName});
      
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('✅ Nombre del círculo actualizado'),
//             backgroundColor: Colors.green, // <-- CAMBIO DE UI (Se mantiene verde para éxito)
//           ),
//         );
//       }
      
//     } catch (e) {
//       debugPrint('[SettingsPage] Error actualizando círculo: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('❌ Error: ${e.toString()}'),
//             backgroundColor: _AppColors.sosRed, // <-- CAMBIO DE UI
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   /// Muestra diálogo de confirmación para salir del círculo
//   void _showLeaveCircleDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: _AppColors.cardBackground, // <-- CAMBIO DE UI
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // <-- CAMBIO DE UI
//         title: Text(
//           'Salir del círculo',
//           style: _AppTextStyles.cardTitle.copyWith(color: _AppColors.sosRed), // <-- CAMBIO DE UI
//         ),
//         content: Text(
//           '¿Estás seguro de que quieres salir del círculo "${_currentCircleName ?? 'actual'}"?\n\nEsta acción no se puede deshacer.',
//           style: _AppTextStyles.textBody, // <-- CAMBIO DE UI
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text(
//               'Cancelar',
//               style: TextStyle(color: _AppColors.textSecondary), // <-- CAMBIO DE UI
//             ),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _leaveCircle();
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: _AppColors.sosRed, // <-- CAMBIO DE UI
//               foregroundColor: _AppColors.textPrimary, // <-- CAMBIO DE UI
//             ),
//             child: const Text('Salir del círculo'),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Sale del círculo actual
//   Future<void> _leaveCircle() async {
//     if (_userId == null || _circleId == null) return;
    
//     setState(() => _isLoading = true);
    
//     try {
//       // CRÍTICO: Cancelar notificaciones antes de salir del círculo
//       // Esto previene inconsistencias donde el usuario ya no está en el círculo
//       // pero las notificaciones permiten actualizaciones de estado inválidas
//       await NotificationService.cancelQuickActionNotification();
      
//       // Remover usuario del círculo
//       await FirebaseFirestore.instance
//           .collection('circles')
//           .doc(_circleId)
//           .collection('members')
//           .doc(_userId)
//           .delete();
      
//       // Actualizar el perfil del usuario para remover circleId
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(_userId)
//           .update({'circleId': FieldValue.delete()});
      
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('✅ Has salido del círculo'),
//             backgroundColor: Colors.green, // <-- CAMBIO DE UI (Se mantiene verde para éxito)
//           ),
//         );
        
//         // Navegar de vuelta a la pantalla principal
//         Navigator.of(context).pushAndRemoveUntil(
//           MaterialPageRoute(builder: (_) => const AuthFinalPage()),
//           (route) => false,
//         );
//       }
      
//     } catch (e) {
//       debugPrint('[SettingsPage] Error saliendo del círculo: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('❌ Error: ${e.toString()}'),
//             backgroundColor: _AppColors.sosRed, // <-- CAMBIO DE UI
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }
//   // --- FIN DE LÓGICA (SIN CAMBIOS) ---


//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _AppColors.background, // <-- CAMBIO DE UI
//       appBar: AppBar(
//         backgroundColor: _AppColors.background, // <-- CAMBIO DE UI
//         foregroundColor: _AppColors.textPrimary, // <-- CAMBIO DE UI
//         title: const Text(
//           'Configuración',
//           style: _AppTextStyles.screenTitle, // <-- CAMBIO DE UI
//         ),
//         elevation: 0,
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator(color: _AppColors.accent)) // <-- CAMBIO DE UI
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(16.0), // <-- CAMBIO DE UI
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     // Sección: Perfil del usuario
//                     _buildSectionCard(
//                       title: 'Tu perfil', // <-- CAMBIO DE UI (Emoji quitado)
//                       children: [
//                         // Email (solo lectura)
//                         const Text(
//                           'Email (no se puede cambiar)',
//                           style: _AppTextStyles.label, // <-- CAMBIO DE UI
//                         ),
//                         const SizedBox(height: 6),
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                           decoration: BoxDecoration(
//                             color: _AppColors.cardBackground, // <-- CAMBIO DE UI
//                             borderRadius: BorderRadius.circular(12),
//                             border: Border.all(color: _AppColors.cardBorder, width: 1), // <-- CAMBIO DE UI
//                           ),
//                           child: Row(
//                             children: [
//                               const Icon(Icons.email, color: _AppColors.textSecondary, size: 18), // <-- CAMBIO DE UI
//                               const SizedBox(width: 8),
//                               Expanded(
//                                 child: Text(
//                                   _userEmail ?? 'Cargando...',
//                                   style: _AppTextStyles.textBody, // <-- CAMBIO DE UI
//                                 ),
//                               ),
//                               Icon(Icons.lock, color: _AppColors.textSecondary, size: 16), // <-- CAMBIO DE UI
//                             ],
//                           ),
//                         ),
                        
//                         const SizedBox(height: 20),
                        
//                         // Nickname (editable)
//                         const Text(
//                           'Nickname',
//                           style: _AppTextStyles.label, // <-- CAMBIO DE UI
//                         ),
//                         const SizedBox(height: 8),
//                         TextFormField(
//                           controller: _userNameController,
//                           style: const TextStyle(color: _AppColors.textPrimary), // <-- CAMBIO DE UI
//                           decoration: InputDecoration(
//                             hintText: 'Ingresa tu nickname',
//                             hintStyle: const TextStyle(color: _AppColors.textSecondary), // <-- CAMBIO DE UI
//                             filled: true,
//                             fillColor: _AppColors.inputFill, // <-- CAMBIO DE UI
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(12),
//                               borderSide: BorderSide.none,
//                             ),
//                             prefixIcon: const Icon(Icons.person, color: _AppColors.textSecondary), // <-- CAMBIO DE UI
//                             suffixIcon: IconButton(
//                               onPressed: _updateUserName,
//                               icon: const Icon(
//                                 Icons.check,
//                                 color: _AppColors.accent, // <-- CAMBIO DE UI
//                               ),
//                               tooltip: 'Guardar nickname',
//                             ),
//                           ),
//                           validator: (value) {
//                             if (value?.trim().isEmpty ?? true) {
//                               return 'El nickname no puede estar vacío';
//                             }
//                             return null;
//                           },
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           'Este es el nombre que verán los miembros de tu círculo.',
//                           style: _AppTextStyles.textBody.copyWith(fontSize: 12), // <-- CAMBIO DE UI
//                         ),
//                       ],
//                     ),

//                     const SizedBox(height: 24),

//                     // Sección: Quick Actions (Point 14)
//                     const QuickActionsConfigWidget(),

//                     const SizedBox(height: 24),

//                     // Sección: Círculo
//                     if (_circleId != null) ...[
//                       _buildSectionCard(
//                         title: 'Círculo', // <-- CAMBIO DE UI (Emoji quitado)
//                         children: [
//                           const Text(
//                             'Nombre del círculo',
//                             style: _AppTextStyles.label, // <-- CAMBIO DE UI
//                           ),
//                           const SizedBox(height: 8),
//                           TextFormField(
//                             controller: _circleNameController,
//                             style: const TextStyle(color: _AppColors.textPrimary), // <-- CAMBIO DE UI
//                             decoration: InputDecoration(
//                               hintText: 'Nombre del círculo',
//                               hintStyle: const TextStyle(color: _AppColors.textSecondary), // <-- CAMBIO DE UI
//                               filled: true,
//                               fillColor: _AppColors.inputFill, // <-- CAMBIO DE UI
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                                 borderSide: BorderSide.none,
//                               ),
//                               suffixIcon: IconButton(
//                                 onPressed: _updateCircleName,
//                                 icon: const Icon(
//                                   Icons.check,
//                                   color: _AppColors.accent, // <-- CAMBIO DE UI
//                                 ),
//                               ),
//                             ),
//                             validator: (value) {
//                               if (value?.trim().isEmpty ?? true) {
//                                 return 'El nombre del círculo no puede estar vacío';
//                               }
//                               return null;
//                             },
//                           ),
//                           const SizedBox(height: 16),
//                           Text(
//                             'Cualquier miembro del círculo puede cambiar este nombre.',
//                             style: _AppTextStyles.textBody.copyWith(fontSize: 12), // <-- CAMBIO DE UI
//                           ),
//                         ],
//                       ),

//                       const SizedBox(height: 32),

//                       // Botón: Salir del círculo
//                       Container(
//                         padding: const EdgeInsets.all(20),
//                         decoration: BoxDecoration(
//                           color: _AppColors.sosRed.withOpacity(0.1), // <-- CAMBIO DE UI
//                           borderRadius: BorderRadius.circular(16),
//                           border: Border.all(
//                             color: _AppColors.sosRed.withOpacity(0.3), // <-- CAMBIO DE UI
//                             width: 1,
//                           ),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.stretch,
//                           children: [
//                             const Text(
//                               'Zona peligrosa',
//                               style: _AppTextStyles.destructiveLabel, // <-- CAMBIO DE UI
//                             ),
//                             const SizedBox(height: 12),
//                             const Text(
//                               'Una vez que salgas del círculo, tendrás que ser invitado nuevamente para volver a unirte.',
//                               style: _AppTextStyles.textBody, // <-- CAMBIO DE UI
//                             ),
//                             const SizedBox(height: 16),
//                             ElevatedButton.icon(
//                               onPressed: _showLeaveCircleDialog,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: _AppColors.sosRed, // <-- CAMBIO DE UI
//                                 foregroundColor: _AppColors.textPrimary, // <-- CAMBIO DE UI
//                                 padding: const EdgeInsets.symmetric(vertical: 16),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                               ),
//                               icon: const Icon(Icons.exit_to_app),
//                               label: const Text(
//                                 'Salir del círculo',
//                                 style: _AppTextStyles.destructiveButton, // <-- CAMBIO DE UI
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//     );
//   }

//   /// Construye una tarjeta de sección
//   Widget _buildSectionCard({
//     required String title,
//     required List<Widget> children,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: _AppColors.cardBackground, // <-- CAMBIO DE UI
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(
//           color: _AppColors.cardBorder, // <-- CAMBIO DE UI
//           width: 1,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: _AppTextStyles.cardTitle, // <-- CAMBIO DE UI
//           ),
//           const SizedBox(height: 16),
//           ...children,
//         ],
//       ),
//     );
//   }
// }


//////////////////////////////////////////////

// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../../../../features/auth/presentation/provider/auth_provider.dart';
// import '../../../../features/auth/presentation/provider/auth_state.dart';
// import '../../../../features/auth/presentation/pages/auth_final_page.dart';
// import '../../../../notifications/notification_service.dart';
// import '../../../../core/widgets/quick_actions_config_widget.dart';

// /// Pantalla de configuración del usuario
// /// Permite cambiar nombre de usuario, nombre del círculo y salir del círculo
// class SettingsPage extends ConsumerStatefulWidget {
//   const SettingsPage({super.key});

//   @override
//   ConsumerState<SettingsPage> createState() => _SettingsPageState();
// }

// class _SettingsPageState extends ConsumerState<SettingsPage> {
//   final _userNameController = TextEditingController();
//   final _circleNameController = TextEditingController();
//   final _formKey = GlobalKey<FormState>();
  
//   bool _isLoading = false;
//   String? _userId;
//   String? _circleId;
//   String? _currentUserName; // nickname/displayName
//   String? _currentCircleName;
//   String? _userEmail; // email (solo lectura)

//   @override
//   void initState() {
//     super.initState();
//     debugPrint('[SettingsPage] 🔧 Inicializando pantalla de configuración');
//     _loadCurrentInfo();
//   }

//   @override
//   void dispose() {
//     _userNameController.dispose();
//     _circleNameController.dispose();
//     super.dispose();
//   }

//   /// Carga la información actual del usuario y círculo
//   void _loadCurrentInfo() async {
//     try {
//       final authState = ref.read(authProvider);
      
//       if (authState is Authenticated) {
//         _userId = authState.user.uid;
//         _userEmail = authState.user.email;
        
//         // Obtener nickname desde Firestore (NO desde email)
//         await _loadUserNickname();
        
//         debugPrint('[SettingsPage] 🔧 Usuario cargado: nickname=[$_currentUserName], email=[$_userEmail] (ID: $_userId)');
        
//         // Obtener información del círculo directamente de Firebase
//         await _loadCircleInfo();
//       }
//     } catch (e) {
//       debugPrint('[SettingsPage] ❌ Error cargando información: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('❌ Error cargando datos: ${e.toString()}'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   /// Carga el nickname del usuario desde Firestore
//   Future<void> _loadUserNickname() async {
//     if (_userId == null) return;
    
//     try {
//       final userDoc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(_userId)
//           .get();
      
//       if (userDoc.exists) {
//         final userData = userDoc.data()!;
//         // Prioridad: nickname > displayName > fallback al email split
//         _currentUserName = userData['nickname'] as String? ?? 
//                           userData['displayName'] as String? ?? 
//                           _userEmail?.split('@')[0] ?? 'Usuario';
        
//         if (mounted) {
//           setState(() {
//             _userNameController.text = _currentUserName ?? '';
//           });
//         }
        
//         debugPrint('[SettingsPage] 🔧 Nickname cargado: $_currentUserName');
//       }
//     } catch (e) {
//       debugPrint('[SettingsPage] ❌ Error cargando nickname: $e');
//     }
//   }

//   /// Carga información del círculo desde Firebase
//   Future<void> _loadCircleInfo() async {
//     if (_userId == null) return;
    
//     try {
//       // Buscar el círculo del usuario
//       final userDoc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(_userId)
//           .get();
      
//       if (userDoc.exists && userDoc.data()?['circleId'] != null) {
//         _circleId = userDoc.data()!['circleId'] as String;
        
//         // Obtener información del círculo
//         final circleDoc = await FirebaseFirestore.instance
//             .collection('circles')
//             .doc(_circleId)
//             .get();
        
//         if (circleDoc.exists) {
//           _currentCircleName = circleDoc.data()?['name'] as String?;
//           debugPrint('[SettingsPage] 🔧 Círculo cargado: $_currentCircleName (ID: $_circleId)');
//           if (mounted) {
//             setState(() {
//               _circleNameController.text = _currentCircleName ?? '';
//             });
//           }
//         }
//       }
//     } catch (e) {
//       debugPrint('[SettingsPage] Error cargando círculo: $e');
//     }
//   }

//   /// Actualiza el nickname del usuario (NO el email que es credencial de auth)
//   Future<void> _updateUserName() async {
//     if (_userId == null || _userNameController.text.trim().isEmpty) return;
    
//     setState(() => _isLoading = true);
    
//     try {
//       final newNickname = _userNameController.text.trim();
      
//       // CRÍTICO: Solo actualizar nickname/displayName, NUNCA el email
      
//       // 1. Actualizar en Firebase Auth displayName
//       await FirebaseAuth.instance.currentUser?.updateDisplayName(newNickname);
      
//       // 2. Actualizar nickname en Firestore (perfil del usuario)
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(_userId)
//           .update({
//             'nickname': newNickname,
//             'displayName': newNickname, // Mantener ambos por compatibilidad
//           });
      
//       // 3. Actualizar también en el documento del círculo si existe
//       if (_circleId != null) {
//         await FirebaseFirestore.instance
//             .collection('circles')
//             .doc(_circleId)
//             .collection('members')
//             .doc(_userId)
//             .update({
//               'nickname': newNickname,
//               'displayName': newNickname,
//             });
//       }
      
//       // 4. Actualizar variable local
//       _currentUserName = newNickname;
      
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('✅ Nickname actualizado correctamente'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       }
      
//     } catch (e) {
//       debugPrint('[SettingsPage] Error actualizando nickname: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('❌ Error actualizando nickname: ${e.toString()}'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   /// Actualiza el nombre del círculo
//   Future<void> _updateCircleName() async {
//     if (_circleId == null || _circleNameController.text.trim().isEmpty) return;
    
//     setState(() => _isLoading = true);
    
//     try {
//       final newName = _circleNameController.text.trim();
      
//       // Actualizar nombre del círculo en Firestore
//       await FirebaseFirestore.instance
//           .collection('circles')
//           .doc(_circleId)
//           .update({'name': newName});
      
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('✅ Nombre del círculo actualizado'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       }
      
//     } catch (e) {
//       debugPrint('[SettingsPage] Error actualizando círculo: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('❌ Error: ${e.toString()}'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   /// Muestra diálogo de confirmación para salir del círculo
//   void _showLeaveCircleDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey[900],
//         title: const Text(
//           '⚠️ Salir del círculo',
//           style: TextStyle(color: Colors.white),
//         ),
//         content: Text(
//           '¿Estás seguro de que quieres salir del círculo "${_currentCircleName ?? 'actual'}"?\n\nEsta acción no se puede deshacer.',
//           style: TextStyle(color: Colors.grey[300]),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text(
//               'Cancelar',
//               style: TextStyle(color: Colors.grey[400]),
//             ),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _leaveCircle();
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.red,
//               foregroundColor: Colors.white,
//             ),
//             child: const Text('Salir del círculo'),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Sale del círculo actual
//   Future<void> _leaveCircle() async {
//     if (_userId == null || _circleId == null) return;
    
//     setState(() => _isLoading = true);
    
//     try {
//       // CRÍTICO: Cancelar notificaciones antes de salir del círculo
//       // Esto previene inconsistencias donde el usuario ya no está en el círculo
//       // pero las notificaciones permiten actualizaciones de estado inválidas
//       await NotificationService.cancelQuickActionNotification();
      
//       // Remover usuario del círculo
//       await FirebaseFirestore.instance
//           .collection('circles')
//           .doc(_circleId)
//           .collection('members')
//           .doc(_userId)
//           .delete();
      
//       // Actualizar el perfil del usuario para remover circleId
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(_userId)
//           .update({'circleId': FieldValue.delete()});
      
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('✅ Has salido del círculo'),
//             backgroundColor: Colors.green,
//           ),
//         );
        
//         // Navegar de vuelta a la pantalla principal
//         Navigator.of(context).pushAndRemoveUntil(
//           MaterialPageRoute(builder: (_) => const AuthFinalPage()),
//           (route) => false,
//         );
//       }
      
//     } catch (e) {
//       debugPrint('[SettingsPage] Error saliendo del círculo: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('❌ Error: ${e.toString()}'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: Colors.grey[900],
//         foregroundColor: Colors.white,
//         title: const Text('⚙️ Configuración'),
//         elevation: 0,
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(24),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     // Sección: Perfil del usuario
//                     _buildSectionCard(
//                       title: '👤 Tu perfil',
//                       children: [
//                         // Email (solo lectura)
//                         Text(
//                           'Email (no se puede cambiar)',
//                           style: TextStyle(
//                             color: Colors.grey[400],
//                             fontSize: 12,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                         const SizedBox(height: 6),
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                           decoration: BoxDecoration(
//                             color: Colors.grey[800]?.withOpacity(0.5),
//                             borderRadius: BorderRadius.circular(12),
//                             border: Border.all(color: Colors.grey[600]!, width: 1),
//                           ),
//                           child: Row(
//                             children: [
//                               Icon(Icons.email, color: Colors.grey[500], size: 18),
//                               const SizedBox(width: 8),
//                               Expanded(
//                                 child: Text(
//                                   _userEmail ?? 'Cargando...',
//                                   style: TextStyle(
//                                     color: Colors.grey[400],
//                                     fontSize: 14,
//                                   ),
//                                 ),
//                               ),
//                               Icon(Icons.lock, color: Colors.grey[600], size: 16),
//                             ],
//                           ),
//                         ),
                        
//                         const SizedBox(height: 20),
                        
//                         // Nickname (editable)
//                         Text(
//                           'Nickname',
//                           style: TextStyle(
//                             color: Colors.grey[300],
//                             fontSize: 14,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         TextFormField(
//                           controller: _userNameController,
//                           style: const TextStyle(color: Colors.white),
//                           decoration: InputDecoration(
//                             hintText: 'Ingresa tu nickname',
//                             hintStyle: TextStyle(color: Colors.grey[500]),
//                             filled: true,
//                             fillColor: Colors.grey[800],
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(12),
//                               borderSide: BorderSide.none,
//                             ),
//                             prefixIcon: Icon(Icons.person, color: Colors.grey[500]),
//                             suffixIcon: IconButton(
//                               onPressed: _updateUserName,
//                               icon: const Icon(
//                                 Icons.check,
//                                 color: Colors.green,
//                               ),
//                               tooltip: 'Guardar nickname',
//                             ),
//                           ),
//                           validator: (value) {
//                             if (value?.trim().isEmpty ?? true) {
//                               return 'El nickname no puede estar vacío';
//                             }
//                             return null;
//                           },
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           '💡 El nickname es cómo te verán otros miembros del círculo',
//                           style: TextStyle(
//                             color: Colors.grey[500],
//                             fontSize: 12,
//                           ),
//                         ),
//                       ],
//                     ),

//                     const SizedBox(height: 24),

//                     // Sección: Quick Actions (Point 14)
//                     const QuickActionsConfigWidget(),

//                     const SizedBox(height: 24),

//                     // Sección: Círculo
//                     if (_circleId != null) ...[
//                       _buildSectionCard(
//                         title: '🔗 Círculo',
//                         children: [
//                           Text(
//                             'Nombre del círculo',
//                             style: TextStyle(
//                               color: Colors.grey[300],
//                               fontSize: 14,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           TextFormField(
//                             controller: _circleNameController,
//                             style: const TextStyle(color: Colors.white),
//                             decoration: InputDecoration(
//                               hintText: 'Nombre del círculo',
//                               hintStyle: TextStyle(color: Colors.grey[500]),
//                               filled: true,
//                               fillColor: Colors.grey[800],
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                                 borderSide: BorderSide.none,
//                               ),
//                               suffixIcon: IconButton(
//                                 onPressed: _updateCircleName,
//                                 icon: const Icon(
//                                   Icons.check,
//                                   color: Colors.green,
//                                 ),
//                               ),
//                             ),
//                             validator: (value) {
//                               if (value?.trim().isEmpty ?? true) {
//                                 return 'El nombre del círculo no puede estar vacío';
//                               }
//                               return null;
//                             },
//                           ),
//                           const SizedBox(height: 16),
//                           Text(
//                             '💡 Cualquier miembro del círculo puede cambiar este nombre',
//                             style: TextStyle(
//                               color: Colors.grey[500],
//                               fontSize: 12,
//                             ),
//                           ),
//                         ],
//                       ),

//                       const SizedBox(height: 32),

//                       // Botón: Salir del círculo
//                       Container(
//                         padding: const EdgeInsets.all(20),
//                         decoration: BoxDecoration(
//                           color: Colors.red.withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(16),
//                           border: Border.all(
//                             color: Colors.red.withOpacity(0.3),
//                             width: 1,
//                           ),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.stretch,
//                           children: [
//                             Text(
//                               '⚠️ Zona peligrosa',
//                               style: TextStyle(
//                                 color: Colors.red[300],
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             const SizedBox(height: 12),
//                             Text(
//                               'Una vez que salgas del círculo, tendrás que ser invitado nuevamente para volver a unirte.',
//                               style: TextStyle(
//                                 color: Colors.grey[400],
//                                 fontSize: 14,
//                               ),
//                             ),
//                             const SizedBox(height: 16),
//                             ElevatedButton.icon(
//                               onPressed: _showLeaveCircleDialog,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.red,
//                                 foregroundColor: Colors.white,
//                                 padding: const EdgeInsets.symmetric(vertical: 16),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                               ),
//                               icon: const Icon(Icons.exit_to_app),
//                               label: const Text(
//                                 'Salir del círculo',
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//     );
//   }

//   /// Construye una tarjeta de sección
//   Widget _buildSectionCard({
//     required String title,
//     required List<Widget> children,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.grey[900],
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(
//           color: Colors.grey[700]!,
//           width: 1,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 16),
//           ...children,
//         ],
//       ),
//     );
//   }
// }