// lib/features/geofencing/presentation/widgets/zone_form.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/zone.dart';
import '../../services/zone_service.dart';

/// Formulario para crear/editar zonas geográficas
/// Incluye selector de ubicación en mapa y slider de radio
class ZoneForm extends StatefulWidget {
  final String circleId;
  final Zone? zone; // null = crear, no-null = editar

  const ZoneForm({
    super.key,
    required this.circleId,
    this.zone,
  });

  @override
  State<ZoneForm> createState() => _ZoneFormState();
}

class _ZoneFormState extends State<ZoneForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final ZoneService _zoneService = ZoneService();

  GoogleMapController? _mapController;
  late LatLng _selectedLocation;
  late double _radiusMeters;
  late ZoneType _selectedType;
  bool _isLoading = false;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();

    if (widget.zone != null) {
      // Modo edición
      _nameController.text = widget.zone!.name;
      _selectedLocation = LatLng(widget.zone!.latitude, widget.zone!.longitude);
      _radiusMeters = widget.zone!.radiusMeters;
      _selectedType = widget.zone!.type;
    } else {
      // Modo creación - valores por defecto
      _selectedLocation = const LatLng(-12.046374, -77.042793); // Lima, Perú
      _radiusMeters = 150.0;
      _selectedType = ZoneType.home;
      _getCurrentLocation(); // Intentar obtener ubicación actual
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// Obtener ubicación GPS actual del usuario
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation, 16),
      );
    } catch (e) {
      print('❌ Error obteniendo ubicación: $e');
      setState(() => _isLoadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.zone == null ? 'CREAR ZONA' : 'EDITAR ZONA',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Mapa
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation,
                    zoom: 16,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  onTap: (latLng) {
                    setState(() => _selectedLocation = latLng);
                  },
                  circles: {
                    Circle(
                      circleId: const CircleId('zone'),
                      center: _selectedLocation,
                      radius: _radiusMeters,
                      fillColor: Color(_selectedType.color).withOpacity(0.2),
                      strokeColor: Color(_selectedType.color),
                      strokeWidth: 2,
                    ),
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId('center'),
                      position: _selectedLocation,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        _getMarkerHue(_selectedType),
                      ),
                    ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                // Botón para ubicación actual
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                    backgroundColor: const Color(0xFF1EE9A4),
                    child: _isLoadingLocation
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Icon(Icons.my_location, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),

          // Formulario
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre
                    const Text(
                      'Nombre de la zona',
                      style: TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ej: Casa de Abuela, Cine Plaza Norte',
                        hintStyle: TextStyle(color: Colors.grey.shade700),
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa un nombre';
                        }
                        if (value.trim().length < 2) {
                          return 'Mínimo 2 caracteres';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Tipo de zona
                    const Text(
                      'Tipo de zona',
                      style: TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: ZoneType.values.map((type) {
                        final isSelected = _selectedType == type;
                        return ChoiceChip(
                          label: Text('${type.emoji} ${_getTypeName(type)}'),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedType = type);
                          },
                          backgroundColor: const Color(0xFF1C1C1E),
                          selectedColor: Color(type.color).withOpacity(0.3),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade600,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: isSelected ? Color(type.color) : const Color(0xFF3A3A3C),
                            width: isSelected ? 2 : 1,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Radio
                    const Text(
                      'Radio de detección',
                      style: TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _radiusMeters,
                            min: ZoneService.MIN_RADIUS_METERS,
                            max: ZoneService.MAX_RADIUS_METERS,
                            divisions: 45, // 10m de incremento
                            activeColor: const Color(0xFF1EE9A4),
                            inactiveColor: const Color(0xFF3A3A3C),
                            onChanged: (value) {
                              setState(() => _radiusMeters = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF3A3A3C),
                            ),
                          ),
                          child: Text(
                            '${_radiusMeters.toInt()}m',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Botón guardar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1EE9A4),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.zone == null ? 'CREAR ZONA' : 'GUARDAR CAMBIOS',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.zone == null) {
        // Crear nueva zona
        await _zoneService.createZone(
          circleId: widget.circleId,
          name: _nameController.text.trim(),
          latitude: _selectedLocation.latitude,
          longitude: _selectedLocation.longitude,
          radiusMeters: _radiusMeters,
          type: _selectedType,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Zona creada exitosamente'),
              backgroundColor: Color(0xFF1EE9A4),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // Actualizar zona existente
        await _zoneService.updateZone(
          circleId: widget.circleId,
          zoneId: widget.zone!.id,
          name: _nameController.text.trim(),
          latitude: _selectedLocation.latitude,
          longitude: _selectedLocation.longitude,
          radiusMeters: _radiusMeters,
          type: _selectedType,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Zona actualizada exitosamente'),
              backgroundColor: Color(0xFF1EE9A4),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getTypeName(ZoneType type) {
    switch (type) {
      case ZoneType.home:
        return 'Casa';
      case ZoneType.school:
        return 'Colegio';
      case ZoneType.university:
        return 'Universidad';
      case ZoneType.work:
        return 'Trabajo';
      case ZoneType.custom:
        return 'Personalizada';
    }
  }

  double _getMarkerHue(ZoneType type) {
    switch (type) {
      case ZoneType.home:
        return BitmapDescriptor.hueGreen;
      case ZoneType.school:
        return BitmapDescriptor.hueBlue;
      case ZoneType.university:
        return BitmapDescriptor.hueViolet;
      case ZoneType.work:
        return BitmapDescriptor.hueOrange;
      case ZoneType.custom:
        return BitmapDescriptor.hueRose;
    }
  }
}
