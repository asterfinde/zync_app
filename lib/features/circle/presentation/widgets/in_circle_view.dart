import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/firebase_circle_service.dart';
import '../../../auth/presentation/provider/auth_provider.dart';
import '../../../auth/presentation/provider/auth_state.dart';
import '../../../../core/widgets/emoji_modal.dart';
import '../../../../core/services/gps_service.dart';
import '../../../../core/services/status_service.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../domain_old/entities/user_status.dart';

// ===========================================================================
// SECCIÓN DE DISEÑO: Colores y Estilos basados en la pantalla de referencia
// ===========================================================================

/// Paleta de colores extraída del diseño de la pantalla de Login.
class _AppColors {
  static const Color background = Color(0xFF000000); // Negro puro
  static const Color accent = Color(0xFF1EE9A4); // Verde menta/turquesa
  static const Color textPrimary = Color(0xFFFFFFFF); // Blanco
  static const Color textSecondary = Color(0xFF9E9E9E); // Gris para subtítulos y labels
  static const Color cardBackground = Color(0xFF1C1C1E); // Gris oscuro para menús y diálogos
  static const Color cardBorder = Color(0xFF3A3A3C); // Borde sutil para tarjetas y divider
  static const Color sosRed = Color(0xFFD32F2F); // Rojo para alertas SOS
}

/// Estilos de texto consistentes con el diseño.
class _AppTextStyles {
  static const TextStyle screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: _AppColors.textPrimary,
    letterSpacing: 1.2,
  );

  static const TextStyle userNickname = TextStyle(
    fontSize: 16,
    color: _AppColors.textSecondary,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: _AppColors.textPrimary,
  );

  static const TextStyle cardSubtitle = TextStyle(
    color: _AppColors.textSecondary,
    fontSize: 14,
  );

  static const TextStyle invitationCode = TextStyle(
    fontFamily: 'monospace',
    fontWeight: FontWeight.bold,
    fontSize: 20,
    color: _AppColors.textPrimary,
    letterSpacing: 1.5,
  );

  static const TextStyle memberNickname = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: _AppColors.textPrimary,
  );
  
  static const TextStyle memberStatus = TextStyle(
    fontSize: 14,
    color: _AppColors.textSecondary,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle sosStatus = TextStyle(
    fontSize: 14,
    color: _AppColors.sosRed,
    fontWeight: FontWeight.bold,
  );
}


class InCircleView extends ConsumerStatefulWidget {
  final Circle circle;

  const InCircleView({super.key, required this.circle});

  @override
  ConsumerState<InCircleView> createState() => _InCircleViewState();
}

class _InCircleViewState extends ConsumerState<InCircleView> {
  // === INICIO DE LA LÓGICA ORIGINAL (SIN CAMBIOS) ===
  final Map<String, Map<String, dynamic>> _memberDataCache = {};
  bool _isUpdatingStatus = false; // Para controlar el loading del botón "Todo Bien"

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _listenToStatusChanges();
  }

  Future<void> _loadInitialData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('circles')
        .doc(widget.circle.id)
        .get();

    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data()!;
      final memberStatus = data['memberStatus'] as Map<String, dynamic>?;

      if (memberStatus != null && mounted) {
        setState(() {
          memberStatus.forEach((memberId, statusData) {
            _memberDataCache[memberId] = _parseMemberData(statusData);
          });
        });
      }
    }
  }

  void _listenToStatusChanges() {
    FirebaseFirestore.instance
        .collection('circles')
        .doc(widget.circle.id)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || !snapshot.exists || snapshot.data() == null) return;

      final data = snapshot.data()!;
      final memberStatus = data['memberStatus'] as Map<String, dynamic>?;

      if (memberStatus != null) {
        bool hasChanges = false;
        final Map<String, Map<String, dynamic>> updates = {};

        memberStatus.forEach((memberId, statusData) {
          final newData = _parseMemberData(statusData);
          final oldData = _memberDataCache[memberId];

          if (_hasChanged(oldData, newData)) {
            updates[memberId] = newData;
            hasChanges = true;
          }
        });

        if (hasChanges) {
          setState(() {
            updates.forEach((memberId, newData) {
              _memberDataCache[memberId] = newData;
            });
          });
        }
      }
    });
  }

  Map<String, dynamic> _parseMemberData(dynamic statusData) {
    if (statusData is! Map<String, dynamic>) {
      return {'emoji': '😊', 'status': 'fine', 'hasGPS': false};
    }

    final statusType = statusData['statusType'] as String?;
    String emoji = '😊';
    
    if (statusType != null) {
      try {
        final statusEnum = StatusType.values.firstWhere(
          (s) => s.name == statusType,
          orElse: () => StatusType.fine,
        );
        emoji = statusEnum.emoji;
      } catch (e) {
        emoji = '😊';
      }
    }

    final coordinates = statusData['coordinates'] as Map<String, dynamic>?;
    final timestamp = statusData['timestamp'];
    DateTime? lastUpdate;
    if (timestamp is Timestamp) {
      lastUpdate = timestamp.toDate();
    }

    return {
      'emoji': emoji,
      'status': statusType ?? 'fine',
      'coordinates': coordinates,
      'hasGPS': coordinates != null && statusType == 'sos',
      'lastUpdate': lastUpdate,
    };
  }

  bool _hasChanged(Map<String, dynamic>? oldData, Map<String, dynamic> newData) {
    if (oldData == null) return true;
    return oldData['status'] != newData['status'] ||
           oldData['lastUpdate']?.toString() != newData['lastUpdate']?.toString() ||
           oldData['coordinates']?.toString() != newData['coordinates']?.toString();
  }
  // === FIN DE LA LÓGICA ORIGINAL (SIN CAMBIOS) ===

  @override
  Widget build(BuildContext context) {
    final circle = widget.circle;
    // CAMBIO: Se envuelve en un Scaffold para poder añadir el footer de demostración.
    return Scaffold(
      backgroundColor: _AppColors.background,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            color: _AppColors.background,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Zync', style: _AppTextStyles.screenTitle),
                      Text(
                        _getCurrentUserNickname(ref),
                        style: _AppTextStyles.userNickname,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: _AppColors.textPrimary),
                  color: _AppColors.cardBackground,
                  onSelected: (value) {
                    switch (value) {
                      case 'leave_circle':
                        _showLeaveCircleDialog(context);
                        break;
                      case 'logout':
                        _showLogoutDialog(context, ref);
                        break;
                      case 'settings':
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        );
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    _buildPopupMenuItem(
                      value: 'logout', icon: Icons.logout, text: 'Cerrar Sesión',
                      color: _AppColors.textSecondary,
                    ),
                    _buildPopupMenuItem(
                      value: 'settings', icon: Icons.settings, text: 'Configuración',
                      color: _AppColors.accent,
                    ),
                     _buildPopupMenuItem(
                      value: 'leave_circle', icon: Icons.exit_to_app, text: 'Salir del Círculo',
                      color: _AppColors.sosRed,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0), // Padding inferior reducido
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.hub, size: 28, color: _AppColors.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(circle.name, style: _AppTextStyles.cardTitle),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${circle.members.length} miembros',
                                    style: _AppTextStyles.cardSubtitle,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        const Text('Código de Invitación', style: _AppTextStyles.cardSubtitle),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(circle.invitationCode, style: _AppTextStyles.invitationCode),
                            ),
                            IconButton(
                              onPressed: () => _copyToClipboard(context, circle.invitationCode),
                              icon: const Icon(Icons.copy, size: 24, color: _AppColors.accent),
                              tooltip: 'Copiar código',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Divider(color: _AppColors.cardBorder, thickness: 1),
                  ),

                  const Row(
                    children: [
                      Icon(Icons.people_outline, size: 24, color: _AppColors.accent),
                      SizedBox(width: 8),
                      Text('Miembros', style: _AppTextStyles.screenTitle),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  FutureBuilder<Map<String, String>>(
                    future: _getAllMemberNicknames(circle.members),
                    builder: (context, nicknameSnapshot) {
                      if (nicknameSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: _AppColors.accent,));
                      }
                      
                      final nicknames = nicknameSnapshot.data ?? {};
                      final currentUser = FirebaseAuth.instance.currentUser;
                      
                      return Column(
                        children: circle.members.asMap().entries.map((entry) {
                          final index = entry.key;
                          final memberId = entry.value;
                          final nickname = nicknames[memberId] ?? 
                            (memberId.length > 8 ? memberId.substring(0, 8) : memberId);
                          final isCurrentUser = currentUser?.uid == memberId;
                          final memberData = _memberDataCache[memberId] ?? {
                            'emoji': '😊', 'status': 'fine', 'hasGPS': false,
                            'coordinates': null, 'lastUpdate': null,
                          };
                          final status = memberData['status'] ?? 'fine';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: _MemberListItem(
                              key: ValueKey('${memberId}_$status'),
                              memberId: memberId, nickname: nickname, isCurrentUser: isCurrentUser,
                              isFirst: index == 0, memberData: memberData,
                              onTap: isCurrentUser 
                                  ? () => showEmojiStatusBottomSheet(context)
                                  : null,
                              onOpenMaps: _openGoogleMaps,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // CAMBIO: Footer de demostración añadido
      bottomNavigationBar: _buildFooterButton(context),
    );
  }

  // === INICIO DE WIDGETS AUXILIARES Y LÓGICA ORIGINAL (SIN CAMBIOS) ===
  
  /// Actualización rápida del estado a "fine" (✅) - Point 17
  Future<void> _quickStatusUpdate() async {
    if (_isUpdatingStatus) return;
    
    setState(() {
      _isUpdatingStatus = true;
    });
    
    try {
      print('[InCircleView] ✅ Enviando estado rápido: fine (Todo Bien)');
      
      final result = await StatusService.updateUserStatus(StatusType.fine);
      
      // El cambio se refleja inmediatamente en el emoji del usuario
      // No necesitamos SnackBar porque es visualmente directo
      if (!result.isSuccess && mounted) {
        // Solo mostrar error si algo salió mal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result.errorMessage}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[InCircleView] Error en quickStatusUpdate: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error actualizando estado'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  /// CAMBIO: Widget para el botón del footer, estilizado como se desea.
  Widget _buildFooterButton(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          // Actualiza el estado del usuario a "fine" (Todo Bien)
          onPressed: _isUpdatingStatus ? null : () => _quickStatusUpdate(),
          style: ElevatedButton.styleFrom(
            backgroundColor: _AppColors.accent,
            foregroundColor: _AppColors.background,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            // La clave para la forma del botón:
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0), // Bordes más cuadrados
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isUpdatingStatus)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                  ),
                )
              else
                const Icon(Icons.check_circle),
              const SizedBox(width: 8),
              Text(_isUpdatingStatus ? 'Actualizando...' : 'Todo bien'),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value, required IconData icon, required String text, required Color color,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: _AppColors.textPrimary)),
        ],
      ),
    );
  }

  String _getCurrentUserNickname(WidgetRef ref) {
    final authState = ref.watch(authProvider);
    if (authState is Authenticated) {
      return authState.user.nickname.isNotEmpty 
          ? authState.user.nickname 
          : authState.user.email.split('@')[0];
    }
    return 'Usuario';
  }

  Future<Map<String, String>> _getAllMemberNicknames(List<String> memberIds) async {
    final Map<String, String> nicknames = {};
    final futures = memberIds.map((uid) async {
      try {
        final doc = await FirebaseCircleService().getUserDoc(uid);
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final nickname = data['nickname'] as String? ?? '';
          final email = data['email'] as String? ?? '';
          final name = data['name'] as String? ?? '';
          
          String finalNickname;
          if (nickname.isNotEmpty) {
            finalNickname = nickname;
          } else if (name.isNotEmpty) finalNickname = name;
          else if (email.isNotEmpty) finalNickname = email.split('@')[0];
          else finalNickname = uid.length > 8 ? uid.substring(0, 8) : uid;
          return MapEntry(uid, finalNickname);
        } else {
          final fallback = uid.length > 8 ? uid.substring(0, 8) : uid;
          return MapEntry(uid, fallback);
        }
      } catch (e) {
        final fallback = uid.length > 8 ? uid.substring(0, 8) : uid;
        return MapEntry(uid, fallback);
      }
    });
    final results = await Future.wait(futures);
    for (final entry in results) {
      nicknames[entry.key] = entry.value;
    }
    return nicknames;
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Código copiado al portapapeles!'),
        duration: Duration(seconds: 2),
        backgroundColor: _AppColors.accent,
      ),
    );
  }

  void _openGoogleMaps(BuildContext context, Map<String, dynamic> coordinates, String memberName) async {
    try {
      final latitude = coordinates['latitude'] as double?;
      final longitude = coordinates['longitude'] as double?;
      if (latitude == null || longitude == null) {
        _showError(context, 'Coordenadas GPS no válidas');
        return;
      }
      final url = GPSService.generateSOSLocationUrl(
        Coordinates(latitude: latitude, longitude: longitude), memberName,
      );
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        HapticFeedback.lightImpact();
      } else {
        // ignore: use_build_context_synchronously
        _showError(context, 'No se pudo abrir la aplicación de mapas');
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      _showError(context, 'Error al abrir la ubicación: $e');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _AppColors.sosRed,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar Sesión', style: TextStyle(color: _AppColors.textPrimary)),
        content: const Text('¿Estás seguro?', style: TextStyle(color: _AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar', style: TextStyle(color: _AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await FirebaseAuth.instance.signOut();
            },
            child: const Text('Cerrar Sesión', style: TextStyle(color: _AppColors.sosRed)),
          ),
        ],
      ),
    );
  }

  void _showLeaveCircleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Salir del Círculo', style: TextStyle(color: _AppColors.textPrimary)),
        content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: _AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar', style: TextStyle(color: _AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final service = FirebaseCircleService();
              await service.leaveCircle();
            },
            child: const Text('Salir', style: TextStyle(color: _AppColors.sosRed)),
          ),
        ],
      ),
    );
  }
}
// === FIN DE LA LÓGICA ORIGINAL (SIN CAMBIOS) ===


// ==============================================================================
// MEMBER LIST ITEM - Widget individual con diseño ultra minimalista
// ==============================================================================
class _MemberListItem extends StatelessWidget {
  final String memberId;
  final String nickname;
  final bool isCurrentUser;
  final bool isFirst;
  final Map<String, dynamic> memberData;
  final VoidCallback? onTap;
  final Function(BuildContext, Map<String, dynamic>, String) onOpenMaps;

  const _MemberListItem({
    super.key,
    required this.memberId,
    required this.nickname,
    required this.isCurrentUser,
    required this.isFirst,
    required this.memberData,
    this.onTap,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = memberData['emoji'] as String? ?? '😊';
    final status = memberData['status'] as String? ?? 'fine';
    final hasGPS = memberData['hasGPS'] as bool? ?? false;
    final coordinates = memberData['coordinates'] as Map<String, dynamic>?;
    final lastUpdate = memberData['lastUpdate'] as DateTime?;
    final isSOS = status == 'sos';
    
    return Material(
      color: _AppColors.background,
      child: InkWell(
        onTap: () {
          if (isCurrentUser && onTap != null) {
            HapticFeedback.mediumImpact();
            onTap!();
          } else if (hasGPS && coordinates != null) {
            HapticFeedback.lightImpact();
            onOpenMaps(context, coordinates, nickname);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Text(emoji, key: ValueKey(status), style: const TextStyle(fontSize: 32)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(nickname, style: _AppTextStyles.memberNickname, overflow: TextOverflow.ellipsis)),
                            if (isCurrentUser) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _AppColors.accent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'TÚ',
                                  style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold, color: _AppColors.background,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStatusLabel(status),
                          style: isSOS ? _AppTextStyles.sosStatus : _AppTextStyles.memberStatus,
                        ),
                        if (isFirst)
                           Text(
                             'Creador',
                             style: TextStyle(
                               fontSize: 12, color: _AppColors.accent.withOpacity(0.8), fontWeight: FontWeight.w500,
                             ),
                           ),
                      ],
                    ),
                  ),
                  if (lastUpdate != null)
                    Text(
                      _getTimeAgo(lastUpdate),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
              if (hasGPS && coordinates != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 20, color: _AppColors.sosRed),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Ubicación SOS compartida',
                          style: TextStyle(fontSize: 13, color: _AppColors.textPrimary, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red[300]),
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

  // === MÉTODOS HELPER ORIGINALES (SIN CAMBIOS) ===
  String _getStatusLabel(String s) {
    final labels = {
      'fine': 'Todo bien', 'sos': '¡Necesito ayuda!', 'meeting': 'En reunión', 'ready': 'Listo',
      'leave': 'De salida', 'happy': 'Feliz', 'sad': 'Triste', 'busy': 'Ocupado',
      'sleepy': 'Con sueño', 'excited': 'Emocionado', 'thinking': 'Pensando', 'worried': 'Preocupado',
      'available': 'Disponible', 'away': 'Ausente', 'focus': 'Concentrado', 'tired': 'Cansado',
      'stressed': 'Estresado', 'traveling': 'Viajando', 'studying': 'Estudiando', 'eating': 'Comiendo',
    };
    return labels[s] ?? s;
  }

  String _getTimeAgo(DateTime dt) {
    final difference = DateTime.now().difference(dt);
    if (difference.inMinutes < 1) return 'Ahora';
    if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Hace ${difference.inHours} h';
    return 'Hace ${difference.inDays} d';
  }
}

////////////////////////////////////////////

