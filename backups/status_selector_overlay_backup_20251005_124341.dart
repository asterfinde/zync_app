import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../features/circle/domain_old/entities/user_status.dart';
import '../core/services/status_service.dart';

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

  // Grid 3x4 de estados disponibles + configuración
  final List<StatusType?> _statusGrid = [
    // Fila 1: Estados básicos
    StatusType.fine, StatusType.sos, StatusType.meeting, StatusType.ready,
    // Fila 2: Estados emocionales  
    StatusType.happy, StatusType.sad, StatusType.excited, StatusType.worried,
    // Fila 3: Estados de actividad
    StatusType.busy, StatusType.sleepy, StatusType.thinking, StatusType.leave,
    // Fila 4: Configuración + espacios vacíos
    null, null, null, null, // null representa el botón de configuración o espacios vacíos
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _animationController.forward();
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

  /// Muestra feedback de éxito
  void _showSuccessFeedback(StatusType status) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${status.emoji} Estado actualizado'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Muestra feedback de error
  void _showErrorFeedback(String error) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $error'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
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
  void _handleConfigTap() {
    HapticFeedback.lightImpact();
    // TODO: Abrir pantalla de configuraciones
    log('[StatusSelectorOverlay] Config tap - TODO: Implementar configuraciones');
    _closeModal();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          color: Colors.black.withOpacity(0.7 * _fadeAnimation.value),
          child: Center(
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Título
                    const Text(
                      'Cambiar Estado',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Grid 3x4 de estados
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: 16, // 4x4 grid
                      itemBuilder: (context, index) {
                        // Primeros 12 elementos son estados
                        if (index < 12) {
                          final status = _statusGrid[index];
                          if (status != null) {
                            return _buildStatusButton(status);
                          }
                        }
                        
                        // Posición 12 (primera de la última fila) es configuración
                        if (index == 12) {
                          return _buildConfigButton();
                        }
                        
                        // Resto son espacios vacíos
                        return const SizedBox.shrink();
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Botón cerrar
                    TextButton(
                      onPressed: _closeModal,
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
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
            color: _isUpdating ? Colors.grey.shade200 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status.emoji,
                style: const TextStyle(fontSize: 24), // Reducido de 28 a 24
              ),
              const SizedBox(height: 2), // Reducido de 4 a 2
              Flexible(
                child: Text(
                  status.shortDescription,
                  style: TextStyle(
                    fontSize: 9, // Reducido de 10 a 9
                    color: Colors.grey.shade700,
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
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.shade200,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '⚙️',
                style: TextStyle(fontSize: 28),
              ),
              const SizedBox(height: 4),
              Text(
                'Config',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Método estático para mostrar el overlay
  static Future<void> show(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent, // Transparente para permitir tap fuera
      builder: (BuildContext context) {
        return const StatusSelectorOverlay();
      },
    );
  }
}