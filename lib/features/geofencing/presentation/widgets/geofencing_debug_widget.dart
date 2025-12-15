// lib/features/geofencing/presentation/widgets/geofencing_debug_widget.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/zone.dart';
import '../../domain/entities/zone_event.dart';
import '../../services/zone_event_service.dart';
import 'package:intl/intl.dart';

/// Widget de debug para simular eventos de entrada/salida de zonas
class GeofencingDebugWidget extends StatefulWidget {
  final String circleId;
  final List<Zone> zones;

  const GeofencingDebugWidget({
    super.key,
    required this.circleId,
    required this.zones,
  });

  @override
  State<GeofencingDebugWidget> createState() => _GeofencingDebugWidgetState();
}

class _GeofencingDebugWidgetState extends State<GeofencingDebugWidget> {
  final ZoneEventService _eventService = ZoneEventService();
  Zone? _selectedZone;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.zones.isNotEmpty) {
      _selectedZone = widget.zones.first;
    }
  }

  Future<void> _simulateEntry() async {
    if (_selectedZone == null) return;

    setState(() => _isLoading = true);
    try {
      // Obtener ubicación actual o usar la de la zona
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (e) {
        // Si falla GPS, usar coordenadas de la zona
        print('[Debug] GPS no disponible, usando coordenadas de la zona');
      }

      await _eventService.createEvent(
        circleId: widget.circleId,
        zoneId: _selectedZone!.id,
        eventType: ZoneEventType.entry,
        latitude: position?.latitude ?? _selectedZone!.latitude,
        longitude: position?.longitude ?? _selectedZone!.longitude,
        zoneName: _selectedZone!.name,
      );

      // US-GEO-004: Actualizar estado del usuario según tipo de zona
      await _updateUserStatus(isEntry: true, zone: _selectedZone!);

      // El evento se muestra automáticamente en la lista por el StreamBuilder
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _simulateExit() async {
    if (_selectedZone == null) return;

    setState(() => _isLoading = true);
    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (e) {
        print('[Debug] GPS no disponible, usando coordenadas de la zona');
      }

      await _eventService.createEvent(
        circleId: widget.circleId,
        zoneId: _selectedZone!.id,
        eventType: ZoneEventType.exit,
        latitude: position?.latitude ?? _selectedZone!.latitude,
        longitude: position?.longitude ?? _selectedZone!.longitude,
        zoneName: _selectedZone!.name,
      );

      // US-GEO-004: Actualizar estado a "Viajando" al salir
      await _updateUserStatus(isEntry: false, zone: null);

      // El evento se muestra automáticamente en la lista por el StreamBuilder
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Actualiza el estado del usuario en Firestore según el evento de zona
  /// US-GEO-004: Actualización automática de estado basado en zona
  Future<void> _updateUserStatus({
    required bool isEntry,
    Zone? zone,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final Map<String, dynamic> statusData = {
        'timestamp': FieldValue.serverTimestamp(),
        'autoUpdated': true,
      };

      if (isEntry && zone != null) {
        // ENTRADA A ZONA
        // Mapeo de tipo de zona a ID de estado predefinido
        String statusId;
        switch (zone.type) {
          case ZoneType.home:
            statusId = 'fine';
            break;
          case ZoneType.school:
            statusId = 'studying'; // 📚 Estudiando (en el colegio)
            break;
          case ZoneType.university:
            statusId = 'studying'; // 📚 Estudiando (en la universidad)
            break;
          case ZoneType.work:
            statusId = 'busy'; // 🔴 Ocupado (en el trabajo)
            break;
          case ZoneType.custom:
            statusId = 'fine';
            break;
        }

        statusData['statusType'] = statusId;
        statusData['customEmoji'] = zone.type.emoji; // 🏠, 🏫, 💼, 📍
        statusData['zoneName'] = zone.name; // "Jaus", "Colegio", etc.
        statusData['zoneId'] = zone.id; // ID de la zona activa

        print('[DebugWidget] ✅ Entrada a zona: ${zone.name} (${zone.type.emoji})');
      } else {
        // SALIDA DE ZONA
        statusData['statusType'] = 'driving'; // 🚗 En camino
        statusData['customEmoji'] = '🚗';
        statusData['zoneName'] = 'En camino';
        statusData['zoneId'] = null;

        // Guardar última zona conocida si existe
        if (_selectedZone != null) {
          statusData['lastKnownZone'] = _selectedZone!.name;
          statusData['lastKnownZoneTime'] = FieldValue.serverTimestamp();
        }

        print('[DebugWidget] ✅ Salida de zona: En camino 🚗');
      }

      await FirebaseFirestore.instance.collection('circles').doc(widget.circleId).update({
        'memberStatus.${user.uid}': statusData,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEntry ? '✅ Entrada a ${zone?.name}' : '✅ Salida: En camino'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[DebugWidget] ❌ Error actualizando estado: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error actualizando estado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.zones.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Crea al menos una zona para usar el simulador',
            style: TextStyle(color: Colors.grey, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1EE9A4), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.bug_report, color: Color(0xFF1EE9A4), size: 24),
              SizedBox(width: 8),
              Text(
                'DEBUG: Simulador de Geofencing',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Estado actual del usuario (US-GEO-004)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('circles').doc(widget.circleId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final userId = FirebaseAuth.instance.currentUser?.uid;
              if (userId == null || data == null) {
                return const SizedBox.shrink();
              }

              final memberStatus = data['memberStatus'] as Map<String, dynamic>?;
              final userStatus = memberStatus?[userId] as Map<String, dynamic>?;
              final statusId = userStatus?['statusType'] as String?;
              final autoUpdated = userStatus?['autoUpdated'] as bool? ?? false;
              final customEmoji = userStatus?['customEmoji'] as String?; // 🆕 Emoji de zona
              final zoneName = userStatus?['zoneName'] as String?; // 🆕 Nombre de zona

              if (statusId == null) {
                return const SizedBox.shrink();
              }

              // CASO 1: Si tiene customEmoji (entrada a zona), usar emoji de zona
              String displayEmoji;
              String displayLabel;
              if (autoUpdated && customEmoji != null) {
                displayEmoji = customEmoji; // 🏠, 🏫, 💼, etc.
                displayLabel = zoneName != null ? 'En $zoneName' : 'En zona';
              }
              // CASO 2: Estado genérico (salida de zona o estado manual)
              else {
                final statusEmojis = {
                  'fine': '🙂',
                  'studying': '📚',
                  'busy': '🔴',
                  'driving': '🚗', // En camino
                };
                final statusLabels = {
                  'fine': 'Todo bien',
                  'studying': 'Estudiando',
                  'busy': 'Ocupado',
                  'driving': 'En camino', // En camino
                };
                displayEmoji = statusEmojis[statusId] ?? '❓';
                displayLabel = statusLabels[statusId] ?? statusId;
              }

              return Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: autoUpdated ? Colors.green.withOpacity(0.15) : Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: autoUpdated ? Colors.green : Colors.blue,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      displayEmoji, // 🆕 Usa emoji de zona o genérico
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estado actual: $displayLabel', // 🆕 Muestra "En Jaus" o "Viajando"
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (autoUpdated)
                            Text(
                              '🤖 Actualizado automáticamente',
                              style: TextStyle(
                                color: Colors.green[300],
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Zone selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Zone>(
                value: _selectedZone,
                isExpanded: true,
                dropdownColor: Colors.grey[850],
                style: const TextStyle(color: Colors.white, fontSize: 16),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1EE9A4)),
                items: widget.zones.map((zone) {
                  return DropdownMenuItem<Zone>(
                    value: zone,
                    child: Row(
                      children: [
                        Text(zone.type.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            zone.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${zone.radiusMeters.toInt()}m',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _isLoading
                    ? null
                    : (Zone? newZone) {
                        setState(() => _selectedZone = newZone);
                      },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _simulateEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.login, size: 20),
                  label: const Text('ENTRADA', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _simulateExit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.logout, size: 20),
                  label: const Text('SALIDA', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Events list
          const Text(
            'Eventos Recientes:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: StreamBuilder<List<ZoneEvent>>(
              stream: _eventService.listenToCircleEvents(widget.circleId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1EE9A4)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final events = snapshot.data ?? [];
                if (events.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay eventos registrados',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: events.length > 10 ? 10 : events.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: Colors.grey,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final timeStr = DateFormat('HH:mm:ss').format(event.timestamp);
                    final isEntry = event.eventType == ZoneEventType.entry;

                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isEntry ? Icons.login : Icons.logout,
                        color: isEntry ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                      title: Text(
                        event.zoneName ?? event.zoneId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '${event.eventType.label} - $timeStr',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      trailing: Text(
                        DateFormat('dd/MM').format(event.timestamp),
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
