import 'dart:async';
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

  // Solo los tipos de zona que el usuario configuró geográficamente.
  // Únicamente esos botones se inhabilitan en el selector.
  Set<String> _configuredZoneTypes = {};
  bool _isLoadingGrid = true; // NUEVO: Prevenir render antes de cargar zonas

  // SOS press & hold
  Timer? _sosTimer;
  double _sosHoldProgress = 0.0;
  bool _sosHolding = false;

  // Grid sin SOS (SOS va en botón separado)
  List<StatusType?> get _displayGrid => _statusGrid.where((s) => s?.id != 'sos').toList();

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
        return type != null && ['home', 'school', 'university', 'work'].contains(type);
      }).toList();

      // Recopilar los tipos de zona efectivamente configurados
      final configuredTypes = predefinedZones
          .map((doc) => doc.data()['type'] as String)
          .toSet();
      print(
          '[StatusSelectorOverlay] 📍 Tipos de zona configurados: $configuredTypes (${predefinedZones.length} de ${zonesSnapshot.docs.length} totales)');

      print('[StatusSelectorOverlay] ✅ Grid ya inicializado con ${_statusGrid.length} emojis');

      await Future.delayed(const Duration(milliseconds: 50));

      if (mounted) {
        setState(() {
          _configuredZoneTypes = configuredTypes;
          _isLoadingGrid = false;
        });
        print(
            '[StatusSelectorOverlay] 🔧 Estado actualizado: _configuredZoneTypes=$_configuredZoneTypes, grid.length=${_statusGrid.length}');

        if (configuredTypes.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() {});
          });
        }
      }
    } catch (e) {
      print('[StatusSelectorOverlay] ❌ ERROR cargando grid: $e');
      if (mounted) {
        setState(() {
          _statusGrid = StatusType.fallbackPredefined;
          _configuredZoneTypes = {};
          _isLoadingGrid = false;
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
    _sosTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startSosHold() {
    if (_isUpdating) return;
    setState(() {
      _sosHolding = true;
      _sosHoldProgress = 0.0;
    });
    _sosTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _sosHoldProgress += 30 / 1000);
      if (_sosHoldProgress >= 1.0) {
        timer.cancel();
        _triggerSos();
      }
    });
  }

  void _cancelSosHold() {
    _sosTimer?.cancel();
    _sosTimer = null;
    if (mounted) {
      setState(() {
        _sosHolding = false;
        _sosHoldProgress = 0.0;
      });
    }
  }

  Future<void> _triggerSos() async {
    final sos = StatusType.fallbackPredefined.firstWhere((s) => s.id == 'sos');
    _cancelSosHold();
    await _handleStatusSelection(sos);
  }

  Widget _buildSosButton() {
    return GestureDetector(
      onTapDown: (_) => _startSosHold(),
      onTapUp: (_) => _cancelSosHold(),
      onTapCancel: _cancelSosHold,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_sosHolding)
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  value: _sosHoldProgress,
                  color: Colors.white,
                  strokeWidth: 3,
                  backgroundColor: Colors.red.shade700,
                ),
              )
            else
              const Text(
                'S.O.S',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  decoration: TextDecoration.none,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _sosHolding ? 'Enviando SOS...' : 'Mantén presionado para enviar',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Maneja la selección de estado reutilizando StatusService existente
  Future<void> _handleStatusSelection(StatusType status) async {
    if (_isUpdating) return;

    if (_configuredZoneTypes.contains(status.id)) {
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
                                    itemCount: _displayGrid.length,
                                    itemBuilder: (context, index) {
                                      if (_displayGrid.isEmpty || index >= _displayGrid.length) {
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF1EE9A4),
                                            strokeWidth: 2,
                                          ),
                                        );
                                      }

                                      final gridItem = _displayGrid[index];

                                      if (gridItem != null) {
                                        return _buildStatusButton(gridItem);
                                      }

                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                        _buildSosButton(),
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
    final isBlockedZone = _configuredZoneTypes.contains(status.id);

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
