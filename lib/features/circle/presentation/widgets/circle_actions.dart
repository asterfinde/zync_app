import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/user_status.dart';
import '../../../../core/services/gps_service.dart';

/// Acciones puras de UI: copiar al portapapeles, abrir Maps, mostrar SnackBars.
/// Extraído de in_circle_view.dart en Sem 5 Día 5.
class CircleActions {
  static const _accent = Color(0xFF1EE9A4);
  static const _sosRed = Color(0xFFD32F2F);

  /// Copia [text] al portapapeles y muestra confirmación.
  static void copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Código copiado al portapapeles!'),
        duration: Duration(seconds: 2),
        backgroundColor: _accent,
      ),
    );
  }

  /// Abre Google Maps con las coordenadas SOS de [memberName].
  static Future<void> openGoogleMaps(
    BuildContext context,
    Map<String, dynamic> coordinates,
    String memberName,
  ) async {
    try {
      final latitude = coordinates['latitude'] as double?;
      final longitude = coordinates['longitude'] as double?;
      if (latitude == null || longitude == null) {
        _showError(context, 'Coordenadas GPS no válidas');
        return;
      }
      final url = GPSService.generateSOSLocationUrl(
        Coordinates(latitude: latitude, longitude: longitude),
        memberName,
      );
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        HapticFeedback.lightImpact();
      } else if (context.mounted) {
        _showError(context, 'No se pudo abrir la aplicación de mapas');
      }
    } catch (e) {
      debugPrint('[CircleActions] Error opening Google Maps: $e');
      if (context.mounted) _showError(context, 'Error al abrir la ubicación');
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _sosRed,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
