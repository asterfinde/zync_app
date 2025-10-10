import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/circle/domain_old/entities/user_status.dart';
import '../../core/services/quick_actions_preferences_service.dart';
import '../../quick_actions/quick_actions_service.dart';

/// Widget para configurar las Quick Actions del usuario (Point 14)
/// Permite seleccionar 4 emojis favoritos de los 16 disponibles
class QuickActionsConfigWidget extends StatefulWidget {
  const QuickActionsConfigWidget({super.key});

  @override
  State<QuickActionsConfigWidget> createState() => _QuickActionsConfigWidgetState();
}

class _QuickActionsConfigWidgetState extends State<QuickActionsConfigWidget> {
  List<StatusType> _selectedQuickActions = [];
  List<StatusType> _availableStatuses = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfiguration();
  }

  /// Carga la configuración actual de Quick Actions
  Future<void> _loadCurrentConfiguration() async {
    try {
      setState(() => _isLoading = true);
      
      final current = await QuickActionsPreferencesService.getUserQuickActions();
      final available = QuickActionsPreferencesService.getAvailableStatusTypes();
      
      setState(() {
        _selectedQuickActions = List.from(current);
        _availableStatuses = available;
        _isLoading = false;
      });
      
      debugPrint('[QuickActionsConfig] ✅ Configuración cargada: ${_selectedQuickActions.map((s) => s.emoji).join(', ')}');
      
    } catch (e) {
      debugPrint('[QuickActionsConfig] ❌ Error cargando configuración: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Guarda la nueva configuración de Quick Actions
  Future<void> _saveConfiguration() async {
    if (_selectedQuickActions.length != 4) {
      _showMessage('❌ Debes seleccionar exactamente 4 emojis', Colors.red);
      return;
    }
    
    try {
      setState(() => _isSaving = true);
      
      // Guardar y actualizar Quick Actions
      await QuickActionsService.updateUserQuickActions(_selectedQuickActions);
      
      // Feedback háptico
      HapticFeedback.lightImpact();
      
      _showMessage('✅ Quick Actions actualizadas correctamente', Colors.green);
      
    } catch (e) {
      debugPrint('[QuickActionsConfig] ❌ Error guardando: $e');
      _showMessage('❌ Error guardando configuración', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// Resetea a la configuración por defecto
  Future<void> _resetToDefaults() async {
    try {
      setState(() => _isSaving = true);
      
      final defaults = QuickActionsPreferencesService.getDefaultQuickActions();
      await QuickActionsService.updateUserQuickActions(defaults);
      
      setState(() {
        _selectedQuickActions = List.from(defaults);
      });
      
      HapticFeedback.lightImpact();
      _showMessage('🔄 Configuración reseteada a defaults', Colors.blue);
      
    } catch (e) {
      debugPrint('[QuickActionsConfig] ❌ Error reseteando: $e');
      _showMessage('❌ Error reseteando configuración', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// Alterna la selección de un StatusType
  void _toggleSelection(StatusType status) {
    if (!mounted) return;
    
    setState(() {
      if (_selectedQuickActions.contains(status)) {
        // Deseleccionar
        _selectedQuickActions.remove(status);
      } else {
        // Seleccionar (máximo 4)
        if (_selectedQuickActions.length < 4) {
          _selectedQuickActions.add(status);
          HapticFeedback.selectionClick();
        } else {
          // Ya hay 4 seleccionados, mostrar mensaje
          _showMessage('🔢 Máximo 4 Quick Actions permitidas', Colors.orange);
        }
      }
    });
  }

  /// Muestra un mensaje temporal
  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[700]!, width: 1),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                '⚡ Quick Actions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${_selectedQuickActions.length}/4',
                style: TextStyle(
                  color: _selectedQuickActions.length == 4 
                      ? Colors.green 
                      : Colors.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Selecciona 4 emojis para tus Quick Actions (presión larga en el ícono de la app)',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 20),

          // Quick Actions seleccionadas (preview)
          if (_selectedQuickActions.isNotEmpty) ...[
            Text(
              'Quick Actions seleccionadas:',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _selectedQuickActions.map((status) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue, width: 1),
                  ),
                  child: Text(
                    '${status.emoji} ${status.description}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Grid de todos los emojis disponibles
          Text(
            'Emojis disponibles (toca para seleccionar):',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          
          // Grid 4x4 de emojis
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: _availableStatuses.length,
            itemBuilder: (context, index) {
              final status = _availableStatuses[index];
              final isSelected = _selectedQuickActions.contains(status);
              
              return GestureDetector(
                onTap: () => _toggleSelection(status),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.blue.withOpacity(0.3)
                        : Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? Colors.blue
                          : Colors.grey[600]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        status.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.description,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? Colors.white : Colors.grey[400],
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 20),

          // Botones de acción
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _resetToDefaults,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: (_selectedQuickActions.length == 4 && !_isSaving) 
                      ? _saveConfiguration 
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: _isSaving 
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: Text(_isSaving ? 'Guardando...' : 'Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}