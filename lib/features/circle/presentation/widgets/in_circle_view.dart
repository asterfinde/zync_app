import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_circle_service.dart';
import '../../../auth/presentation/provider/auth_provider.dart';
import '../../../auth/presentation/provider/auth_state.dart';

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
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'leave_circle',
                    child: ListTile(
                      leading: Icon(Icons.exit_to_app, color: Colors.red),
                      title: Text('Salir del Círculo'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.grey),
                      title: Text('Cerrar Sesión'),
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
    print('[InCircleView] 🔍 Obteniendo nicknames para ${memberIds.length} miembros: $memberIds');
    
    try {
      // Obtener todos los documentos de usuarios en una sola operación batch
      final futures = memberIds.map((uid) async {
        try {
          print('[InCircleView] 📄 Consultando documento para UID: $uid');
          final doc = await FirebaseCircleService().getUserDoc(uid);
          
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            print('[InCircleView] 📊 Datos del usuario $uid: $data');
            
            final nickname = data['nickname'] as String? ?? '';
            final email = data['email'] as String? ?? '';
            final name = data['name'] as String? ?? '';
            
            print('[InCircleView] 🏷️ Para $uid - nickname: "$nickname", email: "$email", name: "$name"');
            
            // Priorizar nickname, luego name, luego email (parte antes del @), luego UID
            if (nickname.isNotEmpty && nickname.trim().isNotEmpty) {
              print('[InCircleView] ✅ Usando nickname: "$nickname" para $uid');
              return MapEntry(uid, nickname.trim());
            } else if (name.isNotEmpty && name.trim().isNotEmpty) {
              print('[InCircleView] ✅ Usando name: "$name" para $uid');
              return MapEntry(uid, name.trim());
            } else if (email.isNotEmpty) {
              final emailPart = email.split('@')[0];
              print('[InCircleView] ✅ Usando email: "$emailPart" para $uid');
              return MapEntry(uid, emailPart);
            } else {
              final shortUid = uid.length > 8 ? uid.substring(0, 8) : uid;
              print('[InCircleView] ⚠️ Usando UID acortado: "$shortUid" para $uid');
              return MapEntry(uid, shortUid);
            }
          } else {
            print('[InCircleView] ❌ Documento no existe para $uid');
            final shortUid = uid.length > 8 ? uid.substring(0, 8) : uid;
            return MapEntry(uid, shortUid);
          }
        } catch (e) {
          print('[InCircleView] ❌ Error obteniendo nickname para $uid: $e');
          final shortUid = uid.length > 8 ? uid.substring(0, 8) : uid;
          return MapEntry(uid, shortUid);
        }
      });
      
      final results = await Future.wait(futures);
      for (final entry in results) {
        nicknames[entry.key] = entry.value;
        print('[InCircleView] 🎯 Resultado final - ${entry.key}: "${entry.value}"');
      }
    } catch (e) {
      print('[InCircleView] ❌ Error general obteniendo nicknames de miembros: $e');
      // Fallback: usar IDs acortados
      for (final uid in memberIds) {
        final shortUid = uid.length > 8 ? uid.substring(0, 8) : uid;
        nicknames[uid] = shortUid;
      }
    }
    
    print('[InCircleView] 🏁 Nicknames finales: $nicknames');
    return nicknames;
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
