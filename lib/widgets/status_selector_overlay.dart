import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/user_status.dart';
import '../core/services/status_service.dart';

/// Modal transparente con grid 3x4 de emojis para selección rápida de estado
/// Reutiliza el StatusService existente sin romper nada
class StatusSelectorOverlay extends StatefulWidget {
  final VoidCallback? onClose;

  const StatusSelectorOverlay({
    super.key,
    this.onClose,
  });

  @override
  State<StatusSelectorOverlay> createState() => _StatusSelectorOverlayState();
}

class _StatusSelectorOverlayState extends State<StatusSelectorOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _isUpdating = false;

  // Grid dinámico cargado desde Firebase (predefinidos + personalizados)
  // HOTFIX: Inicializar con fallbackPredefined INMEDIATAMENTE para evitar timing issues
  List<StatusType?> _statusGrid = StatusType.fallbackPredefined;

  bool _zonesConfigured = false;
  bool _isLoadingGrid = true; // NUEVO: Prevenir render antes de cargar zonas

  static const Set<String> _blockedZoneStatusIds = {
    'home',
    'school',
    'work',
    'medical', // Usar 'medical' (🏥) en lugar de 'university'
  };

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadStatusGrid(); // Cargar grid de forma asíncrona
    // CRÍTICO: NO iniciar animación hasta que el grid esté cargado
    // Esto previene que se muestre el modal vacío o incompleto
    _waitForGridThenAnimate();
  }

  /// Espera a que el grid se cargue antes de animar
  Future<void> _waitForGridThenAnimate() async {
    // Esperar hasta que el grid esté cargado
    while (_isLoadingGrid && mounted) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (mounted) {
      _animationController.forward();
      print('[StatusSelectorOverlay] ✅ Animación iniciada después de cargar grid');
    }
  }

  Future<void> _loadStatusGrid() async {
    try {
      print('[StatusSelectorOverlay] 📡 Cargando grid desde EmojiService...');

      // Obtener circleId del usuario actual
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      final circleId = userDoc.data()?['circleId'] as String?;
      if (circleId == null) throw Exception('Usuario sin círculo');

      // PM5 FIX: Verificar si hay zonas predefinidas configuradas (home, school, work, medical)
      // Buscar zonas con type en ['home', 'school', 'work', 'medical']
      final zonesSnapshot =
          await FirebaseFirestore.instance.collection('circles').doc(circleId).collection('zones').get();

      // Filtrar zonas que sean de tipo predefinido
      final predefinedZones = zonesSnapshot.docs.where((doc) {
        final type = doc.data()['type'] as String?;
        return type != null && ['home', 'school', 'work', 'medical'].contains(type);
      }).toList();

      final hasZones = predefinedZones.isNotEmpty;
      print(
          '[StatusSelectorOverlay] 📍 Zonas predefinidas configuradas: $hasZones (${predefinedZones.length} zonas de ${zonesSnapshot.docs.length} totales)');

      // PM5 FIX: USAR DIRECTAMENTE fallbackPredefined para evitar emojis viejos de Firebase
      // Firebase tiene emojis legacy (como 'available' 🟢) que no deben aparecer
      // HOTFIX CRÍTICO: Ya no construir grid, usar el que ya está inicializado
      print('[StatusSelectorOverlay] ✅ Grid ya inicializado con ${_statusGrid.length} emojis');
      print('[StatusSelectorOverlay] 📋 Emojis: ${_statusGrid.map((e) => e?.emoji ?? "null").join(", ")}');
      print('[StatusSelectorOverlay] 📋 IDs: ${_statusGrid.map((e) => e?.id ?? "null").join(", ")}');

      // CRÍTICO: Dar un pequeño delay para asegurar que todo esté sincronizado
      // Esto es especialmente importante cuando se abre desde notificaciones
      await Future.delayed(const Duration(milliseconds: 50));

      if (mounted) {
        setState(() {
          // Grid ya está inicializado, solo actualizar zonas
          _zonesConfigured = hasZones; // PM5 FIX: Actualizar estado de zonas
          _isLoadingGrid = false; // CRÍTICO: Marcar como cargado
        });
        print(
            '[StatusSelectorOverlay] 🔧 Estado actualizado: _zonesConfigured=$_zonesConfigured, grid.length=${_statusGrid.length}, _isLoadingGrid=false');
        print('[StatusSelectorOverlay] 🎨 Opacidad aplicada a zonas: ${_zonesConfigured ? 'SÍ' : 'NO'}');

        // CRÍTICO: Forzar rebuild adicional después de setState para asegurar que la opacidad se aplique
        // Esto es necesario cuando el modal se abre desde notificaciones
        // Aumentamos el delay a 300ms para dar más tiempo
        if (hasZones) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                // Forzar reconstrucción del widget tree
                _zonesConfigured = hasZones; // Reafirmar el valor
                print(
                    '[StatusSelectorOverlay] 🔄 Forzando rebuild para aplicar opacidad (zonas configuradas=$_zonesConfigured)');
              });
            }
          });
        }
      }
    } catch (e) {
      print('[StatusSelectorOverlay] ❌ ERROR cargando grid: $e');
      if (mounted) {
        setState(() {
          _statusGrid = StatusType.fallbackPredefined;
          _zonesConfigured = false; // PM5 FIX: Sin zonas en caso de error
          _isLoadingGrid = false; // Marcar como cargado incluso en error
        });
      }
    }
  }

  Future<void> _showZoneSelectionNotAllowedModal() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.grey.shade300.withOpacity(0.92),
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Acción no permitida',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No puedes seleccionar zonas manualmente. El estado de zonas se actualiza automáticamente por geofencing.',
                  style: TextStyle(fontSize: 14, color: Colors.black),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Maneja la selección de estado reutilizando StatusService existente
  Future<void> _handleStatusSelection(StatusType status) async {
    if (_isUpdating) return;

    if (_zonesConfigured && _blockedZoneStatusIds.contains(status.id)) {
      await _showZoneSelectionNotAllowedModal();
      return;
    }

    setState(() => _isUpdating = true);

    try {
      // Haptic feedback
      HapticFeedback.lightImpact();

      print('[StatusSelectorOverlay] 🎯 Iniciando actualización de estado: ${status.description}');

      // Usar el StatusService existente - ¡Sin romper nada!
      final result = await StatusService.updateUserStatus(status);

      print(
          '[StatusSelectorOverlay] 📦 Resultado de actualización: isSuccess=${result.isSuccess}, error=${result.errorMessage}');

      if (result.isSuccess) {
        print('[StatusSelectorOverlay] ✅ Estado actualizado exitosamente: ${status.description}');

        // Mostrar feedback visual rápido
        _showSuccessFeedback(status);

        // PM2 FIX: Cerrar modal inmediatamente después de seleccionar emoji
        print('[StatusSelectorOverlay] 🚪 Iniciando cierre automático del modal...');
        await Future.delayed(const Duration(milliseconds: 300));

        print('[StatusSelectorOverlay] 🚪 Ejecutando _closeModal()...');
        await _closeModal();
        print('[StatusSelectorOverlay] ✅ Modal cerrado exitosamente');
      } else {
        print('[StatusSelectorOverlay] ⚠️ Actualización falló: ${result.errorMessage}');
        if (result.errorMessage == 'zone_manual_selection_not_allowed') {
          await _showZoneSelectionNotAllowedModal();
        } else {
          _showErrorFeedback(result.errorMessage ?? 'Error desconocido');
        }
      }
    } catch (e) {
      print('[StatusSelectorOverlay] ❌ Excepción durante actualización: $e');
      _showErrorFeedback(e.toString());
    } finally {
      if (mounted) {
        print('[StatusSelectorOverlay] 🔄 Finalizando actualización, reseteando _isUpdating');
        setState(() => _isUpdating = false);
      }
    }
  }

  /// Muestra feedback de éxito (SILENCIOSO - Point 15)
  void _showSuccessFeedback(StatusType status) {
    if (!mounted) return;

    // Point 15: Eliminar SnackBar para comportamiento silencioso
    print('[StatusSelectorOverlay] ✅ Estado actualizado silenciosamente: ${status.emoji}');

    // Solo mostrar feedback háptico
    HapticFeedback.lightImpact();
  }

  /// Muestra feedback de error (SILENCIOSO - Point 15)
  void _showErrorFeedback(String error) {
    if (!mounted) return;

    // Point 15: Solo log para errores, sin SnackBar
    print('[StatusSelectorOverlay] ❌ Error silencioso: $error');

    // Feedback háptico de error
    HapticFeedback.heavyImpact();
  }

  /// Cierra el modal con animación
  Future<void> _closeModal() async {
    print('[StatusSelectorOverlay] 🚪 _closeModal() llamado, iniciando animación de cierre...');
    try {
      await _animationController.reverse();
      print('[StatusSelectorOverlay] ✅ Animación de cierre completada');

      if (mounted) {
        print('[StatusSelectorOverlay] 🚪 Widget mounted, ejecutando Navigator.pop()...');
        Navigator.of(context).pop();
        print('[StatusSelectorOverlay] ✅ Navigator.pop() ejecutado');

        widget.onClose?.call();
        print('[StatusSelectorOverlay] ✅ Callback onClose ejecutado');
      } else {
        print('[StatusSelectorOverlay] ⚠️ Widget no mounted, no se puede cerrar');
      }
    } catch (e) {
      print('[StatusSelectorOverlay] ❌ Error durante cierre: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // PM1 FIX: Calcular tamaños responsive para uniformidad entre pantallas
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Usar porcentajes para tamaño responsive
    final modalMargin = screenWidth * 0.08; // 8% del ancho de pantalla
    final maxGridHeight = screenHeight * 0.55; // 55% de la altura de pantalla

    print(
        '[StatusSelectorOverlay] 📐 Screen: ${screenWidth}x$screenHeight, margin: $modalMargin, maxHeight: $maxGridHeight');

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return GestureDetector(
          onTap: _closeModal, // Cerrar tocando fuera del modal
          child: Container(
            color: Colors.black.withOpacity(0.85 * _fadeAnimation.value),
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Evitar que el tap se propague al contenedor padre
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    // PM1 FIX: Margen responsive en lugar de fijo
                    margin: EdgeInsets.all(modalMargin),
                    padding: const EdgeInsets.all(12), // PM5 FIX: Reducido de 20 a 12 para emojis más grandes
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900.withOpacity(0.95), // Fondo oscuro transparente
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.grey.shade700.withOpacity(0.5), // Borde sutil
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Grid DINÁMICO scrollable con altura máxima RESPONSIVE
                        _isLoadingGrid
                            ? SizedBox(
                                height: maxGridHeight,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF1EE9A4),
                                  ),
                                ),
                              )
                            : ConstrainedBox(
                                constraints: BoxConstraints(
                                  // PM1 FIX: Altura responsive en lugar de fija
                                  maxHeight: maxGridHeight,
                                ),
                                child: Scrollbar(
                                  thumbVisibility: true, // Barra de scroll siempre visible
                                  thickness: 4,
                                  radius: const Radius.circular(8),
                                  child: GridView.builder(
                                    shrinkWrap: true, // CRÍTICO: Permite que el GridView se ajuste al contenido
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding:
                                        const EdgeInsets.all(8), // PM5 FIX: Reducido de 16 a 8 para emojis más grandes
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 8, // PM5 FIX: Reducido de 10 a 8
                                      mainAxisSpacing: 8, // PM5 FIX: Reducido de 10 a 8
                                      childAspectRatio: 1,
                                    ),
                                    itemCount: _statusGrid.length,
                                    itemBuilder: (context, index) {
                                      // Validar que tenemos suficientes items en el grid
                                      if (_statusGrid.isEmpty || index >= _statusGrid.length) {
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF1EE9A4),
                                            strokeWidth: 2,
                                          ),
                                        );
                                      }

                                      final gridItem = _statusGrid[index];

                                      // Mostrar todos los emojis
                                      if (gridItem != null) {
                                        return _buildStatusButton(gridItem);
                                      }

                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Construye botón de estado individual
  Widget _buildStatusButton(StatusType status) {
    final isBlockedZone = _zonesConfigured && _blockedZoneStatusIds.contains(status.id);

    // DIAGNÓSTICO: Log para TODAS las zonas, no solo las bloqueadas
    if (_blockedZoneStatusIds.contains(status.id)) {
      print(
          '[StatusSelectorOverlay] 🔍 Zona ${status.id} (${status.emoji}): _zonesConfigured=$_zonesConfigured, isBlockedZone=$isBlockedZone, opacidad=${isBlockedZone ? '0.35' : '1.0'}');
    }

    // Log adicional para verificar que se está aplicando la opacidad
    if (isBlockedZone) {
      print('[StatusSelectorOverlay] 🎨 ✅ APLICANDO OPACIDAD 0.35 a ${status.id} (${status.emoji})');
    } else if (_blockedZoneStatusIds.contains(status.id)) {
      print(
          '[StatusSelectorOverlay] ⚠️ NO aplicando opacidad a ${status.id} (${status.emoji}) - _zonesConfigured=$_zonesConfigured');
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isUpdating ? null : () => _handleStatusSelection(status),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: (_isUpdating || isBlockedZone)
                ? Colors.grey.shade800.withOpacity(0.3)
                : Colors.grey.shade800.withOpacity(0.6), // Fondo oscuro transparente
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade600.withOpacity(0.4), // Borde sutil
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: isBlockedZone ? 0.35 : 1.0,
                child: Text(
                  status.emoji,
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Opacity(
                  opacity: isBlockedZone ? 0.35 : 0.8,
                  child: Text(
                    status.shortDescription,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
