// lib/features/geofencing/presentation/widgets/zone_form.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nunakin_app/app/di/injection_container.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/place_search_service.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/zone_repository.dart';
import 'package:nunakin_app/contexts/geofencing/application/use_cases/create_zone.dart';
import 'package:nunakin_app/contexts/geofencing/domain/zone_constraints.dart';
import '../../domain/entities/zone.dart';

/// Formulario para crear zonas geográficas.
/// La edición no existe como flujo de producto: editar = eliminar + crear.
/// Incluye búsqueda de dirección, mapa interactivo y option buttons.
class ZoneForm extends StatefulWidget {
  final String circleId;

  const ZoneForm({
    super.key,
    required this.circleId,
  });

  @override
  State<ZoneForm> createState() => _ZoneFormState();
}

class _ZoneFormState extends State<ZoneForm> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _customNameController = TextEditingController();

  GoogleMapController? _mapController;
  late LatLng _selectedLocation;
  late double _radiusMeters;
  ZoneType? _selectedType; // Ahora nullable - sin tipo por defecto
  bool _isLoading = false;
  bool _isLoadingLocation = false;
  bool _isSearching = false;
  List<PlacePrediction> _predictions = []; // Resultados del autocompletado
  List<Zone> _existingZones = []; // Para deshabilitar tipos ocupados

  @override
  void initState() {
    super.initState();
    _loadExistingZones();

    // Ubicación por defecto hasta que el GPS resuelva la posición real.
    _selectedLocation = const LatLng(-12.046374, -77.042793);
    _radiusMeters = 150.0;
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _customNameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// Cargar zonas existentes para deshabilitar tipos ocupados
  Future<void> _loadExistingZones() async {
    final result = await sl<ZoneRepository>().getCircleZones(widget.circleId);
    final zones = result.valueOrNull ?? const <Zone>[];
    if (mounted) setState(() => _existingZones = zones);
  }

  /// Verificar si un tipo de zona está disponible
  bool _isZoneTypeAvailable(ZoneType type) {
    // Solo las predefinidas se pueden ocupar (una vez)
    if (!type.isPredefinedType) return true;

    // Verificar si el tipo ya está ocupado
    return !_existingZones.any((z) => z.type == type);
  }

  /// Obtener ubicación GPS actual del usuario.
  /// El GPS es obligatorio para crear/editar zonas — si no está disponible
  /// se muestra un diálogo bloqueante y se regresa a la pantalla anterior.
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Verificar que el servicio de ubicación esté activo a nivel de SO
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showGpsRequiredDialog(
          'El GPS está desactivado en tu dispositivo.\n\nActívalo para poder crear o editar zonas.',
        );
        return;
      }

      // Verificar/solicitar permisos
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showGpsRequiredDialog(
          'La app necesita permiso de ubicación para crear zonas.\n\nHabilítalo en Configuración para continuar.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation, 16),
      );
    } catch (e) {
      _showGpsRequiredDialog(
        'No se pudo obtener tu ubicación.\n\nVerifica que el GPS esté activo y vuelve a intentarlo.',
      );
    }
  }

  /// Muestra un diálogo bloqueante informando que el GPS es requerido.
  /// Al cerrarlo regresa a la pantalla anterior.
  void _showGpsRequiredDialog(String message) {
    setState(() => _isLoadingLocation = false);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('GPS requerido', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Volver',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await Geolocator.openLocationSettings();
            },
            child: const Text('Abrir Configuración',
                style: TextStyle(
                    color: Color(0xFF1EE9A4),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Buscar lugar/dirección vía Places SDK y mostrar predicciones.
  /// El autocompletado se restringe a ~50 km alrededor de la posición actual
  /// (REGLAS_NEGOCIO.md §10) e indexa POIs/acrónimos (UNALM, óvalos), que el
  /// geocoder nativo no resolvía. El usuario elige una predicción de la lista.
  Future<void> _searchAddress() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _predictions = [];
    });

    try {
      final results = await sl<PlaceSearchService>().autocomplete(
        query,
        lat: _selectedLocation.latitude,
        lng: _selectedLocation.longitude,
      );

      if (!mounted) return;
      setState(() {
        _predictions = results;
        _isSearching = false;
      });

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró ese lugar cerca de tu ubicación'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on PlaceSearchNetworkException {
      if (!mounted) return;
      setState(() => _isSearching = false);
      _showNetworkSnack();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No se pudo buscar el lugar: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Snackbar neutro (no rojo) para errores de red transitorios.
  /// Texto blanco explícito (era ilegible por heredar el color del tema) y
  /// accionable: la búsqueda Places es de red y tras Doze el primer intento
  /// puede fallar — reabrir la pantalla reintenta limpio. [DT-PLACES-NET]
  void _showNetworkSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sin conexión. Cierra y vuelve a entrar a esta pantalla para reintentar.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xFF3A3A3C),
        duration: Duration(seconds: 4),
      ),
    );
  }

  /// Limpia por completo el campo de búsqueda y descarta las predicciones.
  void _clearSearch() {
    setState(() {
      _addressController.clear();
      _predictions = [];
    });
  }

  /// Resolver la predicción elegida a coordenadas y centrar el mapa.
  /// Aplica el filtro circular fino de 50 km (REGLAS_NEGOCIO.md §10): el
  /// `locationRestriction` del SDK es un rectángulo, cuyas esquinas exceden
  /// los 50 km — este check garantiza el umbral exacto de ciudad.
  Future<void> _selectPrediction(PlacePrediction prediction) async {
    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);

    try {
      final location = await sl<PlaceSearchService>().resolve(prediction.placeId);

      if (!mounted) return;
      if (location == null) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ese lugar no tiene una ubicación disponible'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      const maxDistanceMeters = 50 * 1000.0;
      final dist = Geolocator.distanceBetween(
        _selectedLocation.latitude,
        _selectedLocation.longitude,
        location.latitude,
        location.longitude,
      );
      if (dist > maxDistanceMeters) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ese lugar está fuera de tu ciudad'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final newLocation = LatLng(location.latitude, location.longitude);
      setState(() {
        _selectedLocation = newLocation;
        _predictions = [];
        _addressController.text = prediction.primaryText;
        _isSearching = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(newLocation, 16),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Ubicación encontrada - Refina el punto en el mapa'),
          backgroundColor: Color(0xFF1EE9A4),
          duration: Duration(seconds: 2),
        ),
      );
    } on PlaceSearchNetworkException {
      if (!mounted) return;
      setState(() => _isSearching = false);
      _showNetworkSnack();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No se pudo ubicar el lugar: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
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
        title: const Text(
          'CREAR ZONA',
          style: TextStyle(
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
                  circles: _selectedType != null
                      ? {
                          Circle(
                            circleId: const CircleId('zone'),
                            center: _selectedLocation,
                            radius: _radiusMeters,
                            fillColor: Color(_selectedType!.color).withOpacity(0.2),
                            strokeColor: Color(_selectedType!.color),
                            strokeWidth: 2,
                          ),
                        }
                      : {},
                  markers: {
                    Marker(
                      markerId: const MarkerId('center'),
                      position: _selectedLocation,
                      draggable: true,
                      onDragEnd: (newPosition) {
                        setState(() => _selectedLocation = newPosition);
                      },
                      icon: _selectedType != null
                          ? BitmapDescriptor.defaultMarkerWithHue(_getMarkerHue(_selectedType!))
                          : BitmapDescriptor.defaultMarker,
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
                    // Búsqueda de dirección
                    const Text(
                      'Buscar dirección o lugar',
                      style: TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _addressController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Av. Principal, San Isidro o nombre del lugar',
                              hintStyle: TextStyle(color: Colors.grey.shade700),
                              filled: true,
                              fillColor: const Color(0xFF1C1C1E),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.search, color: Color(0xFF9E9E9E)),
                              suffixIcon: _addressController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Color(0xFF9E9E9E)),
                                      onPressed: _clearSearch,
                                    ),
                            ),
                            onChanged: (_) => setState(() {}),
                            onFieldSubmitted: (_) => _searchAddress(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1EE9A4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: _isSearching ? null : _searchAddress,
                            icon: _isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward, color: Colors.black),
                          ),
                        ),
                      ],
                    ),

                    // Lista de predicciones del autocompletado
                    if (_predictions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF3A3A3C)),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < _predictions.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                  height: 1,
                                  color: Color(0xFF3A3A3C),
                                ),
                              _buildPredictionTile(_predictions[i]),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Tipo de zona con Option Buttons
                    const Text(
                      'Tipo de zona',
                      style: TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Zonas predefinidas (Option Buttons)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildZoneTypeButton(ZoneType.home, '🏠 Casa'),
                        _buildZoneTypeButton(ZoneType.school, '🏫 Colegio'),
                        _buildZoneTypeButton(ZoneType.university, '🎓 Universidad'),
                        _buildZoneTypeButton(ZoneType.work, '💼 Trabajo'),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Divider
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Color(0xFF3A3A3C))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'O',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ),
                        const Expanded(child: Divider(color: Color(0xFF3A3A3C))),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Zona personalizada (genérica)
                    _buildZoneTypeButton(ZoneType.custom, '📍 Personalizada'),

                    // Campo de nombre para zona personalizada
                    if (_selectedType == ZoneType.custom) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Nombre de la zona',
                        style: TextStyle(
                          color: Color(0xFF9E9E9E),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _customNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Ej: Gimnasio, Oficina del cliente, etc.',
                          hintStyle: TextStyle(color: Colors.grey.shade700),
                          filled: true,
                          fillColor: const Color(0xFF1C1C1E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (_selectedType == ZoneType.custom && (value == null || value.trim().isEmpty)) {
                            return 'Ingresa un nombre para la zona';
                          }
                          return null;
                        },
                      ),
                    ],

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
                            min: ZoneConstraints.minRadiusMeters,
                            max: ZoneConstraints.maxRadiusMeters,
                            divisions: 45,
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
                        onPressed: _isLoading || _selectedType == null ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1EE9A4),
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: const Color(0xFF3A3A3C),
                          disabledForegroundColor: Colors.grey.shade700,
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
                            : const Text(
                                'Guardar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    if (_selectedType == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '⚠️ Selecciona un tipo de zona para continuar',
                          style: TextStyle(
                            color: Colors.orange.shade400,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
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
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un tipo de zona'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Obtener nombre según tipo de zona
      String zoneName;
      if (_selectedType!.isPredefinedType) {
        zoneName = _getTypeName(_selectedType!);
      } else {
        // Para zona personalizada, usar el campo de nombre personalizado
        zoneName = _customNameController.text.trim();
        if (zoneName.isEmpty) {
          zoneName = 'Zona personalizada';
        }
      }

      final result = await sl<CreateZone>().call(
        circleId: widget.circleId,
        name: zoneName,
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        radiusMeters: _radiusMeters,
        type: _selectedType!,
      );

      if (!mounted) return;
      if (result.isFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result.failureOrNull?.message ?? 'No se pudo crear la zona'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zona creada exitosamente'),
          backgroundColor: Color(0xFF1EE9A4),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
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

  /// Fila de una predicción del autocompletado.
  /// El distrito (`secondaryText`) es el único desambiguador de homónimos:
  /// misma calle, distinto distrito. No se muestra distancia porque Places API
  /// (New) devuelve `distanceMeters = 0` aunque se pase `origin` (no soporta el
  /// sesgo de proximidad en autocomplete) — ver DEUDA [DT-PLACES-NEAREST].
  Widget _buildPredictionTile(PlacePrediction prediction) {
    return InkWell(
      onTap: () => _selectPrediction(prediction),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.place_outlined, color: Color(0xFF9E9E9E), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prediction.primaryText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (prediction.secondaryText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      prediction.secondaryText,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget para botón de tipo de zona (Option Button)
  Widget _buildZoneTypeButton(ZoneType type, String label) {
    final isSelected = _selectedType == type;
    final isAvailable = _isZoneTypeAvailable(type);

    return Opacity(
      opacity: isAvailable ? 1.0 : 0.4,
      child: InkWell(
        onTap: isAvailable ? () => setState(() => _selectedType = type) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? Color(type.color).withOpacity(0.2) : const Color(0xFF1C1C1E),
            border: Border.all(
              color: isSelected
                  ? Color(type.color)
                  : isAvailable
                      ? const Color(0xFF3A3A3C)
                      : Colors.grey.shade800,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : isAvailable
                          ? Colors.grey.shade400
                          : Colors.grey.shade700,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (!isAvailable && type.isPredefinedType) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Colors.grey.shade700,
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
