// lib/features/geofencing/presentation/pages/zones_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/circle_service.dart';
import '../../domain/entities/zone.dart';
import '../../services/zone_service.dart';
import '../widgets/zone_form.dart';
import '../widgets/geofencing_debug_widget.dart';

/// Página de gestión de zonas geográficas
/// Lista todas las zonas del círculo con opciones CRUD
class ZonesPage extends ConsumerStatefulWidget {
  final Circle circle;

  const ZonesPage({super.key, required this.circle});

  @override
  ConsumerState<ZonesPage> createState() => _ZonesPageState();
}

class _ZonesPageState extends ConsumerState<ZonesPage> {
  final ZoneService _zoneService = ZoneService();
  bool _showDebugWidget = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mis Zonas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.bug_report,
              color: _showDebugWidget ? const Color(0xFF1EE9A4) : Colors.grey,
            ),
            tooltip: 'Debug: Simular eventos',
            onPressed: () {
              setState(() => _showDebugWidget = !_showDebugWidget);
            },
          ),
        ],
      ),
      floatingActionButton: StreamBuilder<List<Zone>>(
        stream: _zoneService.listenToZones(widget.circle.id),
        builder: (context, snapshot) {
          final zones = snapshot.data ?? [];
          final canAdd = zones.length < ZoneService.MAX_ZONES_PER_CIRCLE;

          return FloatingActionButton(
            onPressed: canAdd ? () => _addZone(context) : null,
            backgroundColor: canAdd ? const Color(0xFF1EE9A4) : Colors.grey.shade800,
            child: Icon(
              Icons.add,
              color: canAdd ? Colors.black : Colors.grey.shade600,
              size: 32,
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: StreamBuilder<List<Zone>>(
        stream: _zoneService.listenToZones(widget.circle.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1EE9A4),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final zones = snapshot.data ?? [];

          if (zones.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 80,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No hay zonas configuradas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crea tu primera zona para detectar\nllegadas y salidas automáticamente',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Header con contador (alineado a la derecha)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.location_on, color: Colors.grey.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${zones.length} de ${ZoneService.MAX_ZONES_PER_CIRCLE} zonas',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Debug widget (cuando está activo)
              if (_showDebugWidget)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GeofencingDebugWidget(
                    circleId: widget.circle.id,
                    zones: zones,
                  ),
                ),

              // Lista de zonas
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: zones.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: Color(0xFF3A3A3C),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final zone = zones[index];
                    return _buildZoneTile(context, zone);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildZoneTile(BuildContext context, Zone zone) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: Color(zone.type.color).withOpacity(0.2),
        child: Text(
          zone.type.emoji,
          style: const TextStyle(fontSize: 24),
        ),
      ),
      title: Text(
        zone.name,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        '${zone.radiusMeters.toInt()}m de radio',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF1EE9A4)),
            onPressed: () => _editZone(context, zone),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(context, zone),
          ),
        ],
      ),
      onTap: () => _editZone(context, zone),
    );
  }

  void _addZone(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ZoneForm(
          circleId: widget.circle.id,
        ),
      ),
    );
  }

  void _editZone(BuildContext context, Zone zone) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ZoneForm(
          circleId: widget.circle.id,
          zone: zone,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Zone zone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Eliminar zona',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Estás seguro de eliminar "${zone.name}"?\n\nEsta acción no se puede deshacer.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteZone(context, zone);
            },
            child: const Text(
              'ELIMINAR',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteZone(BuildContext context, Zone zone) async {
    try {
      await _zoneService.deleteZone(
        circleId: widget.circle.id,
        zoneId: zone.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zona "${zone.name}" eliminada'),
            backgroundColor: const Color(0xFF1EE9A4),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
