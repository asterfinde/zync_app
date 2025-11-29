import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/user_status.dart';
import '../core/services/status_service.dart';
import '../core/services/emoji_service.dart';
import '../features/settings/presentation/pages/settings_page.dart';

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

class _StatusSelectorOverlayState extends State<StatusSelectorOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _isUpdating = false;

  // Grid 4x4 cargado desde Firebase (16 emojis predefinidos)
  List<StatusType?> _statusGrid = [];

  // IDs del grid 4x4 en orden (null = botón especial)
  static const _gridIds = [
    // Fila 1: Disponibilidad
    'available', 'busy', 'away', 'do_not_disturb',
    // Fila 2: Ubicación
    'home', 'school', 'work', 'medical',
    // Fila 3: Actividad
    'meeting', 'studying', 'eating', 'exercising',
    // Fila 4: Transporte + SOS
    'driving', 'walking', 'public_transport', 'sos',
  ];

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
      final emojis = await EmojiService.getPredefinedEmojis();
      log('[StatusSelectorOverlay] ✅ Recibidos ${emojis.length} emojis: ${emojis.map((e) => e.emoji).join(", ")}');

      final grid = <StatusType?>[];

      for (final id in _gridIds) {
        final status = emojis.firstWhere(
          (e) => e.id == id,
          orElse: () => StatusType.fallbackPredefined.first,
        );
        grid.add(status);
      }

      log('[StatusSelectorOverlay] ✅ Grid construido con ${grid.length} emojis');

      if (mounted) {
        setState(() => _statusGrid = grid);
      }
    } catch (e) {
      log('[StatusSelectorOverlay] ❌ ERROR cargando grid: $e');
      if (mounted) {
        setState(() =>
            _statusGrid = StatusType.fallbackPredefined.take(16).toList());
      }
    }
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

    setState(() => _isUpdating = true);

    try {
      // Haptic feedback
      HapticFeedback.lightImpact();

      // Usar el StatusService existente - ¡Sin romper nada!
      final result = await StatusService.updateUserStatus(status);

      if (result.isSuccess) {
        log('[StatusSelectorOverlay] Estado actualizado: ${status.description}');

        // Mostrar feedback visual rápido
        _showSuccessFeedback(status);

        // Cerrar modal después de un breve delay
        await Future.delayed(const Duration(milliseconds: 800));
        _closeModal();
      } else {
        _showErrorFeedback(result.errorMessage ?? 'Error desconocido');
      }
    } catch (e) {
      log('[StatusSelectorOverlay] Error: $e');
      _showErrorFeedback(e.toString());
    } finally {
      if (mounted) {
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
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
      widget.onClose?.call();
    }
  }

  /// Maneja tap en configuración (gear emoji)
  void _handleConfigTap() async {
    HapticFeedback.lightImpact();
    log('[StatusSelectorOverlay] 🔧 TAP EN CONFIGURACIÓN - Cerrando modal y navegando');

    // CRÍTICO: Cerrar modal COMPLETAMENTE antes de navegar
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop(); // Cerrar modal
      widget.onClose?.call();

      // Esperar un frame para asegurar que el modal se cerró
      await Future.delayed(const Duration(milliseconds: 50));

      // Ahora sí navegar a configuración
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const SettingsPage(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return GestureDetector(
          onTap: _closeModal, // Cerrar tocando fuera del modal
          child: Container(
            color: Colors.black.withOpacity(0.85 * _fadeAnimation.value),
            child: Center(
              child: GestureDetector(
                onTap:
                    () {}, // Evitar que el tap se propague al contenedor padre
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900
                          .withOpacity(0.95), // Fondo oscuro transparente
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.grey.shade700
                            .withOpacity(0.5), // Borde sutil
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
                        // Grid 3x4 de estados con altura fija
                        SizedBox(
                          height:
                              280, // Altura aumentada para mostrar última fila completa
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1,
                            ),
                            itemCount: 16, // 4x4 grid
                            itemBuilder: (context, index) {
                              final gridItem = _statusGrid[index];

                              // Si es un estado válido, mostrar botón de estado
                              if (gridItem != null) {
                                return _buildStatusButton(gridItem);
                              }

                              // Posición 12 (primera de la última fila) es configuración
                              if (index == 12) {
                                return _buildConfigButton();
                              }

                              // Resto son espacios vacíos (posiciones 13, 14)
                              return const SizedBox.shrink();
                            },
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isUpdating ? null : () => _handleStatusSelection(status),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: _isUpdating
                ? Colors.grey.shade800.withOpacity(0.3)
                : Colors.grey.shade800
                    .withOpacity(0.6), // Fondo oscuro transparente
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
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  status.shortDescription,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.8),
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

  /// Construye botón de configuración
  Widget _buildConfigButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleConfigTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade900
                .withOpacity(0.6), // Azul oscuro transparente
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.shade400.withOpacity(0.5), // Borde azul sutil
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '⚙️',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 2),
              Text(
                'Config',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.blue.shade200,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
