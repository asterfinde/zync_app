import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/user_status.dart';
import '../../core/services/quick_actions_preferences_service.dart';
import '../../quick_actions/quick_actions_service.dart';

// ===========================================================================
// SECCIÓN DE DISEÑO: Colores y Estilos basados en la pantalla de referencia
// ===========================================================================

/// Paleta de colores extraída del diseño de la pantalla de referencia (InCircleView).
class _AppColors {
  static const Color background = Color(0xFF000000); // Negro puro
  static const Color accent = Color(0xFF1EE9A4); // Verde menta/turquesa
  static const Color textPrimary = Color(0xFFFFFFFF); // Blanco
  static const Color textSecondary =
      Color(0xFF9E9E9E); // Gris para subtítulos y labels
  static const Color cardBackground =
      Color(0xFF1C1C1E); // Gris oscuro para menús y diálogos
  static const Color cardBorder =
      Color(0xFF3A3A3C); // Borde sutil para tarjetas y divider
  static const Color sosRed = Color(0xFFD32F2F); // Rojo para alertas SOS
  static const Color inputFill = Color(0xFF2C2C2E); // Relleno de inputs
}

/// Estilos de texto consistentes con el diseño de referencia.
class _AppTextStyles {
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

  static const TextStyle buttonLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}

/// Widget para configurar las Quick Actions del usuario (Point 14)
/// Permite seleccionar 4 emojis favoritos de los 16 disponibles
class QuickActionsConfigWidget extends StatefulWidget {
  const QuickActionsConfigWidget({super.key});

  @override
  State<QuickActionsConfigWidget> createState() =>
      _QuickActionsConfigWidgetState();
}

class _QuickActionsConfigWidgetState extends State<QuickActionsConfigWidget> {
  // --- INICIO DE LÓGICA (SIN CAMBIOS) ---
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

      final current =
          await QuickActionsPreferencesService.getUserQuickActions();
      final available =
          await QuickActionsPreferencesService.getAvailableStatusTypes();

      setState(() {
        _selectedQuickActions = List.from(current);
        _availableStatuses = available;
        _isLoading = false;
      });

      debugPrint(
          '[QuickActionsConfig] ✅ Configuración cargada: ${_selectedQuickActions.map((s) => s.emoji).join(', ')}');
    } catch (e) {
      debugPrint('[QuickActionsConfig] ❌ Error cargando configuración: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Guarda la nueva configuración de Quick Actions
  Future<void> _saveConfiguration() async {
    if (_selectedQuickActions.length != 4) {
      _showMessage('❌ Debes seleccionar exactamente 4 emojis',
          _AppColors.sosRed); // <-- CAMBIO DE UI
      return;
    }

    try {
      setState(() => _isSaving = true);

      // Guardar y actualizar Quick Actions
      await QuickActionsService.updateUserQuickActions(_selectedQuickActions);

      // Feedback háptico
      HapticFeedback.lightImpact();

      _showMessage('✅ Quick Actions actualizadas correctamente',
          Colors.green); // <-- CAMBIO DE UI (Se mantiene verde)
    } catch (e) {
      debugPrint('[QuickActionsConfig] ❌ Error guardando: $e');
      _showMessage('❌ Error guardando configuración',
          _AppColors.sosRed); // <-- CAMBIO DE UI
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// Resetea a la configuración por defecto
  Future<void> _resetToDefaults() async {
    try {
      setState(() => _isSaving = true);

      final defaults =
          await QuickActionsPreferencesService.getDefaultQuickActions();
      await QuickActionsService.updateUserQuickActions(defaults);

      setState(() {
        _selectedQuickActions = List.from(defaults);
      });

      HapticFeedback.lightImpact();
      _showMessage('🔄 Configuración reseteada a defaults',
          _AppColors.textSecondary); // <-- CAMBIO DE UI
    } catch (e) {
      debugPrint('[QuickActionsConfig] ❌ Error reseteando: $e');
      _showMessage('❌ Error reseteando configuración',
          _AppColors.sosRed); // <-- CAMBIO DE UI
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
          _showMessage('🔢 Máximo 4 Quick Actions permitidas',
              _AppColors.sosRed); // <-- CAMBIO DE UI
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
  // --- FIN DE LÓGICA (SIN CAMBIOS) ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _AppColors.cardBackground, // <-- CAMBIO DE UI
          borderRadius: BorderRadius.circular(16),
          // --- INICIO DE LA MEJORA ---
          // border: Border.all(color: Colors.grey[700]!, width: 1), // Borde eliminado
          // --- FIN DE LA MEJORA ---
        ),
        child: const Center(
          child: CircularProgressIndicator(
              color: _AppColors.accent), // <-- CAMBIO DE UI
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _AppColors.cardBackground, // <-- CAMBIO DE UI
        borderRadius: BorderRadius.circular(16),
        // --- INICIO DE LA MEJORA ---
        // border: Border.all(color: Colors.grey[700]!, width: 1), // Borde eliminado
        // --- FIN DE LA MEJORA ---
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Quick Actions', // <-- CAMBIO DE UI (Emoji quitado)
                style: _AppTextStyles.cardTitle, // <-- CAMBIO DE UI
              ),
              const Spacer(),
              Text(
                '${_selectedQuickActions.length}/4',
                style: TextStyle(
                  color: _selectedQuickActions.length == 4
                      ? _AppColors.accent // <-- CAMBIO DE UI
                      : _AppColors.textSecondary, // <-- CAMBIO DE UI
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            'Selecciona 4 emojis para tus Quick Actions (presión larga en el ícono de la app)',
            style: _AppTextStyles.textBody, // <-- CAMBIO DE UI
          ),

          const SizedBox(height: 16), // Reducido de 20 a 16

          // Quick Actions seleccionadas (preview más compacto)
          if (_selectedQuickActions.isNotEmpty) ...[
            Text(
              'Quick Actions seleccionadas:',
              style: _AppTextStyles.textBody
                  .copyWith(fontSize: 13), // <-- CAMBIO DE UI
            ),
            const SizedBox(height: 6), // Reducido de 8 a 6
            Wrap(
              spacing: 6, // Reducido de 8 a 6
              runSpacing: 4,
              children: _selectedQuickActions.map((status) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4), // Reducido
                  decoration: BoxDecoration(
                    color:
                        _AppColors.accent.withOpacity(0.2), // <-- CAMBIO DE UI
                    borderRadius:
                        BorderRadius.circular(16), // Reducido de 20 a 16
                    border: Border.all(
                        color: _AppColors.accent, width: 1), // <-- CAMBIO DE UI
                  ),
                  child: Text(
                    '${status.emoji} ${status.shortDescription}', // Usar shortDescription
                    style: const TextStyle(
                      color: _AppColors.textPrimary, // <-- CAMBIO DE UI
                      fontSize: 11, // Reducido de 12 a 11
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12), // Reducido de 16 a 12
          ],

          // Grid de todos los emojis disponibles
          Text(
            'Emojis disponibles (toca para seleccionar):',
            style: _AppTextStyles.textBody
                .copyWith(fontSize: 13), // <-- CAMBIO DE UI
          ),
          const SizedBox(height: 8), // Reducido de 12 a 8

          // Grid sincronizado con StatusSelectorOverlay (13 elementos)
          // Ahora con mejor manejo de overflow
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 300, // Altura máxima para prevenir overflow
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 6, // Reducido de 8 a 6
                crossAxisSpacing: 6, // Reducido de 8 a 6
                childAspectRatio: 1.0, // Elementos cuadrados
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
                          ? _AppColors.accent
                              .withOpacity(0.3) // <-- CAMBIO DE UI
                          : _AppColors.inputFill, // <-- CAMBIO DE UI
                      borderRadius:
                          BorderRadius.circular(8), // Reducido de 12 a 8
                      border: Border.all(
                        color: isSelected
                            ? _AppColors.accent // <-- CAMBIO DE UI
                            : _AppColors.cardBorder, // <-- CAMBIO DE UI
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          status.emoji,
                          style: const TextStyle(
                              fontSize: 20), // Reducido de 24 a 20
                        ),
                        const SizedBox(height: 2), // Reducido de 4 a 2
                        Flexible(
                          child: Text(
                            status
                                .shortDescription, // Usar shortDescription como el modal
                            style: TextStyle(
                              fontSize: 8, // Reducido de 10 a 8
                              color: isSelected
                                  ? _AppColors.textPrimary
                                  : _AppColors
                                      .textSecondary, // <-- CAMBIO DE UI
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1, // Solo 1 línea para evitar overflow
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16), // Reducido de 20 a 16

          // Botones de acción (más compactos)
          Row(
            children: [
              // --- INICIO DE LA MEJORA: BOTÓN RESET ---
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _resetToDefaults,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _AppColors.inputFill, // <-- CAMBIO DE UI
                    foregroundColor: _AppColors.textPrimary, // <-- CAMBIO DE UI
                    padding: const EdgeInsets.symmetric(
                        vertical: 16), // <-- CAMBIO DE UI
                    shape: RoundedRectangleBorder(
                      // <-- CAMBIO DE UI
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 18), // <-- CAMBIO DE UI
                  label: Text('Reset',
                      style: _AppTextStyles.buttonLabel.copyWith(
                        color: _AppColors.textPrimary,
                      ) // <-- CAMBIO DE UI
                      ),
                ),
              ),
              // --- FIN DE LA MEJORA ---

              const SizedBox(width: 10), // Reducido de 12 a 10

              // --- INICIO DE LA MEJORA: BOTÓN GUARDAR ---
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: (_selectedQuickActions.length == 4 && !_isSaving)
                      ? _saveConfiguration
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _AppColors.accent, // <-- CAMBIO DE UI
                    foregroundColor: _AppColors.background, // <-- CAMBIO DE UI
                    disabledBackgroundColor: _AppColors.accent.withOpacity(0.5),
                    disabledForegroundColor:
                        _AppColors.background.withOpacity(0.7),
                    padding: const EdgeInsets.symmetric(
                        vertical: 16), // <-- CAMBIO DE UI
                    shape: RoundedRectangleBorder(
                      // <-- CAMBIO DE UI
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18, height: 18, // <-- CAMBIO DE UI
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _AppColors.background, // <-- CAMBIO DE UI
                          ),
                        )
                      : const Icon(Icons.save, size: 18), // <-- CAMBIO DE UI
                  label: Text(_isSaving ? 'Guardando...' : 'Guardar',
                      style: _AppTextStyles.buttonLabel.copyWith(
                        color: _AppColors.background,
                      ) // <-- CAMBIO DE UI
                      ),
                ),
              ),
              // --- FIN DE LA MEJORA ---
            ],
          ),
        ],
      ),
    );
  }
}


////////////////////////////////////////////////////

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import '../../core/models/user_status.dart';
// import '../../core/services/quick_actions_preferences_service.dart';
// import '../../quick_actions/quick_actions_service.dart';

// /// Widget para configurar las Quick Actions del usuario (Point 14)
// /// Permite seleccionar 4 emojis favoritos de los 16 disponibles
// class QuickActionsConfigWidget extends StatefulWidget {
//   const QuickActionsConfigWidget({super.key});

//   @override
//   State<QuickActionsConfigWidget> createState() => _QuickActionsConfigWidgetState();
// }

// class _QuickActionsConfigWidgetState extends State<QuickActionsConfigWidget> {
//   List<StatusType> _selectedQuickActions = [];
//   List<StatusType> _availableStatuses = [];
//   bool _isLoading = true;
//   bool _isSaving = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadCurrentConfiguration();
//   }

//   /// Carga la configuración actual de Quick Actions
//   Future<void> _loadCurrentConfiguration() async {
//     try {
//       setState(() => _isLoading = true);
      
//       final current = await QuickActionsPreferencesService.getUserQuickActions();
//       final available = QuickActionsPreferencesService.getAvailableStatusTypes();
      
//       setState(() {
//         _selectedQuickActions = List.from(current);
//         _availableStatuses = available;
//         _isLoading = false;
//       });
      
//       debugPrint('[QuickActionsConfig] ✅ Configuración cargada: ${_selectedQuickActions.map((s) => s.emoji).join(', ')}');
      
//     } catch (e) {
//       debugPrint('[QuickActionsConfig] ❌ Error cargando configuración: $e');
//       setState(() => _isLoading = false);
//     }
//   }

//   /// Guarda la nueva configuración de Quick Actions
//   Future<void> _saveConfiguration() async {
//     if (_selectedQuickActions.length != 4) {
//       _showMessage('❌ Debes seleccionar exactamente 4 emojis', Colors.red);
//       return;
//     }
    
//     try {
//       setState(() => _isSaving = true);
      
//       // Guardar y actualizar Quick Actions
//       await QuickActionsService.updateUserQuickActions(_selectedQuickActions);
      
//       // Feedback háptico
//       HapticFeedback.lightImpact();
      
//       _showMessage('✅ Quick Actions actualizadas correctamente', Colors.green);
      
//     } catch (e) {
//       debugPrint('[QuickActionsConfig] ❌ Error guardando: $e');
//       _showMessage('❌ Error guardando configuración', Colors.red);
//     } finally {
//       setState(() => _isSaving = false);
//     }
//   }

//   /// Resetea a la configuración por defecto
//   Future<void> _resetToDefaults() async {
//     try {
//       setState(() => _isSaving = true);
      
//       final defaults = QuickActionsPreferencesService.getDefaultQuickActions();
//       await QuickActionsService.updateUserQuickActions(defaults);
      
//       setState(() {
//         _selectedQuickActions = List.from(defaults);
//       });
      
//       HapticFeedback.lightImpact();
//       _showMessage('🔄 Configuración reseteada a defaults', Colors.blue);
      
//     } catch (e) {
//       debugPrint('[QuickActionsConfig] ❌ Error reseteando: $e');
//       _showMessage('❌ Error reseteando configuración', Colors.red);
//     } finally {
//       setState(() => _isSaving = false);
//     }
//   }

//   /// Alterna la selección de un StatusType
//   void _toggleSelection(StatusType status) {
//     if (!mounted) return;
    
//     setState(() {
//       if (_selectedQuickActions.contains(status)) {
//         // Deseleccionar
//         _selectedQuickActions.remove(status);
//       } else {
//         // Seleccionar (máximo 4)
//         if (_selectedQuickActions.length < 4) {
//           _selectedQuickActions.add(status);
//           HapticFeedback.selectionClick();
//         } else {
//           // Ya hay 4 seleccionados, mostrar mensaje
//           _showMessage('🔢 Máximo 4 Quick Actions permitidas', Colors.orange);
//         }
//       }
//     });
//   }

//   /// Muestra un mensaje temporal
//   void _showMessage(String message, Color color) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: color,
//         duration: const Duration(seconds: 2),
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return Container(
//         padding: const EdgeInsets.all(20),
//         decoration: BoxDecoration(
//           color: Colors.grey[900],
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(color: Colors.grey[700]!, width: 1),
//         ),
//         child: const Center(
//           child: CircularProgressIndicator(),
//         ),
//       );
//     }

//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.grey[900],
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: Colors.grey[700]!, width: 1),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header
//           Row(
//             children: [
//               const Text(
//                 '⚡ Quick Actions',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const Spacer(),
//               Text(
//                 '${_selectedQuickActions.length}/4',
//                 style: TextStyle(
//                   color: _selectedQuickActions.length == 4 
//                       ? Colors.green 
//                       : Colors.orange,
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
          
//           const SizedBox(height: 12),
          
//           Text(
//             'Selecciona 4 emojis para tus Quick Actions (presión larga en el ícono de la app)',
//             style: TextStyle(
//               color: Colors.grey[400],
//               fontSize: 14,
//             ),
//           ),
          
//           const SizedBox(height: 16), // Reducido de 20 a 16

//           // Quick Actions seleccionadas (preview más compacto)
//           if (_selectedQuickActions.isNotEmpty) ...[
//             Text(
//               'Quick Actions seleccionadas:',
//               style: TextStyle(
//                 color: Colors.grey[300],
//                 fontSize: 13, // Reducido de 14 a 13
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//             const SizedBox(height: 6), // Reducido de 8 a 6
//             Wrap(
//               spacing: 6, // Reducido de 8 a 6
//               runSpacing: 4,
//               children: _selectedQuickActions.map((status) {
//                 return Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reducido
//                   decoration: BoxDecoration(
//                     color: Colors.blue.withOpacity(0.2),
//                     borderRadius: BorderRadius.circular(16), // Reducido de 20 a 16
//                     border: Border.all(color: Colors.blue, width: 1),
//                   ),
//                   child: Text(
//                     '${status.emoji} ${status.shortDescription}', // Usar shortDescription
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 11, // Reducido de 12 a 11
//                     ),
//                   ),
//                 );
//               }).toList(),
//             ),
//             const SizedBox(height: 12), // Reducido de 16 a 12
//           ],

//           // Grid de todos los emojis disponibles
//           Text(
//             'Emojis disponibles (toca para seleccionar):',
//             style: TextStyle(
//               color: Colors.grey[300],
//               fontSize: 13, // Reducido de 14 a 13
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           const SizedBox(height: 8), // Reducido de 12 a 8
          
//           // Grid sincronizado con StatusSelectorOverlay (13 elementos)
//           // Ahora con mejor manejo de overflow
//           ConstrainedBox(
//             constraints: const BoxConstraints(
//               maxHeight: 300, // Altura máxima para prevenir overflow
//             ),
//             child: GridView.builder(
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 4,
//                 mainAxisSpacing: 6, // Reducido de 8 a 6
//                 crossAxisSpacing: 6, // Reducido de 8 a 6
//                 childAspectRatio: 1.0, // Elementos cuadrados
//               ),
//               itemCount: _availableStatuses.length,
//               itemBuilder: (context, index) {
//                 final status = _availableStatuses[index];
//                 final isSelected = _selectedQuickActions.contains(status);
                
//                 return GestureDetector(
//                   onTap: () => _toggleSelection(status),
//                   child: Container(
//                     decoration: BoxDecoration(
//                       color: isSelected 
//                           ? Colors.blue.withOpacity(0.3)
//                           : Colors.grey[800],
//                       borderRadius: BorderRadius.circular(8), // Reducido de 12 a 8
//                       border: Border.all(
//                         color: isSelected 
//                             ? Colors.blue
//                             : Colors.grey[600]!,
//                         width: isSelected ? 2 : 1,
//                       ),
//                     ),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Text(
//                           status.emoji,
//                           style: const TextStyle(fontSize: 20), // Reducido de 24 a 20
//                         ),
//                         const SizedBox(height: 2), // Reducido de 4 a 2
//                         Flexible(
//                           child: Text(
//                             status.shortDescription, // Usar shortDescription como el modal
//                             style: TextStyle(
//                               fontSize: 8, // Reducido de 10 a 8
//                               color: isSelected ? Colors.white : Colors.grey[400],
//                               fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
//                             ),
//                             textAlign: TextAlign.center,
//                             maxLines: 1, // Solo 1 línea para evitar overflow
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
          
//           const SizedBox(height: 16), // Reducido de 20 a 16

//           // Botones de acción (más compactos)
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton.icon(
//                   onPressed: _isSaving ? null : _resetToDefaults,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.grey[700],
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 10), // Reducido de 12 a 10
//                   ),
//                   icon: const Icon(Icons.refresh, size: 16), // Reducido de 18 a 16
//                   label: const Text('Reset', style: TextStyle(fontSize: 13)), // Reducido
//                 ),
//               ),
//               const SizedBox(width: 10), // Reducido de 12 a 10
//               Expanded(
//                 flex: 2,
//                 child: ElevatedButton.icon(
//                   onPressed: (_selectedQuickActions.length == 4 && !_isSaving) 
//                       ? _saveConfiguration 
//                       : null,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 10), // Reducido de 12 a 10
//                   ),
//                   icon: _isSaving 
//                       ? const SizedBox(
//                           width: 16, height: 16, // Reducido de 18 a 16
//                           child: CircularProgressIndicator(
//                             strokeWidth: 2, color: Colors.white,
//                           ),
//                         )
//                       : const Icon(Icons.save, size: 16), // Reducido de 18 a 16
//                   label: Text(
//                     _isSaving ? 'Guardando...' : 'Guardar',
//                     style: const TextStyle(fontSize: 13), // Reducido
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }