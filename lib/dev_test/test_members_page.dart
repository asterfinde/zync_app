// ==============================================================================
// 🧪 TEST MEMBERS PAGE - Point 17 Testing
// ==============================================================================
// Pantalla de prueba aislada para validar:
// 1. Scroll de lista de miembros sin overlap del FAB
// 2. Actualización granular del estado del usuario actual
// 3. Point 16 SOS GPS functionality
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'mock_data.dart';

class TestMembersPage extends StatefulWidget {
  const TestMembersPage({super.key});

  @override
  State<TestMembersPage> createState() => _TestMembersPageState();
}

class _TestMembersPageState extends State<TestMembersPage> {
  /// Lista de miembros mock
  List<Map<String, dynamic>> members = MockData.getMockMembers();

  /// ID del usuario actual
  final String currentUserId = MockData.currentUserId;

  /// Actualizar estado del usuario actual
  void _updateCurrentUserStatus(String newStatus) {
    setState(() {
      final currentUserIndex =
          members.indexWhere((m) => m['userId'] == currentUserId);

      if (currentUserIndex != -1) {
        print('🔄 Updating current user status: ${members[currentUserIndex]['status']} → $newStatus');
        
        members[currentUserIndex]['status'] = newStatus;
        members[currentUserIndex]['lastUpdate'] = DateTime.now();

        // Si es SOS, simular captura de GPS
        if (newStatus == 'sos') {
          members[currentUserIndex]['gpsLatitude'] = -12.0464;
          members[currentUserIndex]['gpsLongitude'] = -77.0428;
          print('📍 GPS captured: ${members[currentUserIndex]['gpsLatitude']}, ${members[currentUserIndex]['gpsLongitude']}');
        } else {
          members[currentUserIndex]['gpsLatitude'] = null;
          members[currentUserIndex]['gpsLongitude'] = null;
        }
      }
    });

    // Haptic feedback
    HapticFeedback.mediumImpact();
  }

  /// Update to fine (FAB action)
  void _updateToFine() {
    _updateCurrentUserStatus('fine');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Estado actualizado a Todo Bien'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// Abrir Google Maps con coordenadas
  Future<void> _openGoogleMaps(double lat, double lng) async {
    // Usar formato de coordenadas directo para mejor compatibilidad
    final url = 'https://www.google.com/maps?q=$lat,$lng';
    final uri = Uri.parse(url);

    print('🗺️ Opening Google Maps: $url');

    try {
      final canLaunch = await canLaunchUrl(uri);
      print('🗺️ Can launch URL: $canLaunch');
      
      if (canLaunch) {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('🗺️ Launch result: $launched');
      } else {
        print('❌ Cannot launch URL: $url');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ No se pudo abrir Google Maps')),
          );
        }
      }
    } catch (e) {
      print('❌ Error opening Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  /// Mostrar menú de cambio de estado (ESTILO APP ORIGINAL)
  void _showStatusMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle visual
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              
              // Grid 3x2 de estados (ESTILO ORIGINAL)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                itemCount: 6, // Solo 6 estados principales
                itemBuilder: (context, index) {
                  // Estados principales en orden original
                  final statusList = ['leave', 'busy', 'fine', 'sad', 'ready', 'sos'];
                  final status = statusList[index];
                  
                  return _buildStatusChip(status);
                },
              ),
              
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }

  /// Chip de estado para el modal (ESTILO ORIGINAL)
  Widget _buildStatusChip(String status) {
    final emoji = MockData.getEmojiForStatus(status);
    final label = MockData.getStatusLabel(status);
    final currentStatus = members.firstWhere((m) => m['userId'] == currentUserId)['status'];
    final isCurrentStatus = currentStatus == status;

    return GestureDetector(
      onTap: () {
        _updateCurrentUserStatus(status);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isCurrentStatus 
              ? const Color(0xFF1CE4B3).withOpacity(0.15) 
              : const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrentStatus 
                ? const Color(0xFF1CE4B3) 
                : Colors.grey[700]!,
            width: isCurrentStatus ? 2 : 1,
          ),
          boxShadow: isCurrentStatus ? [
            BoxShadow(
              color: const Color(0xFF1CE4B3).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isCurrentStatus ? const Color(0xFF1CE4B3) : Colors.grey[300],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Test Members List'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: members.length,
        itemBuilder: (context, index) {
          final member = members[index];
          final isCurrentUser = member['userId'] == currentUserId;

          return _MemberListItem(
            key: ValueKey('${member['userId']}_${member['status']}'),
            member: member,
            isCurrentUser: isCurrentUser,
            onTap: isCurrentUser ? _showStatusMenu : null,
            onOpenMaps: (lat, lng) => _openGoogleMaps(lat, lng),
          );
        },
      ),
      // Footer estilo app original (sin traslape)
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 8,
        ),
        decoration: BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: ElevatedButton.icon(
            onPressed: _updateToFine,
            icon: const Icon(Icons.check_circle, size: 24),
            label: const Text(
              'Todo Bien',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// MEMBER LIST ITEM - Widget individual para cada miembro
// ==============================================================================

class _MemberListItem extends StatelessWidget {
  final Map<String, dynamic> member;
  final bool isCurrentUser;
  final VoidCallback? onTap;
  final Function(double, double)? onOpenMaps;

  const _MemberListItem({
    super.key,
    required this.member,
    required this.isCurrentUser,
    this.onTap,
    this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    print('🔄 Building MemberListItem for ${member['userId']}');

    final status = member['status'] as String;
    final emoji = MockData.getEmojiForStatus(status);
    final hasGPS = MockData.hasGPS(member);
    final isSOS = status == 'sos';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSOS ? Colors.red.shade900.withOpacity(0.3) : Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Emoji + Nickname
            Row(
              children: [
                // Emoji con AnimatedSwitcher
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    emoji,
                    key: ValueKey(status),
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            member['nickname'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'TÚ',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        MockData.getStatusLabel(status),
                        style: TextStyle(
                          fontSize: 14,
                          color: isSOS ? Colors.red.shade300 : Colors.grey[400],
                          fontWeight: isSOS ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                // Time ago
                Text(
                  MockData.getTimeAgo(member['lastUpdate']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),

            // GPS Card (solo si tiene GPS)
            if (hasGPS) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade700),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ubicación de emergencia',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          Text(
                            MockData.formatGPS(
                              member['gpsLatitude'],
                              member['gpsLongitude'],
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.map, color: Colors.red),
                      onPressed: () {
                        if (onOpenMaps != null) {
                          onOpenMaps!(
                            member['gpsLatitude'],
                            member['gpsLongitude'],
                          );
                        }
                      },
                      tooltip: 'Abrir en Google Maps',
                    ),
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
}
