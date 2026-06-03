// lib/features/geofencing/presentation/pages/zones_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../services/circle_service.dart';
import '../../domain/entities/zone.dart';
import '../../services/zone_service.dart';
import '../widgets/zone_form.dart';
import '../widgets/geofencing_debug_widget.dart';
import '../../../../app/theme/design_tokens.dart';

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
  late final bool _isCreator;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _isCreator = uid != null && uid == widget.circle.creatorId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NkColors.canvas,
      appBar: AppBar(
        backgroundColor: NkColors.canvas,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mis Zonas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: NkColors.onDark,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.bug_report,
              color: _showDebugWidget ? NkColors.mint : NkColors.fgSub,
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
            backgroundColor: canAdd ? NkColors.mint : NkColors.surface3,
            child: Icon(
              Icons.add,
              color: canAdd ? NkColors.onMint : NkColors.fgSub,
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
                color: NkColors.mint,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: NkColors.danger),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: NkColors.onDark),
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
                  const Icon(
                    Icons.location_off,
                    size: 80,
                    color: NkColors.surface4,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No hay zonas configuradas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: NkColors.onDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crea tu primera zona para detectar\nllegadas y salidas automáticamente',
                    style: TextStyle(
                      fontSize: 14,
                      color: NkColors.fgSub,
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
                    const Icon(Icons.location_on, color: NkColors.fgSub, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${zones.length} de ${ZoneService.MAX_ZONES_PER_CIRCLE} zonas',
                      style: const TextStyle(
                        color: NkColors.fgSub,
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
                    color: NkColors.surface4,
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
          color: NkColors.onDark,
        ),
      ),
      subtitle: Text(
        '${zone.radiusMeters.toInt()}m de radio',
        style: const TextStyle(
          fontSize: 14,
          color: NkColors.fgSub,
        ),
      ),
      trailing: _isCreator
          ? IconButton(
              icon: const Icon(Icons.delete, color: NkColors.danger),
              onPressed: () => _confirmDelete(context, zone),
            )
          : null,
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

  void _confirmDelete(BuildContext context, Zone zone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NkColors.surface2,
        title: const Text(
          'Eliminar zona',
          style: TextStyle(color: NkColors.onDark),
        ),
        content: Text(
          '¿Estás seguro de eliminar "${zone.name}"?\n\nEsta acción no se puede deshacer.',
          style: const TextStyle(color: NkColors.fgMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: NkColors.fgSub),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteZone(context, zone);
            },
            child: const Text(
              'ELIMINAR',
              style: TextStyle(color: NkColors.danger),
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
            backgroundColor: NkColors.mint,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: NkColors.danger,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
