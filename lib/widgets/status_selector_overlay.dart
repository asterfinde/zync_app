import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/user_status.dart';
import '../core/services/status_service.dart';
import '../core/services/emoji_service.dart';

import 'dart:developer';

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
  List<StatusType?> _statusGrid = [];

  bool _zonesConfigured = false;

  static const Set<String> _blockedZoneStatusIds = {
    'home',
    'school',
    'work',
    'university',
  };

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadStatusGrid();
    _animationController.forward();
  }

  Future<void> _loadStatusGrid() async {
    try {
      log('[StatusSelectorOverlay] 📡 Cargando grid desde EmojiService...');

      // Obtener circleId del usuario actual
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      final circleId = userDoc.data()?['circleId'] as String?;
      if (circleId == null) throw Exception('Usuario sin círculo');

      final zonesSnapshot =
          await FirebaseFirestore.instance.collection('circles').doc(circleId).collection('zones').limit(1).get();
      _zonesConfigured = zonesSnapshot.docs.isNotEmpty;

      // PM5 FIX: Cargar solo los 16 emojis predefinidos (sin custom)
      final emojis = await EmojiService.getPredefinedEmojis();
      log('[StatusSelectorOverlay] ✅ Recibidos ${emojis.length} emojis predefinidos: ${emojis.map((e) => e.emoji).join(", ")}');

      // PM5 FIX: Filtrar estados legacy y validar que sean los 16 correctos
      final validIds = [
        'fine', 'busy', 'away', 'do_not_disturb', // FILA 1
        'home', 'school', 'work', 'medical', // FILA 2
        'meeting', 'studying', 'eating', 'exercising', // FILA 3
        'driving', 'walking', 'public_transport', 'sos' // FILA 4
      ];

      final grid = emojis.where((e) => validIds.contains(e.id)).take(16).toList();

      // Si Firebase tiene menos de 16, completar con fallback
      if (grid.length < 16) {
        log('[StatusSelectorOverlay] ⚠️ Solo ${grid.length}/16 emojis válidos, completando con fallback');
        final fallbackGrid = StatusType.fallbackPredefined;
        for (final fallbackStatus in fallbackGrid) {
          if (!grid.any((s) => s.id == fallbackStatus.id)) {
            grid.add(fallbackStatus);
          }
          if (grid.length >= 16) break;
        }
      }

      // Ordenar por 'order' para mantener consistencia
      grid.sort((a, b) => a.order.compareTo(b.order));

      log('[StatusSelectorOverlay] ✅ Grid construido con ${grid.length} emojis válidos');

      if (mounted) {
        setState(() => _statusGrid = grid);
      }
    } catch (e) {
      log('[StatusSelectorOverlay] ❌ ERROR cargando grid: $e');
      if (mounted) {
        // PM5 FIX: Garantizar siempre los 16 estados correctos
        setState(() => _statusGrid = StatusType.fallbackPredefined);
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

      log('[StatusSelectorOverlay] 🎯 Iniciando actualización de estado: ${status.description}');

      // Usar el StatusService existente - ¡Sin romper nada!
      final result = await StatusService.updateUserStatus(status);

      log('[StatusSelectorOverlay] 📦 Resultado de actualización: isSuccess=${result.isSuccess}, error=${result.errorMessage}');

      if (result.isSuccess) {
        log('[StatusSelectorOverlay] ✅ Estado actualizado exitosamente: ${status.description}');

        // Mostrar feedback visual rápido
        _showSuccessFeedback(status);

        // PM2 FIX: Cerrar modal inmediatamente después de seleccionar emoji
        log('[StatusSelectorOverlay] 🚪 Iniciando cierre automático del modal...');
        await Future.delayed(const Duration(milliseconds: 300));

        log('[StatusSelectorOverlay] 🚪 Ejecutando _closeModal()...');
        await _closeModal();
        log('[StatusSelectorOverlay] ✅ Modal cerrado exitosamente');
      } else {
        log('[StatusSelectorOverlay] ⚠️ Actualización falló: ${result.errorMessage}');
        if (result.errorMessage == 'zone_manual_selection_not_allowed') {
          await _showZoneSelectionNotAllowedModal();
        } else {
          _showErrorFeedback(result.errorMessage ?? 'Error desconocido');
        }
      }
    } catch (e) {
      log('[StatusSelectorOverlay] ❌ Excepción durante actualización: $e');
      _showErrorFeedback(e.toString());
    } finally {
      if (mounted) {
        log('[StatusSelectorOverlay] 🔄 Finalizando actualización, reseteando _isUpdating');
        setState(() => _isUpdating = false);
      }
    }
  }

  /// Muestra feedback de éxito (SILENCIOSO - Point 15)
  void _showSuccessFeedback(StatusType status) {
    if (!mounted) return;

    // Point 15: Eliminar SnackBar para comportamiento silencioso
    log('[StatusSelectorOverlay] ✅ Estado actualizado silenciosamente: ${status.emoji}');

    // Solo mostrar feedback háptico
    HapticFeedback.lightImpact();
  }

  /// Muestra feedback de error (SILENCIOSO - Point 15)
  void _showErrorFeedback(String error) {
    if (!mounted) return;

    // Point 15: Solo log para errores, sin SnackBar
    log('[StatusSelectorOverlay] ❌ Error silencioso: $error');

    // Feedback háptico de error
    HapticFeedback.heavyImpact();
  }

  /// Cierra el modal con animación
  Future<void> _closeModal() async {
    log('[StatusSelectorOverlay] 🚪 _closeModal() llamado, iniciando animación de cierre...');
    try {
      await _animationController.reverse();
      log('[StatusSelectorOverlay] ✅ Animación de cierre completada');

      if (mounted) {
        log('[StatusSelectorOverlay] 🚪 Widget mounted, ejecutando Navigator.pop()...');
        Navigator.of(context).pop();
        log('[StatusSelectorOverlay] ✅ Navigator.pop() ejecutado');

        widget.onClose?.call();
        log('[StatusSelectorOverlay] ✅ Callback onClose ejecutado');
      } else {
        log('[StatusSelectorOverlay] ⚠️ Widget no mounted, no se puede cerrar');
      }
    } catch (e) {
      log('[StatusSelectorOverlay] ❌ Error durante cierre: $e');
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

    log('[StatusSelectorOverlay] 📐 Screen: ${screenWidth}x$screenHeight, margin: $modalMargin, maxHeight: $maxGridHeight');

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
                        ConstrainedBox(
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
                              padding: const EdgeInsets.all(8), // PM5 FIX: Reducido de 16 a 8 para emojis más grandes
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
              Text(
                status.emoji,
                style: TextStyle(
                  fontSize: 24,
                  color: isBlockedZone ? Colors.white.withOpacity(0.35) : Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  status.shortDescription,
                  style: TextStyle(
                    fontSize: 9,
                    color: isBlockedZone ? Colors.white.withOpacity(0.35) : Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
