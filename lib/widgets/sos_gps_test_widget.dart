// Point 16 Debug: Widget para probar funcionalidad SOS GPS
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/services/gps_service.dart';
import '../core/services/status_service.dart';
import '../features/circle/domain_old/entities/user_status.dart';

class SOSGPSTestWidget extends StatefulWidget {
  const SOSGPSTestWidget({super.key});

  @override
  State<SOSGPSTestWidget> createState() => _SOSGPSTestWidgetState();
}

class _SOSGPSTestWidgetState extends State<SOSGPSTestWidget> {
  String _status = 'Sin probar';
  Coordinates? _lastCoordinates;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('🆘📍 Point 16 Debug'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Estado GPS',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: TextStyle(color: Colors.grey[300]),
                    ),
                    if (_lastCoordinates != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Lat: ${_lastCoordinates!.latitude}',
                        style: const TextStyle(color: Colors.green),
                      ),
                      Text(
                        'Lng: ${_lastCoordinates!.longitude}',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton.icon(
              onPressed: _testGPS,
              icon: const Icon(Icons.gps_fixed),
              label: const Text('Probar GPS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _testSOSWithGPS,
              icon: const Icon(Icons.sos),
              label: const Text('Enviar SOS con GPS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _lastCoordinates != null ? _testMapsUrls : null,
              icon: const Icon(Icons.map),
              label: const Text('Probar URLs de Mapas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Expanded(
              child: Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Log de Debug',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[700]!),
                          ),
                          child: const SingleChildScrollView(
                            child: Text(
                              'Los logs aparecerán en la consola Flutter.\nVerifica el terminal para ver los detalles del debugging.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
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
      ),
    );
  }

  void _testGPS() async {
    setState(() {
      _status = 'Obteniendo ubicación...';
    });

    try {
      final coordinates = await GPSService.getCurrentLocation();
      
      if (coordinates != null) {
        setState(() {
          _status = 'GPS obtenido correctamente';
          _lastCoordinates = coordinates;
        });
        
        HapticFeedback.lightImpact();
        _showSuccess('GPS obtenido: ${coordinates.latitude}, ${coordinates.longitude}');
      } else {
        setState(() {
          _status = 'Error: No se pudo obtener GPS';
        });
        _showError('No se pudo obtener ubicación GPS');
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      _showError('Error obteniendo GPS: $e');
    }
  }

  void _testSOSWithGPS() async {
    setState(() {
      _status = 'Enviando SOS con GPS...';
    });

    try {
      final result = await StatusService.updateUserStatus(StatusType.sos);
      
      if (result.isSuccess) {
        setState(() {
          if (result.coordinates != null) {
            _status = 'SOS enviado con GPS correctamente';
            _lastCoordinates = result.coordinates;
          } else {
            _status = 'SOS enviado sin GPS';
          }
        });
        
        HapticFeedback.mediumImpact();
        _showSuccess('SOS enviado ${result.coordinates != null ? 'con GPS' : 'sin GPS'}');
      } else {
        setState(() {
          _status = 'Error enviando SOS: ${result.errorMessage}';
        });
        _showError('Error: ${result.errorMessage}');
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      _showError('Error enviando SOS: $e');
    }
  }

  void _testMapsUrls() async {
    if (_lastCoordinates == null) return;

    final urls = GPSService.generateFallbackMapUrls(_lastCoordinates!, 'TestUser');
    
    for (int i = 0; i < urls.length; i++) {
      final url = urls[i];
      print('Testing URL $i: $url');
      
      try {
        final uri = Uri.parse(url);
        final canLaunch = await canLaunchUrl(uri);
        
        print('URL $i can launch: $canLaunch');
        
        if (canLaunch) {
          // Mostrar diálogo de confirmación
          final shouldLaunch = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text('Probar URL $i', style: const TextStyle(color: Colors.white)),
              content: Text(
                'URL: $url\n\n¿Abrir en aplicación de mapas?',
                style: const TextStyle(color: Colors.grey),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Abrir'),
                ),
              ],
            ),
          );
          
          if (shouldLaunch == true && mounted) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            _showSuccess('URL $i funcionó correctamente');
            return;
          }
        }
      } catch (e) {
        print('Error with URL $i: $e');
      }
    }
    
    _showError('Ninguna URL de mapas funcionó');
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}