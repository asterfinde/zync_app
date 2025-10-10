import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_circle_service.dart';
import '../../../auth/presentation/provider/auth_provider.dart';
import '../../../auth/presentation/provider/auth_state.dart';
import '../../../../core/widgets/emoji_modal.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../domain_old/entities/user_status.dart'; // Para StatusType

class InCircleView extends ConsumerWidget {
  final Circle circle;
  
  const InCircleView({super.key, required this.circle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // AppBar personalizado
        Container(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
          color: Colors.black,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Zync',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      _getCurrentUserNickname(ref),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
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
                  const PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.grey),
                      title: Text('Cerrar Sesión'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings, color: Colors.blue),
                      title: Text('Configuración'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'leave_circle',
                    child: ListTile(
                      leading: Icon(Icons.exit_to_app, color: Colors.red),
                      title: Text('Salir del Círculo'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Contenido principal
        Expanded(
          child: Container(
            color: Colors.black,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header del círculo
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1513),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.group, size: 32, color: Colors.blue[400]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    circle.name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${circle.members.length} miembros',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Código de invitación mejorado
                        Row(
                          children: const [
                            Icon(Icons.vpn_key, size: 20, color: Colors.grey),
                            SizedBox(width: 12),
                            Text(
                              'Código de Invitación:',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                circle.invitationCode,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _copyToClipboard(context, circle.invitationCode),
                              icon: const Icon(Icons.copy, size: 24, color: Color(0xFF4CAF50)),
                              tooltip: 'Copiar código',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Lista de miembros
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1513),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people, size: 24, color: Colors.green[400]),
                            const SizedBox(width: 8),
                            const Text(
                              'Miembros',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Lista de miembros con nicknames optimizada
                        FutureBuilder<Map<String, String>>(
                          future: _getAllMemberNicknames(circle.members),
                          builder: (context, snapshot) {
                            // Mostrar indicador de carga mientras se obtienen los nicknames
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Column(
                                children: circle.members.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  // Miembro en estado de carga
                                  final isFirst = index == 0;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isFirst ? Colors.blue[900] : Colors.grey[700],
                                          ),
                                          child: const Center(
                                            child: Text(
                                              '🙂',
                                              style: TextStyle(fontSize: 20),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.grey[500],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Cargando...',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.grey[400],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (isFirst) ...[
                                                Text(
                                                  'Creador',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.blue[400],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.green[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            }
                            
                            final nicknames = snapshot.data ?? {};
                            
                            return Column(
                              children: circle.members.asMap().entries.map((entry) {
                                final index = entry.key;
                                final memberId = entry.value;
                                final isFirst = index == 0;
                                final nickname = nicknames[memberId] ?? 
                                  (memberId.length > 8 ? memberId.substring(0, 8) : memberId);
                                
                                // Verificar si es el usuario actual
                                final currentUser = FirebaseAuth.instance.currentUser;
                                final isCurrentUser = currentUser?.uid == memberId;

                                Widget memberRow = Row(
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: StreamBuilder<Map<String, String>>(
                                        stream: _getMemberStatusStream(circle.id),
                                        builder: (context, snapshot) {
                                          final statusEmojis = snapshot.data ?? {};
                                          final emoji = statusEmojis[memberId] ?? '😊';
                                          return Center(
                                            child: Text(
                                              emoji,
                                              style: const TextStyle(fontSize: 28),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nickname,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (isFirst) ...[
                                            Text(
                                              'Creador',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue[400],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                          if (isCurrentUser) ...[
                                            Text(
                                              'Mantén presionado para cambiar estado',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[400],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.green[400],
                                      ),
                                    ),
                                  ],
                                );

                                // Envolver con GestureDetector solo si es el usuario actual
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: isCurrentUser 
                                    ? GestureDetector(
                                        onLongPress: () {
                                          // Mostrar feedback haptic
                                          HapticFeedback.mediumImpact();
                                          // Abrir bottom sheet para cambiar estado
                                          showEmojiStatusBottomSheet(context);
                                        },
                                        child: memberRow,
                                      )
                                    : memberRow,
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
        // log('[InCircleView] 🔍 Obteniendo nicknames para ${uids.length} miembros: $uids');
    
    // Procesar en paralelo para optimizar rendimiento
    final futures = memberIds.map((uid) async {
      try {
      // log('[InCircleView] 📄 Consultando documento para UID: $uid');
        final doc = await FirebaseCircleService().getUserDoc(uid);
        
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final nickname = data['nickname'] as String? ?? '';
          final email = data['email'] as String? ?? '';
          final name = data['name'] as String? ?? '';
          
          print('[InCircleView] 🏷️ Para $uid - nickname: "$nickname", email: "$email", name: "$name"');
          
          String finalNickname;
          if (nickname.isNotEmpty) {
            finalNickname = nickname;
            print('[InCircleView] ✅ Usando nickname: "$nickname" para $uid');
          } else if (name.isNotEmpty) {
            finalNickname = name;
            print('[InCircleView] ✅ Usando name: "$name" para $uid');
          } else if (email.isNotEmpty) {
            finalNickname = email.split('@')[0];
            print('[InCircleView] ✅ Usando email prefix: "${email.split('@')[0]}" para $uid');
          } else {
            finalNickname = uid.length > 8 ? uid.substring(0, 8) : uid;
            print('[InCircleView] ⚠️ Usando UID truncado: "$finalNickname" para $uid');
          }
          
          return MapEntry(uid, finalNickname);
        } else {
          print('[InCircleView] ⚠️ Documento no existe para $uid');
          final fallback = uid.length > 8 ? uid.substring(0, 8) : uid;
          return MapEntry(uid, fallback);
        }
      } catch (e) {
        print('[InCircleView] ❌ Error obteniendo datos para $uid: $e');
        final fallback = uid.length > 8 ? uid.substring(0, 8) : uid;
        return MapEntry(uid, fallback);
      }
    });
    
    final results = await Future.wait(futures);
    for (final entry in results) {
      nicknames[entry.key] = entry.value;
      print('[InCircleView] 🎯 Resultado final - ${entry.key}: "${entry.value}"');
    }
    
    print('[InCircleView] 🏁 Nicknames finales: $nicknames');
    return nicknames;
  }

  /// Stream que escucha cambios en el estado de los miembros del círculo
  Stream<Map<String, String>> _getMemberStatusStream(String circleId) {
    return FirebaseFirestore.instance
        .collection('circles')
        .doc(circleId)
        .snapshots()
        .map((snapshot) {
      final Map<String, String> statusEmojis = {};
      
      if (snapshot.exists && snapshot.data() != null) {
        final memberStatus = snapshot.data()!['memberStatus'] as Map<String, dynamic>?;
        
        if (memberStatus != null) {
          memberStatus.forEach((memberId, statusData) {
            if (statusData is Map<String, dynamic>) {
              final statusType = statusData['statusType'] as String?;
              
              // Mapear el statusType a emoji usando StatusType dinámico
              if (statusType != null) {
                try {
                  print('[InCircleView] 🔍 DEBUG - Buscando: "$statusType"');
                  print('[InCircleView] 🔍 DEBUG - Disponibles: ${StatusType.values.map((s) => s.name).toList()}');
                  
                  // Buscar el StatusType que coincida
                  final statusEnum = StatusType.values.firstWhere(
                    (status) => status.name == statusType,
                    orElse: () {
                      print('[InCircleView] ⚠️ orElse - "$statusType" no encontrado');
                      return StatusType.fine;
                    },
                  );
                  statusEmojis[memberId] = statusEnum.emoji;
                  print('[InCircleView] ✅ Mapeado: $statusType → ${statusEnum.emoji} (${statusEnum.name})');
                } catch (e) {
                  // Fallback si hay error en el mapeo
                  statusEmojis[memberId] = '😊';
                  print('[InCircleView] ❌ Error mapeando $statusType: $e');
                }
              } else {
                statusEmojis[memberId] = '😊'; // Default si statusType es null
              }
            }
          });
        }
      }
      
      return statusEmojis;
    });
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Código copiado al portapapeles!'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Cerrar Sesión',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Estás seguro de que quieres cerrar sesión?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sesión cerrada exitosamente'),
                      backgroundColor: Color(0xFF4CAF50),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al cerrar sesión: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  void _showLeaveCircleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Salir del Círculo',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Estás seguro de que quieres salir de este círculo? Necesitarás un nuevo código de invitación para volver a unirte.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final service = FirebaseCircleService();
                await service.leaveCircle();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Has salido del círculo exitosamente'),
                      backgroundColor: Color(0xFF4CAF50),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al salir del círculo: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }
}
